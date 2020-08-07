#include "m_pd.h"
#include <stdio.h>
#include <string.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>

#define NCH 2
#define BUFSIZE 0x1200

typedef const char *err_t;

/* -------------------------- FFmpeg player -------------------------- */
static t_class *ffplay_class;

typedef struct _playlist {
	t_symbol **trk; /* m3u list of tracks */
	t_symbol *dir;  /* starting directory */
	int      siz;   /* size of the list */
	int      max;   /* list's current maximum capacity */
} t_playlist;

typedef struct _ffplay {
	t_object x_obj;
	AVFormatContext *ic;
	AVCodecContext  *ctx;
	AVPacket        *pkt;
	AVFrame         *frm;
	SwrContext      *swr;
	t_sample        *buf[NCH];
	t_playlist      plist;
	int      pos;     /* current buffer position */
	int      siz;     /* size of frame after resampling */
	int      idx;     /* index of the audio stream */
	unsigned open:1;  /* true when a file has been successfully opened */
	unsigned play:1;  /* play/pause toggle */
	t_outlet *o_meta; /* outputs track metadata */
} t_ffplay;

static void ffplay_time(t_ffplay *x) {
	if (!x->open) return;
	t_float f = x->ic->duration / 1000.; // AV_TIME_BASE is in microseconds
	t_atom time = { A_FLOAT, {f} };
	outlet_anything(x->o_meta, gensym("time:"), 1, &time);
}

static void ffplay_position(t_ffplay *x) {
	if (!x->open) return;
	AVRational ratio = x->ic->streams[x->idx]->time_base;
	t_float f = 1000. * x->frm->pts * ratio.num / ratio.den;
	t_atom pos = { A_FLOAT, {f} };
	outlet_anything(x->o_meta, gensym("pos:"), 1, &pos);
}

static void ffplay_seek(t_ffplay *x, t_floatarg f) {
	if (!x->open) return;
	int64_t ts = 1000L * f;
	avformat_seek_file(x->ic, -1, 0, ts, x->ic->duration, 0);
	swr_init(x->swr);
	x->siz = 0;

	// avcodec_flush_buffers(x->ctx); // doesn't always flush properly
	avcodec_free_context(&x->ctx);
	x->ctx = avcodec_alloc_context3(NULL);
	avcodec_parameters_to_context(x->ctx, x->ic->streams[x->idx]->codecpar);
	x->ctx->pkt_timebase = x->ic->streams[x->idx]->time_base;
	AVCodec *codec = avcodec_find_decoder(x->ctx->codec_id);
	avcodec_open2(x->ctx, codec, NULL);
}

static void ffplay_decode(t_ffplay *x, t_sample *outs[NCH]) {
	if (x->siz > 0) goto have_buf;
	while (av_read_frame(x->ic, x->pkt) >= 0)
	{	if (x->pkt->stream_index == x->idx)
		{	if (avcodec_send_packet(x->ctx, x->pkt) < 0
			 || avcodec_receive_frame(x->ctx, x->frm) < 0)
				return;
			x->siz = swr_convert(x->swr, (uint8_t**)&x->buf, BUFSIZE,
				(const uint8_t **)x->frm->extended_data, x->frm->nb_samples);
			av_packet_unref(x->pkt);
			x->pos = 0;
			goto have_buf;   }
		av_packet_unref(x->pkt);   }

	// reached the end
	x->play = 0;
	ffplay_seek(x, 0);
	outlet_anything(x->o_meta, gensym("EOF"), 0, 0);
	return;

	have_buf:
	for (int i=NCH; i--;)
		*outs[i]++ = x->buf[i][x->pos];
	if (++x->pos >= x->siz)
		x->siz = 0;
}

static t_int *ffplay_perform(t_int *w) {
	t_ffplay *x = (t_ffplay *)(w[1]);
	t_sample *outs[NCH];
	for (int i=NCH; i--;) outs[i] = (t_sample *)(w[i+2]);
	int n = (int)(w[NCH+2]);

	while (n--)
		if (x->open && x->play)
			ffplay_decode(x, outs);
		else for (int i=NCH; i--;)
			*outs[i]++ = 0;
	return (w+NCH+3);
}

static void ffplay_dsp(t_ffplay *x, t_signal **sp) {
	dsp_add(ffplay_perform, NCH+2, x,
		sp[0]->s_vec, sp[1]->s_vec, sp[0]->s_n);
}

static err_t ffplay_load(t_ffplay *x, const char *fname) {
	avformat_close_input(&x->ic);
	x->ic = avformat_alloc_context();
	if (avformat_open_input(&x->ic, fname, NULL, NULL) != 0)
		return "Couldn't open input stream";
	if (avformat_find_stream_info(x->ic, NULL) < 0)
		return "Couldn't find stream information";
	x->ic->seek2any = 1;

	int i = -1;
	for (unsigned j=0; j < x->ic->nb_streams; j++)
		if (x->ic->streams[j]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO)
		{	i = j;
			break;   }
	if (i < 0)
		return "No audio stream found";
	x->idx = i;

	avcodec_free_context(&x->ctx);
	x->ctx = avcodec_alloc_context3(NULL);
	if (!x->ctx)
		return "Out of memory";
	if (avcodec_parameters_to_context(x->ctx, x->ic->streams[i]->codecpar) < 0)
		return "Out of memory";
	x->ctx->pkt_timebase = x->ic->streams[i]->time_base;

	AVCodec *codec = avcodec_find_decoder(x->ctx->codec_id);
	if (!codec)
		return "Codec not found";
	if (avcodec_open2(x->ctx, codec, NULL) < 0)
		return "Could not open codec";

	swr_free(&x->swr);
	int out_sample_rate = sys_getsr();
	uint64_t layout_in = av_get_default_channel_layout(x->ctx->channels);
	x->swr = swr_alloc_set_opts(x->swr,
		AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_FLTP, out_sample_rate,
		layout_in, x->ctx->sample_fmt, x->ctx->sample_rate,
		0, NULL);
	if (swr_init(x->swr) < 0)
		return "Resampler initialization failed";

	x->siz = 0;
	return 0;
}

static err_t ffplay_m3u(t_ffplay *x, t_symbol *s) {
	int size = 0;
	char str[MAXPDSTRING];
	t_playlist *pl = &x->plist;
	FILE *fp = fopen(s->s_name, "r");
	if (!fp)
		return "Could not open m3u";

	while (fgets(str, MAXPDSTRING, fp) != NULL)
		size++;
	if (size > pl->max)
	{	pl->trk = (t_symbol**)resizebytes(pl->trk,
			pl->max * sizeof(t_symbol*), size * sizeof(t_symbol*));
		pl->max = size;   }
	pl->siz = size;
	rewind(fp);

	for (int i=0; fgets(str, MAXPDSTRING, fp) != NULL; i++)
	{	str[strcspn(str, "\r\n")] = 0;
		pl->trk[i] = gensym(str);   }

	fclose(fp);
	return 0;
}

static err_t ffplay_start(t_ffplay *x, int track) {
	char str[MAXPDSTRING];
	sprintf(str, "%s/%s",
		x->plist.dir->s_name,
		x->plist.trk[track-1]->s_name);
	err_t err_msg = ffplay_load(x, str);
	x->open = !err_msg;
	x->play = 0;
	return err_msg;
}

static void ffplay_open(t_ffplay *x, t_symbol *s) {
	int len = 0;
	err_t err_msg = 0;
	char str[MAXPDSTRING];

	const char *p = strrchr(s->s_name, '/');
	if (p)
	{	len = p - s->s_name;
		strncpy(str, s->s_name, len);
		p++;   }
	else
	{	len = 1;
		str[0] = '.';
		p = s->s_name;   }
	str[len] = 0;
	x->plist.dir = gensym(str);

	char *ext = strrchr(s->s_name, '.');
	if (ext && !strcmp(ext+1, "m3u"))
		err_msg = ffplay_m3u(x, s);
	else
	{	x->plist.siz = 1;
		x->plist.trk[0] = gensym(p);   }

	if (!err_msg) err_msg = ffplay_start(x, 1);
	if (err_msg) post("Error: %s.", err_msg);
	t_atom open = { A_FLOAT, {(t_float)x->open} };
	outlet_anything(x->o_meta, gensym("open:"), 1, &open);
}

static void ffplay_info_custom(AVDictionary *meta, int ac, t_atom *av) {
	for (; ac--; av++) if (av->a_type == A_SYMBOL)
	{	const char *sym = av->a_w.w_symbol->s_name, *pct, *end;
		while ( (pct = strchr(sym, '%')) && (end = strchr(pct+1, '%')) )
		{	int len = pct - sym;
			if (len)
			{	char before[len + 1];
				strncpy(before, sym, len);
				before[len] = 0;
				startpost("%s", before);
				sym += len;   }
			pct++;
			len = end - pct;
			char buf[len + 1];
			strncpy(buf, pct, len);
			buf[len] = 0;
			AVDictionaryEntry *entry = av_dict_get(meta, buf, 0, 0);
			if (entry)
				startpost("%s", entry->value);
			sym += len + 2;   }
		startpost("%s%s", sym, ac ? " ":"");   }
	endpost();
}

static void ffplay_info(t_ffplay *x, t_symbol *s, int ac, t_atom *av) {
	if (!x->open) return;
	AVDictionary *meta = x->ic->metadata;
	if (ac) return ffplay_info_custom(meta, ac, av);
	else
	{	AVDictionaryEntry *artist = av_dict_get(meta, "artist", 0, 0);
		AVDictionaryEntry *title  = av_dict_get(meta, "title", 0, 0);
		if (artist || title)
			post("%s%s%s",
				artist ? artist->value : "",
				artist ? " - " : "",
				title  ? title->value  : "");   }
}

static void ffplay_send(t_ffplay *x, t_symbol *s) {
	if (!x->open) return;
	AVDictionary *meta = x->ic->metadata;
	AVDictionaryEntry *entry = av_dict_get(meta, s->s_name, 0, 0);
	if (entry)
	{	int len = strlen(s->s_name);
		char key[len + 2];
		strcpy(key, s->s_name);
		strcpy(key+len, ":\0");
		t_atom val = { A_SYMBOL, {.w_symbol = gensym(entry->value)} };
		outlet_anything(x->o_meta, gensym(key), 1, &val);   }
}

static void ffplay_total(t_ffplay *x) {
	t_atom total = { A_FLOAT, {(t_float)x->plist.siz} };
	outlet_anything(x->o_meta, gensym("total:"), 1, &total);
}

static void ffplay_anything(t_ffplay *x, t_symbol *s, int ac, t_atom *av) {
	if (!x->open) return;
	if (!strcmp(s->s_name, "path") || !strcmp(s->s_name, "url"))
	{	post("%s", x->ic->url);
		return;   }
	if (!strcmp(s->s_name, "filename"))
	{	const char *name = strrchr(x->ic->url, '/');
		if (name) name++;
		else name = x->ic->url;
		post("%s", name);
		return;   }
	AVDictionaryEntry *entry = av_dict_get(x->ic->metadata, s->s_name, 0, 0);
	if (entry) post("%s", entry->value);
}

static void ffplay_bang(t_ffplay *x) {
	if (!x->open) return;
	x->play = !x->play;
	t_atom play = { A_FLOAT, {(t_float)x->play} };
	outlet_anything(x->o_meta, gensym("play:"), 1, &play);
}

static void ffplay_float(t_ffplay *x, t_float f) {
	if (!x->open) return;
	int d = f;
	if (d > 0 && d <= x->plist.siz)
	{	err_t err_msg = ffplay_start(x, d);
		if (err_msg) post("Error: %s.", err_msg);
		x->play = !err_msg;   }
	else
	{	x->play = d = 0;
		ffplay_seek(x, 0);   }
	t_atom play = { A_FLOAT, {(t_float)x->play} };
	outlet_anything(x->o_meta, gensym("play:"), 1, &play);
}

static void ffplay_stop(t_ffplay *x) {
	ffplay_float(x, 0);
}

static void *ffplay_new(t_floatarg f) {
	t_ffplay *x = (t_ffplay *)pd_new(ffplay_class);
	x->pkt = av_packet_alloc();
	x->frm = av_frame_alloc();
	for (int i=NCH; i--;)
		x->buf[i] = (t_sample*)getbytes(BUFSIZE * sizeof(t_sample));
	x->open = x->play = x->pos = x->siz = 0;

	x->plist.siz = 0;
	x->plist.max = 1;
	x->plist.trk = (t_symbol**)getbytes(sizeof(t_symbol*));

	outlet_new(&x->x_obj, &s_signal);
	outlet_new(&x->x_obj, &s_signal);
	x->o_meta = outlet_new(&x->x_obj, 0);
	return (x);
}

static void ffplay_free(t_ffplay *x) {
	avformat_close_input(&x->ic);
	avcodec_free_context(&x->ctx);
	av_packet_free(&x->pkt);
	av_frame_free(&x->frm);
	swr_free(&x->swr);
	for (int i=NCH; i--;)
		freebytes(x->buf[i], BUFSIZE * sizeof(t_sample));
}

void ffplay_tilde_setup(void) {
	ffplay_class = class_new(gensym("ffplay~"),
		(t_newmethod)ffplay_new, (t_method)ffplay_free,
		sizeof(t_ffplay), 0,
		A_DEFFLOAT, 0);
	class_addbang(ffplay_class, ffplay_bang);
	class_addfloat(ffplay_class, ffplay_float);
	class_addanything(ffplay_class, ffplay_anything);
	class_addmethod(ffplay_class, (t_method)ffplay_dsp,
		gensym("dsp"), A_CANT, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_seek,
		gensym("seek"), A_FLOAT, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_info,
		gensym("info"), A_GIMME, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_info,
		gensym("print"), A_GIMME, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_send,
		gensym("send"), A_SYMBOL, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_open,
		gensym("open"), A_SYMBOL, 0);
	class_addmethod(ffplay_class, (t_method)ffplay_bang,
		gensym("play"), A_NULL);
	class_addmethod(ffplay_class, (t_method)ffplay_stop,
		gensym("stop"), A_NULL);
	class_addmethod(ffplay_class, (t_method)ffplay_time,
		gensym("time"), A_NULL);
	class_addmethod(ffplay_class, (t_method)ffplay_position,
		gensym("pos"), A_NULL);
	class_addmethod(ffplay_class, (t_method)ffplay_total,
		gensym("total"), A_NULL);
}
