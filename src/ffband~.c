#include "ffbase.h"
#include <rubberband/rubberband-c.h>

#define FRAMES 0x10

static const t_float fastest = 1.0 * FRAMES;
static const t_float slowest = 1.0 / FRAMES;

/* -------------------- FFmpeg player (with rubberband) --------------------- */
static t_class *ffband_class;

typedef struct _buffer {
	t_sample **buf;
	unsigned size;
} t_buffer;

typedef struct _ffband {
	t_ffbase b;
	t_buffer in;
	t_float *tempo;
	t_float *pitch;
	RubberBandState state;
} t_ffband;

static void ffband_seek(t_ffband *x, t_float f) {
	ffbase_seek(&x->b, f);
	rubberband_reset(x->state);
}

static void ffband_tempo(t_ffband *x, t_float f) {
	*x->tempo = f;
}

static void ffband_pitch(t_ffband *x, t_float f) {
	*x->pitch = f;
}

static t_int *ffband_perform(t_int *w) {
	t_ffband *x = (t_ffband *)(w[1]);
	t_ffbase *b = &x->b;
	t_player *p = &b->p;
	unsigned nch = p->nch;
	t_sample *outs[nch];
	for (int i = nch; i--;) {
		outs[i] = p->outs[i];
	}

	int n = (int)(w[2]);
	if (p->play) {
		t_sample *in2 = (t_sample *)(w[3]);
		t_sample *in3 = (t_sample *)(w[4]);
		RubberBandState state = x->state;
		t_buffer *in = &x->in;

		int m = rubberband_available(state);
		if (m > 0) {
			perform:
			m = rubberband_retrieve(state, outs, m < n ? m : n);
			if (m >= n) {
				return (w + 5);
			}
			n -= m, in2 += m, in3 += m;
			for (int i = nch; i--;) {
				outs[i] += m;
			}
		}
		rubberband_set_time_ratio(state, 1.0 /
			(*in2 > fastest ? fastest : (*in2 < slowest ? slowest : *in2)) );
		rubberband_set_pitch_scale(state,
			(*in3 > fastest ? fastest : (*in3 < slowest ? slowest : *in3)) );
		process:
		if (in->size > 0) {
			rubberband_process(state, (const float *const *)in->buf, in->size, 0);
			in->size = swr_convert(b->swr, (uint8_t **)in->buf, FRAMES, 0, 0);
			if ((m = rubberband_available(state)) > 0) {
				goto perform;
			} else {
				goto process;
			}
		}
		receive:
		for (; av_read_frame(b->ic, b->pkt) >= 0; av_packet_unref(b->pkt)) {
			if (b->pkt->stream_index == b->a.idx) {
				if (avcodec_send_packet(b->a.ctx, b->pkt) < 0
				 || avcodec_receive_frame(b->a.ctx, b->frm) < 0) {
					continue;
				}
				in->size = swr_convert(b->swr, (uint8_t **)in->buf, FRAMES
				, (const uint8_t **)b->frm->extended_data, b->frm->nb_samples);
				av_packet_unref(b->pkt);
				goto process;
			} else if (b->pkt->stream_index == b->sub.idx) {
				int got;
				AVSubtitle sub;
				if (avcodec_decode_subtitle2(b->sub.ctx, &sub, &got, b->pkt) >= 0 && got) {
					post("\n%s", b->pkt->data);
				}
			}
		}

		// reached the end
		if (p->play) {
			p->play = 0;
			outlet_anything(p->o_meta, s_done, 0, 0);
			goto receive;
		} else {
			ffband_seek(x, 0);
			t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = p->play} };
			outlet_anything(p->o_meta, s_play, 1, &play);
			goto silence;
		}
	} else while (n--) {
		silence:
		for (int i = nch; i--;) {
			*outs[i]++ = 0;
		}
	}
	return (w + 5);
}

static void ffband_dsp(t_ffband *x, t_signal **sp) {
	t_player *p = &x->b.p;
	for (int i = p->nch; i--;) {
		p->outs[i] = sp[i + 2]->s_vec;
	}
	dsp_add(ffband_perform, 4, x, sp[0]->s_n, sp[0]->s_vec, sp[1]->s_vec);
}

static err_t ffband_reset(void *y) {
	t_ffband *x = (t_ffband *)y;
	t_ffbase *b = &x->b;
	swr_free(&b->swr);
	AVChannelLayout layout_in = ffbase_layout(b);
	swr_alloc_set_opts2(&b->swr
	, &b->layout, AV_SAMPLE_FMT_FLTP  , sys_getsr()
	, &layout_in, b->a.ctx->sample_fmt, b->a.ctx->sample_rate
	, 0, NULL);
	if (swr_init(b->swr) < 0) {
		return "SWResampler initialization failed";
	}

	// pad rubberband's buffer with silence
	x->in.size = 0;
	rubberband_reset(x->state);
	unsigned nch = x->b.p.nch;
	unsigned pad = rubberband_get_preferred_start_pad(x->state);
	t_sample **buf = (t_sample **)getbytes(nch * sizeof(t_sample *));
	for (int i = nch; i--;) {
		buf[i] = (t_sample *)getbytes(pad * sizeof(t_sample));
	}
	rubberband_process(x->state, (const float *const *)buf, pad, 0);
	for (int i = nch; i--;) {
		freebytes(buf[i], pad * sizeof(t_sample));
	}
	freebytes(buf, nch * sizeof(t_sample *));

	return 0;
}

static void *ffband_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_ffband *x = (t_ffband *)ffbase_new(ffband_class, ac, av);
	t_inlet *in2 = signalinlet_new(&x->b.p.obj, 1.0);
	x->tempo = &in2->iu_floatsignalvalue;
	t_inlet *in3 = signalinlet_new(&x->b.p.obj, 1.0);
	x->pitch = &in3->iu_floatsignalvalue;

	RubberBandOptions options = RubberBandOptionProcessRealTime
	| RubberBandOptionEngineFiner;
	x->state = rubberband_new(sys_getsr(), ac, options, 1.0, 1.0);

	x->in.buf = (t_sample **)getbytes(ac * sizeof(t_sample *));
	for (int i = ac; i--;) {
		x->in.buf[i] = (t_sample *)getbytes(FRAMES * sizeof(t_sample));
	}
	x->in.size = 0;

	return x;
}

static void ffband_free(t_ffband *x) {
	ffbase_free(&x->b);
	rubberband_delete(x->state);
	for (int i = x->b.p.nch; i--;) {
		freebytes(x->in.buf[i], FRAMES * sizeof(t_sample));
	}
	freebytes(x->in.buf, x->b.p.nch * sizeof(t_sample *));
}

void ffband_tilde_setup(void) {
	ffbase_reset = ffband_reset;
	ffband_class = class_ffbase(gensym("ffband~")
	, (t_newmethod)ffband_new, (t_method)ffband_free
	, sizeof(t_ffband));

	class_addmethod(ffband_class, (t_method)ffband_dsp
	, gensym("dsp"), A_CANT, 0);
	class_addmethod(ffband_class, (t_method)ffband_seek
	, gensym("seek"), A_FLOAT, 0);
	class_addmethod(ffband_class, (t_method)ffband_pitch
	, gensym("pitch"), A_FLOAT, 0);
	class_addmethod(ffband_class, (t_method)ffband_tempo
	, gensym("tempo"), A_FLOAT, 0);
}
