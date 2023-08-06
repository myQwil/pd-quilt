#include "player.h"
#include "playlist.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include <rubberband/rubberband-c.h>

#define BUFSIZE  0x01
#define SPEED    0x10

static const t_float fastest = 1.0 * SPEED;
static const t_float slowest = 1.0 / SPEED;
static t_symbol *s_done;
static t_symbol *s_pos;

/* ------------------------- FFmpeg player ------------------------- */
static t_class *ffband_class;

typedef struct _buffer {
	t_sample **buf;
	unsigned size;
} t_buffer;

typedef struct _vinlet {
	t_float *p; // inlet pointer
	t_float v; // internal value
} t_vinlet;

typedef struct _avstream {
	AVCodecContext *ctx;
	int idx; /* stream index */
} t_avstream;

typedef struct _ffband {
	t_player z;
	t_buffer in;
	t_vinlet tempo;
	t_vinlet pitch;
	t_avstream a;     /* audio stream */
	t_avstream sub;   /* subtitle stream */
	RubberBandState state;
	AVPacket *pkt;
	AVFrame *frm;
	SwrContext *swr;
	AVFormatContext *ic;
	AVChannelLayout layout;
	t_playlist plist;
} t_ffband;

static void ffband_seek(t_ffband *x, t_float f) {
	if (!x->z.open) {
		return;
	}
	avformat_seek_file(x->ic, -1, 0, f * 1000, x->ic->duration, 0);
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	x->frm->pts = f * ratio.den / (ratio.num * 1000);
	rubberband_reset(x->state);
	swr_init(x->swr);

	// avcodec_flush_buffers(x->a.ctx); // doesn't always flush properly
	avcodec_free_context(&x->a.ctx);
	x->a.ctx = avcodec_alloc_context3(NULL);
	avcodec_parameters_to_context(x->a.ctx, x->ic->streams[x->a.idx]->codecpar);
	x->a.ctx->pkt_timebase = x->ic->streams[x->a.idx]->time_base;
	const AVCodec *codec = avcodec_find_decoder(x->a.ctx->codec_id);
	avcodec_open2(x->a.ctx, codec, NULL);
}

static void ffband_position(t_ffband *x) {
	if (!x->z.open) {
		return;
	}
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	t_float f = x->frm->pts * ratio.num * 1000 / (t_float)ratio.den;
	t_atom pos = { .a_type = A_FLOAT, .a_w = {.w_float = f} };
	outlet_anything(x->z.o_meta, s_pos, 1, &pos);
}

static void ffband_tempo(t_ffband *x, t_float f) {
	*x->tempo.p = f;
}

static void ffband_pitch(t_ffband *x, t_float f) {
	*x->pitch.p = f;
}

static t_int *ffband_perform(t_int *w) {
	t_ffband *y = (t_ffband *)(w[1]);
	t_player *x = &y->z;

	int n = (int)(w[2]);
	unsigned nch = x->nch;
	t_sample *outs[nch];
	for (int i = nch; i--;) {
		outs[i] = x->outs[i];
	}

	if (x->play) {
		t_sample *in2 = (t_sample *)(w[3]);
		t_sample *in3 = (t_sample *)(w[4]);
		RubberBandState state = y->state;
		t_buffer *in = &y->in;

		perform:
		int m = rubberband_available(state);
		if (m > 0) {
			m = rubberband_retrieve(state, outs, m < n ? m : n);
			if (m >= n) {
				return (w + 5);
			}
			n -= m, in2 += m, in3 += m;
			for (int i = nch; i--;) {
				outs[i] += m;
			}
		}
		y->tempo.v = *in2 > fastest ? fastest : (*in2 < slowest ? slowest : *in2);
		y->pitch.v = *in3 > fastest ? fastest : (*in3 < slowest ? slowest : *in3);
		rubberband_set_time_ratio(state, 1.0 / y->tempo.v);
		rubberband_set_pitch_scale(state, y->pitch.v);
		process:
		if (in->size > 0) {
			rubberband_process(state, (const float *const *)in->buf, in->size, 0);
			in->size = swr_convert(y->swr, (uint8_t **)in->buf, BUFSIZE, 0, 0);
			goto perform;
		}
		receive:
		for (; av_read_frame(y->ic, y->pkt) >= 0; av_packet_unref(y->pkt)) {
			if (y->pkt->stream_index == y->a.idx) {
				if (avcodec_send_packet(y->a.ctx, y->pkt) < 0
				 || avcodec_receive_frame(y->a.ctx, y->frm) < 0) {
					continue;
				}
				in->size = swr_convert(y->swr, (uint8_t **)in->buf, BUFSIZE
				, (const uint8_t **)y->frm->extended_data, y->frm->nb_samples);
				av_packet_unref(y->pkt);
				goto process;
			} else if (y->pkt->stream_index == y->sub.idx) {
				int got;
				AVSubtitle sub;
				if (avcodec_decode_subtitle2(y->sub.ctx, &sub, &got, y->pkt) >= 0 && got) {
					post("\n%s", y->pkt->data);
				}
			}
		}

		// reached the end
		if (x->play) {
			x->play = 0;
			outlet_anything(x->o_meta, s_done, 0, 0);
			goto receive;
		} else {
			ffband_seek(y, 0);
			t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = x->play} };
			outlet_anything(x->o_meta, s_play, 1, &play);
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

static void ffband_dsp(t_ffband *y, t_signal **sp) {
	t_player *x = &y->z;
	for (int i = x->nch; i--;) {
		x->outs[i] = sp[i + 2]->s_vec;
	}
	dsp_add(ffband_perform, 4, y, sp[0]->s_n, sp[0]->s_vec, sp[1]->s_vec);
}

static inline err_t ffband_context(t_ffband *x, t_avstream *s) {
	int i = s->idx;
	avcodec_free_context(&s->ctx);
	s->ctx = avcodec_alloc_context3(NULL);
	if (!s->ctx) {
		return "Failed to allocate AVCodecContext";
	}
	if (avcodec_parameters_to_context(s->ctx, x->ic->streams[i]->codecpar) < 0) {
		return "Failed to fill codec with parameters";
	}
	s->ctx->pkt_timebase = x->ic->streams[i]->time_base;

	const AVCodec *codec = avcodec_find_decoder(s->ctx->codec_id);
	if (!codec) {
		return "Codec not found";
	}
	if (avcodec_open2(s->ctx, codec, NULL) < 0) {
		return "Failed to open codec";
	}

	return 0;
}

static err_t ffband_stream(t_ffband *x, t_avstream *s, int i, enum AVMediaType type) {
	if (!x->z.open || i == s->idx) {
		return 0;
	}
	if (i >= (int)x->ic->nb_streams) {
		return "Index out of bounds";
	}
	if (x->ic->streams[i]->codecpar->codec_type != type) {
		return "Stream type mismatch";
	}
	t_avstream stream = { .ctx = NULL, .idx = i };
	err_t err_msg = ffband_context(x, &stream);
	if (err_msg) {
		return err_msg;
	}
	AVCodecContext *ctx = s->ctx;
	*s = stream;
	avcodec_free_context(&ctx);
	return 0;
}

static err_t ffband_swr(t_ffband *x) {
	swr_free(&x->swr);
	AVChannelLayout layout_in;
	if (x->a.ctx->ch_layout.u.mask) {
		av_channel_layout_from_mask(&layout_in, x->a.ctx->ch_layout.u.mask);
	} else {
		av_channel_layout_default(&layout_in, x->a.ctx->ch_layout.nb_channels);
	}
	swr_alloc_set_opts2(&x->swr
	, &x->layout, AV_SAMPLE_FMT_FLTP  , sys_getsr()
	, &layout_in, x->a.ctx->sample_fmt, x->a.ctx->sample_rate
	, 0, NULL);
	if (swr_init(x->swr) < 0) {
		return "SWResampler initialization failed";
	}
	return 0;
}

static void ffband_audio(t_ffband *x, t_float f) {
	err_t err_msg = ffband_stream(x, &x->a, f, AVMEDIA_TYPE_AUDIO);
	if (err_msg) {
		logpost(x, PD_DEBUG, "ffband_audio: %s.", err_msg);
	} else if ( (err_msg = ffband_swr(x)) ) {
		logpost(x, PD_DEBUG, "ffband_audio: %s.", err_msg);
		x->z.open = x->z.play = 0;
	}
}

static void ffband_subtitle(t_ffband *x, t_float f) {
	if (f < 0) {
		x->sub.idx = -1;
		return;
	}
	err_t err_msg = ffband_stream(x, &x->sub, f, AVMEDIA_TYPE_SUBTITLE);
	if (err_msg) {
		logpost(x, PD_DEBUG, "ffband_subtitle: %s.", err_msg);
	}
}

static err_t ffband_load(t_ffband *x, int index) {
	char url[MAXPDSTRING];
	const char *fname = x->plist.arr[index]->s_name;
	if (fname[0] == '/') { // absolute path
		strcpy(url, fname);
	} else {
		strcpy(url, x->plist.dir->s_name);
		strcat(url, fname);
	}

	avformat_close_input(&x->ic);
	x->ic = avformat_alloc_context();
	if (avformat_open_input(&x->ic, url, NULL, NULL) != 0) {
		return "Failed to open input stream";
	}
	if (avformat_find_stream_info(x->ic, NULL) < 0) {
		return "Failed to find stream information";
	}
	x->ic->seek2any = 1;

	int i = -1;
	for (unsigned j = x->ic->nb_streams; j--;) {
		if (x->ic->streams[j]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
			i = j;
			break;
		}
	}
	x->a.idx = i;
	if (i < 0) {
		return "No audio stream found";
	}
	err_t err_msg = ffband_context(x, &x->a);
	if (err_msg) {
		return err_msg;
	}
	x->in.size = 0;
	x->frm->pts = 0;
	rubberband_reset(x->state);

	// pad rubberband's buffer with silence
	unsigned nch = x->z.nch;
	unsigned pad = rubberband_get_preferred_start_pad(x->state);
	t_sample **buf = (t_sample **)getbytes(nch * sizeof(t_sample *));
	for (i = nch; i--;) {
		buf[i] = (t_sample *)getbytes(pad * sizeof(t_sample));
	}
	rubberband_process(x->state, (const float *const *)buf, pad, 0);
	for (i = nch; i--;) {
		freebytes(buf[i], pad * sizeof(t_sample));
	}
	freebytes(buf, nch * sizeof(t_sample *));

	return ffband_swr(x);
}

static void ffband_open(t_ffband *x, t_symbol *s) {
	x->z.play = 0;
	err_t err_msg = 0;
	const char *sym = s->s_name;
	if (strlen(sym) >= MAXPDSTRING) {
		err_msg = "File path is too long";
	} else {
		t_playlist *pl = &x->plist;
		char dir[MAXPDSTRING];
		const char *fname = strrchr(sym, '/');
		if (fname) {
			int len = ++fname - sym;
			strncpy(dir, sym, len);
			dir[len] = '\0';
		} else {
			fname = sym;
			strcpy(dir, "./");
		}
		pl->dir = gensym(dir);

		char *ext = strrchr(sym, '.');
		if (ext && !strcmp(ext + 1, "m3u")) {
			err_msg = playlist_m3u(pl, s);
		} else {
			pl->size = 1;
			pl->arr[0] = gensym(fname);
		}
	}

	if (err_msg || (err_msg = ffband_load(x, 0))) {
		pd_error(x, "ffband_open: %s.", err_msg);
	}
	x->z.open = !err_msg;
	t_atom open = { .a_type = A_FLOAT, .a_w = {.w_float = x->z.open} };
	outlet_anything(x->z.o_meta, s_open, 1, &open);
}

static t_symbol *dict[11];

static t_atom ffband_meta(void *y, t_symbol *s) {
	t_ffband *x = (t_ffband *)y;
	t_atom meta;
	if (s == dict[0] || s == dict[1]) { // path || url
		SETSYMBOL(&meta, gensym(x->ic->url));
	} else if (s == dict[2]) { // filename
		const char *name = strrchr(x->ic->url, '/');
		name = name ? name + 1 : x->ic->url;
		SETSYMBOL(&meta, gensym(name));
	} else if (s == dict[3]) { // time
		meta = player_time(x->ic->duration / 1000.);
	} else if (s == dict[4]) { // ftime
		meta = player_ftime(x->ic->duration / 1000);
	} else if (s == dict[5]) { // tracks
		SETFLOAT(&meta, x->plist.size);
	} else if (s == dict[6]) { // samplefmt
		SETSYMBOL(&meta, gensym(av_get_sample_fmt_name(x->a.ctx->sample_fmt)));
	} else if (s == dict[7]) { // samplerate
		SETFLOAT(&meta, x->a.ctx->sample_rate);
	} else if (s == dict[8]) { // bitrate
		SETFLOAT(&meta, x->ic->bit_rate / 1000.);
	} else {
		AVDictionaryEntry *entry = av_dict_get(x->ic->metadata, s->s_name, 0, 0);
		if (!entry) { // try some aliases for common terms
			if (s == dict[9]) { // date
				if (!(entry = av_dict_get(x->ic->metadata, "time", 0, 0))
				 && !(entry = av_dict_get(x->ic->metadata, "tyer", 0, 0))
				 && !(entry = av_dict_get(x->ic->metadata, "tdat", 0, 0))
				 && !(entry = av_dict_get(x->ic->metadata, "tdrc", 0, 0))) {
				}
			} else if (s == dict[10]) { // bpm
				entry = av_dict_get(x->ic->metadata, "tbpm", 0, 0);
			}
		}

		if (entry) {
			SETSYMBOL(&meta, gensym(entry->value));
		} else {
			meta = (t_atom){ A_SYMBOL, {.w_symbol = &s_bang} };
		}
	}
	return meta;
}

static void ffband_print(t_ffband *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!x->z.open) {
		return post("No file opened.");
	}
	if (ac) {
		return player_info_custom(&x->z, ac, av);
	}

	AVDictionary *meta = x->ic->metadata;
	AVDictionaryEntry *artist = av_dict_get(meta, "artist", 0, 0);
	AVDictionaryEntry *title = av_dict_get(meta, "title", 0, 0);
	if (artist || title) {
		// general track info: %artist% - %title%
		post("%s%s%s"
		, artist ? artist->value : ""
		, " - "
		, title ? title->value : ""
		);
	}
}

static void ffband_start(t_ffband *x, t_float f, t_float ms) {
	int track = f;
	err_t err_msg = "";
	if (0 < track && track <= x->plist.size) {
		if ( (err_msg = ffband_load(x, track - 1)) ) {
			pd_error(x, "ffband_start: %s.", err_msg);
		} else if (ms > 0) {
			ffband_seek(x, ms);
		}
		x->z.open = !err_msg;
	} else {
		ffband_seek(x, 0);
	}
	x->z.play = !err_msg;
	t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = x->z.play} };
	outlet_anything(x->z.o_meta, s_play, 1, &play);
}

static void ffband_list(t_ffband *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	ffband_start(x, atom_getfloatarg(0, ac, av), atom_getfloatarg(1, ac, av));
}

static void ffband_float(t_ffband *x, t_float f) {
	ffband_start(x, f, 0);
}

static void ffband_stop(t_ffband *x) {
	ffband_start(x, 0, 0);
	x->frm->pts = 0; // reset internal position
}

static void *ffband_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_atom defarg[2] = {
	  { .a_type = A_FLOAT, .a_w = {.w_float = 1} }
	, { .a_type = A_FLOAT, .a_w = {.w_float = 2} }
	};
	if (!ac) {
		ac = 2;
		av = defarg;
	}

	// channel layout masking details: libavutil/channel_layout.h
	uint64_t mask = 0;
	AVChannelLayout layout;
	for (int i = ac; i--;) {
		int ch = atom_getfloatarg(i, ac, av);
		if (ch > 0) {
			mask |= 1 << (ch - 1);
		}
	}
	int err = av_channel_layout_from_mask(&layout, mask);
	if (err) {
		pd_error(0, "ffband_new: invalid channel layout (%d).", err);
		return NULL;
	}

	t_ffband *x = (t_ffband *)player_new(ffband_class, ac);
	t_inlet *in2 = signalinlet_new(&x->z.obj, (x->tempo.v = 1.0));
	x->tempo.p = &in2->iu_floatsignalvalue;
	t_inlet *in3 = signalinlet_new(&x->z.obj, (x->pitch.v = 1.0));
	x->pitch.p = &in3->iu_floatsignalvalue;

	RubberBandOptions options = RubberBandOptionProcessRealTime
	| RubberBandOptionEngineFiner;
	x->state = rubberband_new(sys_getsr(), ac, options, x->tempo.v, x->pitch.v);

	x->in.buf = (t_sample **)getbytes(ac * sizeof(t_sample *));
	for (int i = ac; i--;) {
		x->in.buf[i] = (t_sample *)getbytes(BUFSIZE * sizeof(t_sample));
	}
	x->in.size = 0;

	x->pkt = av_packet_alloc();
	x->frm = av_frame_alloc();
	x->layout = layout;
	x->sub.idx = -1;

	t_playlist *pl = &x->plist;
	pl->size = 0;
	pl->max = 1;
	pl->arr = (t_symbol **)getbytes(pl->max * sizeof(t_symbol *));
	return x;
}

static void ffband_free(t_ffband *x) {
	av_channel_layout_uninit(&x->layout);
	avcodec_free_context(&x->a.ctx);
	avformat_close_input(&x->ic);
	av_packet_free(&x->pkt);
	av_frame_free(&x->frm);
	swr_free(&x->swr);

	t_playlist *pl = &x->plist;
	freebytes(pl->arr, pl->max * sizeof(t_symbol *));
	player_free(&x->z);

	for (int i = x->z.nch; i--;) {
		freebytes(x->in.buf[i], BUFSIZE * sizeof(t_sample));
	}
	freebytes(x->in.buf, x->z.nch * sizeof(t_sample *));
}

void ffband_tilde_setup(void) {
	dict[0] = gensym("path");
	dict[1] = gensym("url");
	dict[2] = gensym("filename");
	dict[3] = gensym("time");
	dict[4] = gensym("ftime");
	dict[5] = gensym("tracks");
	dict[6] = gensym("samplefmt");
	dict[7] = gensym("samplerate");
	dict[8] = gensym("bitrate");
	dict[9] = gensym("date");
	dict[10] = gensym("bpm");

	s_done = gensym("done");
	s_pos = gensym("pos");
	fn_meta = ffband_meta;

	ffband_class = class_player(gensym("ffband~")
	, (t_newmethod)ffband_new, (t_method)ffband_free
	, sizeof(t_ffband));
	class_addfloat(ffband_class, ffband_float);
	class_addlist(ffband_class, ffband_list);

	class_addmethod(ffband_class, (t_method)ffband_dsp
	, gensym("dsp"), A_CANT, 0);
	class_addmethod(ffband_class, (t_method)ffband_seek
	, gensym("seek"), A_FLOAT, 0);
	class_addmethod(ffband_class, (t_method)ffband_pitch
	, gensym("pitch"), A_FLOAT, 0);
	class_addmethod(ffband_class, (t_method)ffband_tempo
	, gensym("tempo"), A_FLOAT, 0);
	class_addmethod(ffband_class, (t_method)ffband_audio
	, gensym("audio"), A_FLOAT, 0);
	class_addmethod(ffband_class, (t_method)ffband_subtitle
	, gensym("subtitle"), A_FLOAT, 0);
	class_addmethod(ffband_class, (t_method)ffband_print
	, gensym("print"), A_GIMME, 0);
	class_addmethod(ffband_class, (t_method)ffband_open
	, gensym("open"), A_SYMBOL, 0);
	class_addmethod(ffband_class, (t_method)ffband_stop
	, gensym("stop"), 0);
	class_addmethod(ffband_class, (t_method)ffband_position
	, gensym("pos"), 0);
}
