#include "player.h"
#include "playlist.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>

static t_symbol *s_done;
static t_symbol *s_pos;
static err_t (*ffbase_reset)(void *);

/* ---------------------- FFmpeg player (base class) ------------------------ */

typedef struct _avstream {
	AVCodecContext *ctx;
	int idx; /* stream index */
} t_avstream;

typedef struct _ffbase {
	t_player p;
	t_avstream a;   /* audio stream */
	t_avstream sub; /* subtitle stream */
	AVPacket *pkt;
	AVFrame *frm;
	SwrContext *swr;
	AVFormatContext *ic;
	AVChannelLayout layout;
	t_playlist plist;
} t_ffbase;

static void ffbase_seek(t_ffbase *x, t_float f) {
	if (!x->p.open) {
		return;
	}
	avformat_seek_file(x->ic, -1, 0, f * 1000, x->ic->duration, 0);
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	x->frm->pts = f * ratio.den / (ratio.num * 1000);
	swr_init(x->swr);

	// avcodec_flush_buffers(x->a.ctx); // doesn't always flush properly
	avcodec_free_context(&x->a.ctx);
	x->a.ctx = avcodec_alloc_context3(NULL);
	avcodec_parameters_to_context(x->a.ctx, x->ic->streams[x->a.idx]->codecpar);
	x->a.ctx->pkt_timebase = x->ic->streams[x->a.idx]->time_base;
	const AVCodec *codec = avcodec_find_decoder(x->a.ctx->codec_id);
	avcodec_open2(x->a.ctx, codec, NULL);
}

static void ffbase_position(t_ffbase *x) {
	if (!x->p.open) {
		return;
	}
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	t_float f = x->frm->pts * ratio.num * 1000 / (t_float)ratio.den;
	t_atom pos = { .a_type = A_FLOAT, .a_w = {.w_float = f} };
	outlet_anything(x->p.o_meta, s_pos, 1, &pos);
}

static inline err_t ffbase_context(t_ffbase *x, t_avstream *s) {
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

static err_t ffbase_stream(t_ffbase *x, t_avstream *s, int i, enum AVMediaType type) {
	if (!x->p.open || i == s->idx) {
		return 0;
	}
	if (i >= (int)x->ic->nb_streams) {
		return "Index out of bounds";
	}
	if (x->ic->streams[i]->codecpar->codec_type != type) {
		return "Stream type mismatch";
	}
	t_avstream stream = { .ctx = NULL, .idx = i };
	err_t err_msg = ffbase_context(x, &stream);
	if (err_msg) {
		return err_msg;
	}
	AVCodecContext *ctx = s->ctx;
	*s = stream;
	avcodec_free_context(&ctx);
	return 0;
}

static AVChannelLayout ffbase_layout(t_ffbase *x) {
	AVChannelLayout layout_in;
	if (x->a.ctx->ch_layout.u.mask) {
		av_channel_layout_from_mask(&layout_in, x->a.ctx->ch_layout.u.mask);
	} else {
		av_channel_layout_default(&layout_in, x->a.ctx->ch_layout.nb_channels);
	}
	return layout_in;
}

static void ffbase_audio(t_ffbase *x, t_float f) {
	err_t err_msg = ffbase_stream(x, &x->a, f, AVMEDIA_TYPE_AUDIO);
	if (err_msg) {
		logpost(x, PD_DEBUG, "ffbase_audio: %s.", err_msg);
	} else if ( (err_msg = ffbase_reset(x)) ) {
		logpost(x, PD_DEBUG, "ffbase_audio: %s.", err_msg);
		x->p.open = x->p.play = 0;
	}
}

static void ffbase_subtitle(t_ffbase *x, t_float f) {
	if (f < 0) {
		x->sub.idx = -1;
		return;
	}
	err_t err_msg = ffbase_stream(x, &x->sub, f, AVMEDIA_TYPE_SUBTITLE);
	if (err_msg) {
		logpost(x, PD_DEBUG, "ffbase_subtitle: %s.", err_msg);
	}
}

static err_t ffbase_load(t_ffbase *x, int index) {
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
	err_t err_msg = ffbase_context(x, &x->a);
	if (err_msg) {
		return err_msg;
	}
	x->frm->pts = 0;
	return ffbase_reset(x);
}

static void ffbase_open(t_ffbase *x, t_symbol *s) {
	x->p.play = 0;
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

		const char *ext = strrchr(sym, '.');
		if (ext && !strcmp(ext + 1, "m3u")) {
			err_msg = playlist_m3u(pl, s);
		} else {
			pl->size = 1;
			pl->arr[0] = gensym(fname);
		}
	}

	if (err_msg || (err_msg = ffbase_load(x, 0))) {
		pd_error(x, "ffbase_open: %s.", err_msg);
	}
	x->p.open = !err_msg;
	t_atom open = { .a_type = A_FLOAT, .a_w = {.w_float = x->p.open} };
	outlet_anything(x->p.o_meta, s_open, 1, &open);
}

static t_symbol *dict[11];

static t_atom ffbase_meta(void *y, t_symbol *s) {
	t_ffbase *x = (t_ffbase *)y;
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

static void ffbase_print(t_ffbase *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!x->p.open) {
		return post("No file opened.");
	}
	if (ac) {
		return player_info_custom(&x->p, ac, av);
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

static void ffbase_start(t_ffbase *x, t_float f, t_float ms) {
	int track = f;
	err_t err_msg = "";
	if (0 < track && track <= x->plist.size) {
		if ( (err_msg = ffbase_load(x, track - 1)) ) {
			pd_error(x, "ffbase_start: %s.", err_msg);
		} else if (ms > 0) {
			ffbase_seek(x, ms);
		}
		x->p.open = !err_msg;
	} else {
		ffbase_seek(x, 0);
	}
	x->p.play = !err_msg;
	t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = x->p.play} };
	outlet_anything(x->p.o_meta, s_play, 1, &play);
}

static void ffbase_list(t_ffbase *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	ffbase_start(x, atom_getfloatarg(0, ac, av), atom_getfloatarg(1, ac, av));
}

static void ffbase_float(t_ffbase *x, t_float f) {
	ffbase_start(x, f, 0);
}

static void ffbase_stop(t_ffbase *x) {
	ffbase_start(x, 0, 0);
	x->frm->pts = 0; // reset internal position
}

static t_ffbase *ffbase_new(t_class *cl, int ac, t_atom *av) {
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
		pd_error(0, "ffbase_new: invalid channel layout (%d).", err);
		return NULL;
	}

	t_ffbase *x = (t_ffbase *)player_new(cl, ac);
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

static void ffbase_free(t_ffbase *x) {
	av_channel_layout_uninit(&x->layout);
	avcodec_free_context(&x->a.ctx);
	avformat_close_input(&x->ic);
	av_packet_free(&x->pkt);
	av_frame_free(&x->frm);
	swr_free(&x->swr);

	t_playlist *pl = &x->plist;
	freebytes(pl->arr, pl->max * sizeof(t_symbol *));
	player_free(&x->p);
}

static t_class *class_ffbase
(t_symbol *s, t_newmethod newm, t_method free, size_t size) {
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
	fn_meta = ffbase_meta;

	t_class *cls = class_player(s, newm, free, size);
	class_addfloat(cls, ffbase_float);
	class_addlist(cls, ffbase_list);
	class_addmethod(cls, (t_method)ffbase_audio, gensym("audio"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)ffbase_subtitle, gensym("subtitle"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)ffbase_print, gensym("print"), A_GIMME, 0);
	class_addmethod(cls, (t_method)ffbase_open, gensym("open"), A_SYMBOL, 0);
	class_addmethod(cls, (t_method)ffbase_stop, gensym("stop"), A_NULL);
	class_addmethod(cls, (t_method)ffbase_position, gensym("pos"), A_NULL);
	return cls;
}
