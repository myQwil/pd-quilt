#include "ffbase.h"
#include "rabbit.h"

/* ------------------------- FFmpeg player ------------------------- */
static t_class *ffplay_class;

typedef struct _ffplay {
	t_ffbase b;
	t_rabbit r;
	t_sample *in;
	t_sample *out;
	t_vinlet speed; /* rate of playback */
} t_ffplay;

static void ffplay_seek(t_ffplay *x, t_float f) {
	ffbase_seek(&x->b, f);
	rabbit_reset(&x->r);
}

static void ffplay_speed(t_ffplay *x, t_float f) {
	*x->speed.p = f;
}

static void ffplay_interp(t_ffplay *x, t_float f) {
	int err = rabbit_interp(&x->r, x->b.p.nch, f);
	if (err) {
		x->b.p.open = x->b.p.play = 0;
	}
}

static t_int *ffplay_perform(t_int *w) {
	t_ffplay *x = (t_ffplay *)(w[1]);
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
		t_rabbit *r = &x->r;
		SRC_DATA *data = &r->data;
		for (; n--; in2++) {
			if (data->output_frames_gen > 0) {
				perform:
				for (int i = nch; i--;) {
					*outs[i]++ = data->data_out[i];
				}
				data->data_out += nch;
				data->output_frames_gen--;
				continue;
			}
			x->speed.v = *in2;
			rabbit_speed(r, *in2);

			process:
			if (data->input_frames > 0) {
				data->data_out = x->out;
				src_process(r->state, data);
				data->input_frames -= data->input_frames_used;
				if (data->input_frames <= 0) {
					data->data_in = x->in;
					data->input_frames = swr_convert(b->swr
					, (uint8_t **)&x->in, FRAMES
					, 0, 0);
				} else {
					data->data_in += data->input_frames_used * nch;
				}
				if (data->output_frames_gen > 0) {
					goto perform;
				} else {
					goto process;
				}
			}
			// receive
			data->data_in = x->in;
			for (; av_read_frame(b->ic, b->pkt) >= 0; av_packet_unref(b->pkt)) {
				if (b->pkt->stream_index == b->a.idx) {
					if (avcodec_send_packet(b->a.ctx, b->pkt) < 0
					 || avcodec_receive_frame(b->a.ctx, b->frm) < 0) {
						continue;
					}
					data->input_frames = swr_convert(b->swr
					, (uint8_t **)&x->in, FRAMES
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
				n++; // don't iterate in case there's another track
				outlet_anything(p->o_meta, s_done, 0, 0);
			} else {
				ffplay_seek(x, 0);
				t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = p->play} };
				outlet_anything(p->o_meta, s_play, 1, &play);
				goto silence;
			}
		}
	} else while (n--) {
		silence:
		for (int i = nch; i--;) {
			*outs[i]++ = 0;
		}
	}
	return (w + 4);
}

static void ffplay_dsp(t_ffplay *x, t_signal **sp) {
	t_player *p = &x->b.p;
	for (int i = p->nch; i--;) {
		p->outs[i] = sp[i + 1]->s_vec;
	}
	dsp_add(ffplay_perform, 3, x, sp[0]->s_n, sp[0]->s_vec);
}

static err_t ffplay_reset(void *y) {
	t_ffplay *x = (t_ffplay *)y;
	t_ffbase *b = &x->b;
	swr_free(&b->swr);
	AVChannelLayout layout_in = ffbase_layout(b);
	swr_alloc_set_opts2(&b->swr
	, &b->layout, AV_SAMPLE_FMT_FLT   , b->a.ctx->sample_rate
	, &layout_in, b->a.ctx->sample_fmt, b->a.ctx->sample_rate
	, 0, NULL);
	if (swr_init(b->swr) < 0) {
		return "SWResampler initialization failed";
	}

	if (!x->r.state) {
		return "SRC has not been initialized";
	}
	rabbit_reset(&x->r);
	x->r.ratio = (double)x->b.a.ctx->sample_rate / sys_getsr();
	rabbit_speed(&x->r, x->speed.v);
	return 0;
}

static void *ffplay_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_ffplay *x = (t_ffplay *)ffbase_new(ffplay_class, ac, av);
	int err = rabbit_init(&x->r, ac);
	if (err) {
		player_free(&x->b.p);
		pd_free((t_pd *)x);
		return NULL;
	}
	t_inlet *in2 = signalinlet_new(&x->b.p.obj, (x->speed.v = 1.0));
	x->speed.p = &in2->iu_floatsignalvalue;
	x->in  = (t_sample *)getbytes(ac * FRAMES * sizeof(t_sample));
	x->out = (t_sample *)getbytes(ac * FRAMES * sizeof(t_sample));
	return x;
}

static void ffplay_free(t_ffplay *x) {
	ffbase_free(&x->b);
	src_delete(x->r.state);
	freebytes(x->in, x->b.p.nch * sizeof(t_sample) * FRAMES);
	freebytes(x->out, x->b.p.nch * sizeof(t_sample) * FRAMES);
}

void ffplay_tilde_setup(void) {
	ffbase_reset = ffplay_reset;
	ffplay_class = class_ffbase(gensym("ffplay~")
	, (t_newmethod)ffplay_new, (t_method)ffplay_free
	, sizeof(t_ffplay));

	class_addmethod(ffplay_class, (t_method)ffplay_dsp
	, gensym("dsp"), A_CANT, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_seek
	, gensym("seek"), A_FLOAT, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_speed
	, gensym("speed"), A_FLOAT, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_interp
	, gensym("interp"), A_FLOAT, 0);
}
