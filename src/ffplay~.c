#include "player.h"
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>

static t_symbol *s_done;
static t_symbol *s_pos;

typedef const char *err_t;

/* ------------------------- FFmpeg player ------------------------- */
static t_class *ffplay_class;

typedef struct {
	t_symbol **trk; /* m3u list of tracks */
	t_symbol *dir;  /* starting directory */
	int siz;        /* size of the list */
	int max;        /* size of the memory allocation */
} t_playlist;

typedef struct {
	AVCodecContext *ctx;
	int idx; /* stream index */
} t_avstream;

typedef struct {
	t_player z;
	t_avstream a; /* audio stream */
	AVPacket *pkt;
	AVFrame *frm;
	SwrContext *swr;
	AVFormatContext *ic;
	t_playlist plist;
	int64_t  layout; /* channel layout bit-mask */
} t_ffplay;

static void ffplay_seek(t_ffplay *x, t_float f) {
	if (!x->z.open) {
		return;
	}
	avformat_seek_file(x->ic, -1, 0, f * 1000, x->ic->duration, 0);
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	x->frm->pts = f * ratio.den / (ratio.num * 1000);
	player_reset(&x->z);
	swr_init(x->swr);

	// avcodec_flush_buffers(x->a.ctx); // doesn't always flush properly
	avcodec_free_context(&x->a.ctx);
	x->a.ctx = avcodec_alloc_context3(NULL);
	avcodec_parameters_to_context(x->a.ctx, x->ic->streams[x->a.idx]->codecpar);
	x->a.ctx->pkt_timebase = x->ic->streams[x->a.idx]->time_base;
	AVCodec *codec = avcodec_find_decoder(x->a.ctx->codec_id);
	avcodec_open2(x->a.ctx, codec, NULL);
}

static void ffplay_position(t_ffplay *x) {
	if (!x->z.open) {
		return;
	}
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	t_float f = x->frm->pts * ratio.num * 1000 / (t_float)ratio.den;
	t_atom pos = { .a_type = A_FLOAT, .a_w = {.w_float = f} };
	outlet_anything(x->z.o_meta, s_pos, 1, &pos);
}

static t_int *ffplay_perform(t_int *w) {
	t_ffplay *y = (t_ffplay *)(w[1]);
	int n = (int)w[3];

	t_player *x = &y->z;
	unsigned nch = x->nch;
	t_sample *outs[nch];
	for (int i = nch; i--;) {
		outs[i] = x->outs[i];
	}

	if (x->play) {
		t_sample *in2 = (t_sample *)(w[2]);
		SRC_DATA *data = &x->data;
		for (; n--; in2++) {
			if (data->output_frames_gen > 0) {
				perform:
				for (int i = nch; i--;) {
					*outs[i]++ = data->data_out[i];
				}
				data->data_out += nch;
				data->output_frames_gen--;
				continue;
			} else if (data->input_frames > 0) {
				resample:
				if (x->speed_ != *in2) {
					player_speed_(x, *in2);
				}
				data->data_out = x->out;
				src_process(x->state, data);
				data->input_frames -= data->input_frames_used;
				if (data->input_frames <= 0) {
					data->data_in = x->in;
					data->input_frames = swr_convert(y->swr
					, (uint8_t **)&x->in, FRAMES
					, 0, 0);
				} else {
					data->data_in += data->input_frames_used * nch;
				}
				goto perform;
			} else {	// receive
				data->data_in = x->in;
				for (; av_read_frame(y->ic, y->pkt) >= 0; av_packet_unref(y->pkt)) {
					if (y->pkt->stream_index == y->a.idx) {
						if (avcodec_send_packet(y->a.ctx, y->pkt) < 0
						 || avcodec_receive_frame(y->a.ctx, y->frm) < 0) {
							continue;
						}
						data->input_frames = swr_convert(y->swr
						, (uint8_t **)&x->in, FRAMES
						, (const uint8_t **)y->frm->extended_data, y->frm->nb_samples);
						av_packet_unref(y->pkt);
						goto resample;
					}
				}
			}

			// reached the end
			if (x->play) {
				x->play = 0;
				n++; // don't iterate in case there's another track
				outlet_anything(x->o_meta, s_done, 0, 0);
			} else {
				ffplay_seek(y, 0);
				t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = x->play} };
				outlet_anything(x->o_meta, s_play, 1, &play);
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

static void ffplay_dsp(t_ffplay *y, t_signal **sp) {
	t_player *x = &y->z;
	for (int i = x->nch; i--;) {
		x->outs[i] = sp[i + 1]->s_vec;
	}
	dsp_add(ffplay_perform, 3, y, sp[0]->s_vec, sp[0]->s_n);
}

static int m3u_size(FILE *fp, char *dir, int dlen) {
	int size = 0;
	char line[MAXPDSTRING];
	while (fgets(line, MAXPDSTRING, fp) != NULL) {
		line[strcspn(line, "\r\n")] = '\0';
		int isabs = (line[0] == '/');
		if ((isabs ? 0 : dlen) + strlen(line) >= MAXPDSTRING) {
			continue;
		}
		char *ext = strrchr(line, '.');
		if (ext && !strcmp(ext + 1, "m3u")) {
			strcpy(dir + dlen, line);
			char *fname = strrchr(line, '/');
			int len = (fname) ? ++fname - line : 0;
			FILE *m3u = fopen(dir, "r");
			if (m3u) {
				size += m3u_size(m3u, dir, dlen + len);
				fclose(m3u);
			}
		} else {
			size++;
		}
	}
	return size;
}

static int playlist_fill(t_playlist *pl, FILE *fp, char *dir, int dlen, int i) {
	char line[MAXPDSTRING];
	int oldlen = strlen(pl->dir->s_name);
	while (fgets(line, MAXPDSTRING, fp) != NULL) {
		line[strcspn(line, "\r\n")] = '\0';
		int isabs = (line[0] == '/');
		if ((isabs ? 0 : dlen) + strlen(line) >= MAXPDSTRING) {
			continue;
		}
		strcpy(dir + dlen, line);
		char *ext = strrchr(line, '.');
		if (ext && !strcmp(ext + 1, "m3u")) {
			char *fname = strrchr(line, '/');
			int len = (fname) ? ++fname - line : 0;
			FILE *m3u = fopen(dir, "r");
			if (m3u) {
				i = playlist_fill(pl, m3u, dir, dlen + len, i);
				fclose(m3u);
			}
		} else {
			pl->trk[i++] = gensym(dir + oldlen);
		}
	}
	return i;
}

static inline err_t ffplay_m3u(t_ffplay *x, t_symbol *s) {
	FILE *fp = fopen(s->s_name, "r");
	if (!fp) {
		return "Could not open m3u";
	}

	t_playlist *pl = &x->plist;
	char dir[MAXPDSTRING];
	strcpy(dir, pl->dir->s_name);
	int size = m3u_size(fp, dir, strlen(dir));
	if (size > pl->max) {
		pl->trk = (t_symbol **)resizebytes(pl->trk
		, pl->max * sizeof(t_symbol *), size * sizeof(t_symbol *));
		pl->max = size;
	}
	pl->siz = size;
	rewind(fp);

	playlist_fill(pl, fp, dir, strlen(pl->dir->s_name), 0);
	fclose(fp);
	return 0;
}

static inline err_t ffplay_stream(t_ffplay *x, t_avstream *s, enum AVMediaType type) {
	int i = -1;
	for (unsigned j = x->ic->nb_streams; j--;) {
		if (x->ic->streams[j]->codecpar->codec_type == type) {
			i = j;
			break;
		}
	}
	s->idx = i;
	if (i < 0) {
		post("stream type: %s", av_get_media_type_string(type));
		return "No stream found";
	}

	avcodec_free_context(&s->ctx);
	s->ctx = avcodec_alloc_context3(NULL);
	if (!s->ctx) {
		return "Out of memory";
	}
	if (avcodec_parameters_to_context(s->ctx, x->ic->streams[i]->codecpar) < 0) {
		return "Out of memory";
	}
	s->ctx->pkt_timebase = x->ic->streams[i]->time_base;

	AVCodec *codec = avcodec_find_decoder(s->ctx->codec_id);
	if (!codec) {
		return "Codec not found";
	}
	if (avcodec_open2(s->ctx, codec, NULL) < 0) {
		return "Could not open codec";
	}

	return 0;
}

static err_t ffplay_load(t_ffplay *x, int index) {
	if (!x->z.state) {
		return "SRC has not been initialized";
	}

	char url[MAXPDSTRING];
	const char *trk = x->plist.trk[index]->s_name;
	if (trk[0] == '/') { // absolute path
		strcpy(url, trk);
	} else {
		strcpy(url, x->plist.dir->s_name);
		strcat(url, trk);
	}

	avformat_close_input(&x->ic);
	x->ic = avformat_alloc_context();
	if (avformat_open_input(&x->ic, url, NULL, NULL) != 0) {
		return "Couldn't open input stream";
	}
	if (avformat_find_stream_info(x->ic, NULL) < 0) {
		return "Couldn't find stream information";
	}
	x->ic->seek2any = 1;

	err_t err_msg;
	if ((err_msg = ffplay_stream(x, &x->a, AVMEDIA_TYPE_AUDIO))) {
		return err_msg;
	}

	swr_free(&x->swr);
	int64_t layout_in = av_get_default_channel_layout(x->a.ctx->channels);
	x->swr = swr_alloc_set_opts(x->swr
	, x->layout, AV_SAMPLE_FMT_FLT, x->a.ctx->sample_rate
	, layout_in, x->a.ctx->sample_fmt, x->a.ctx->sample_rate
	, 0, NULL);
	if (swr_init(x->swr) < 0) {
		return "SWResampler initialization failed";
	}

	x->z.ratio = sys_getsr() / (double)x->a.ctx->sample_rate;
	player_speed_(&x->z, x->z.speed_);
	player_reset(&x->z);
	x->frm->pts = 0;
	return 0;
}

static void ffplay_open(t_ffplay *x, t_symbol *s) {
	x->z.play = 0;
	err_t err_msg = 0;
	const char *sym = s->s_name;
	if (strlen(sym) >= MAXPDSTRING) {
		err_msg = "File path is too long";
	} else {
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
		x->plist.dir = gensym(dir);

		char *ext = strrchr(sym, '.');
		if (ext && !strcmp(ext + 1, "m3u")) {
			err_msg = ffplay_m3u(x, s);
		} else {
			x->plist.siz = 1;
			x->plist.trk[0] = gensym(fname);
		}
	}

	if (err_msg || (err_msg = ffplay_load(x, 0))) {
		post("Error: %s.", err_msg);
	}
	x->z.open = !err_msg;
	t_atom open = { .a_type = A_FLOAT, .a_w = {.w_float = x->z.open} };
	outlet_anything(x->z.o_meta, s_open, 1, &open);
}

static t_symbol *dict[11];

static t_atom ffplay_meta(void *y, t_symbol *s) {
	t_ffplay *x = (t_ffplay *)y;
	t_atom meta;
	if (s == dict[0] || s == dict[1]) {
		SETSYMBOL(&meta, gensym(x->ic->url));
	} else if (s == dict[2]) {
		const char *name = strrchr(x->ic->url, '/');
		name = name ? name + 1 : x->ic->url;
		SETSYMBOL(&meta, gensym(name));
	} else if (s == dict[3]) {
		meta = player_time(x->ic->duration / 1000.);
	} else if (s == dict[4]) {
		meta = player_ftime(x->ic->duration / 1000);
	} else if (s == dict[5]) {
		SETFLOAT(&meta, x->plist.siz);
	} else if (s == dict[6]) {
		SETSYMBOL(&meta, gensym(av_get_sample_fmt_name(x->a.ctx->sample_fmt)));
	} else if (s == dict[7]) {
		SETFLOAT(&meta, x->a.ctx->sample_rate);
	} else if (s == dict[8]) {
		SETFLOAT(&meta, x->ic->bit_rate / 1000.);
	} else {
		AVDictionaryEntry *entry = av_dict_get(x->ic->metadata, s->s_name, 0, 0);
		if (!entry) { // try some aliases for common terms
			if (s == dict[9]) {
				if (!(entry = av_dict_get(x->ic->metadata, "time", 0, 0))
				 && !(entry = av_dict_get(x->ic->metadata, "tyer", 0, 0))
				 && !(entry = av_dict_get(x->ic->metadata, "tdat", 0, 0))
				 && !(entry = av_dict_get(x->ic->metadata, "tdrc", 0, 0))) {
				}
			} else if (s == dict[10]) {
				entry = av_dict_get(x->ic->metadata, "tbpm", 0, 0);
			}
		}

		if (entry) {
			SETSYMBOL(&meta, gensym(entry->value));
		} else {
			meta = (t_atom){ A_NULL, {0} };
		}
	}
	return meta;
}

static void ffplay_info(t_ffplay *x, t_symbol *s, int ac, t_atom *av) {
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
		post("%s%s%s"
		, artist ? artist->value : ""
		, " - "
		, title ? title->value : ""
		);
	}
}

static void ffplay_start(t_ffplay *x, t_float f, t_float ms) {
	int track = f;
	err_t err_msg = "";
	if (0 < track && track <= x->plist.siz) {
		if ( (err_msg = ffplay_load(x, track - 1)) ) {
			post("Error: %s.", err_msg);
		} else if (ms > 0) {
			ffplay_seek(x, ms);
		}
		x->z.open = !err_msg;
	} else {
		ffplay_seek(x, 0);
	}
	x->z.play = !err_msg;
	t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = x->z.play} };
	outlet_anything(x->z.o_meta, s_play, 1, &play);
}

static void ffplay_list(t_ffplay *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (ac > 1 && av[0].a_type == A_FLOAT && av[1].a_type == A_FLOAT) {
		ffplay_start(x, av[0].a_w.w_float, av[1].a_w.w_float);
	}
}

static void ffplay_float(t_ffplay *x, t_float f) {
	ffplay_start(x, f, 0);
}

static void ffplay_stop(t_ffplay *x) {
	ffplay_float(x, 0);
	x->frm->pts = 0; // reset internal position
}

static void *ffplay_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_atom defarg[2];
	if (!ac) {
		ac = 2;
		av = defarg;
		SETFLOAT(&defarg[0], 1);
		SETFLOAT(&defarg[1], 2);
	}

	t_ffplay *x = (t_ffplay *)player_new(ffplay_class, ac);
	x->pkt = av_packet_alloc();
	x->frm = av_frame_alloc();

	// channel layout masking details: libavutil/channel_layout.h
	x->layout = 0;
	for (int i = ac; i--;) {
		int ch = atom_getfloatarg(i, ac, av);
		if (ch > 0) {
			x->layout |= 1 << (ch - 1);
		}
	}

	x->plist.siz = 0;
	x->plist.max = 1;
	x->plist.trk = (t_symbol **)getbytes(sizeof(t_symbol *));
	return x;
}

static void ffplay_free(t_ffplay *x) {
	avcodec_free_context(&x->a.ctx);
	avformat_close_input(&x->ic);
	av_packet_free(&x->pkt);
	av_frame_free(&x->frm);
	swr_free(&x->swr);

	t_playlist *pl = &x->plist;
	freebytes(pl->trk, pl->max * sizeof(t_symbol *));
	player_free(&x->z);
}

void ffplay_tilde_setup(void) {
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
	fn_meta = ffplay_meta;

	ffplay_class = class_player(gensym("ffplay~")
	, (t_newmethod)ffplay_new, (t_method)ffplay_free
	, sizeof(t_ffplay));
	class_addfloat(ffplay_class, ffplay_float);
	class_addlist(ffplay_class, ffplay_list);

	class_addmethod(ffplay_class, (t_method)ffplay_dsp, gensym("dsp"), A_CANT, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_seek, gensym("seek"), A_FLOAT, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_info, gensym("info"), A_GIMME, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_info, gensym("print"), A_GIMME, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_open, gensym("open"), A_SYMBOL, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_stop, gensym("stop"), A_NULL);
	class_addmethod(ffplay_class, (t_method)ffplay_position, gensym("pos"), A_NULL);
}
