#include "m_pd.h"
#include <samplerate.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>

#define FRAMES 0x10
#define MAXCH 30

static const double frames = FRAMES;
static const double inv_frames = 1. / FRAMES;

static t_symbol *s_open;
static t_symbol *s_play;
static t_symbol *s_done;
static t_symbol *s_pos;

typedef const char *err_t;

/* ------------------------- FFmpeg player ------------------------- */
static t_class *ffplay_class;

typedef struct {
	t_symbol **trk; /* m3u list of tracks */
	t_symbol  *dir; /* starting directory */
	int        siz; /* size of the list */
	int        max; /* size of the memory allocation */
} t_playlist;

typedef struct {
	AVCodecContext *ctx;
	int             idx; /* stream index */
} t_avstream;

typedef struct {
	t_object obj;
	float      *in;
	float      *out;
	SRC_DATA     data;
	SRC_STATE   *state;
	t_avstream       a;   /* audio stream */
	AVPacket        *pkt;
	AVFrame         *frm;
	SwrContext      *swr;
	AVFormatContext *ic;
	t_sample  *outs[MAXCH];
	t_playlist plist;
	int64_t  layout;  /* channel layout bit-mask */
	t_float  speed;   /* playback speed */
	double   ratio;   /* resampling ratio */
	unsigned nch;     /* number of channels */
	unsigned open:1;  /* true when a file has been successfully opened */
	unsigned play:1;  /* play/pause toggle */
	t_outlet *o_meta; /* outputs track metadata */
} t_ffplay;

static inline void ffplay_reset_src(t_ffplay *x) {
	src_reset(x->state);
	x->data.output_frames_gen = 0;
	x->data.input_frames = 0;
}

static void ffplay_seek(t_ffplay *x ,t_float f) {
	if (!x->open) return; // quietly
	avformat_seek_file(x->ic ,-1 ,0 ,f * 1000 ,x->ic->duration ,0);
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	x->frm->pts = f * ratio.den / (ratio.num * 1000);
	ffplay_reset_src(x);
	swr_init(x->swr);

	// avcodec_flush_buffers(x->a.ctx); // doesn't always flush properly
	avcodec_free_context(&x->a.ctx);
	x->a.ctx = avcodec_alloc_context3(NULL);
	avcodec_parameters_to_context(x->a.ctx ,x->ic->streams[x->a.idx]->codecpar);
	x->a.ctx->pkt_timebase = x->ic->streams[x->a.idx]->time_base;
	AVCodec *codec = avcodec_find_decoder(x->a.ctx->codec_id);
	avcodec_open2(x->a.ctx ,codec ,NULL);
}

static void ffplay_position(t_ffplay *x) {
	if (!x->open) return; // quietly
	AVRational ratio = x->ic->streams[x->a.idx]->time_base;
	t_float f = x->frm->pts * ratio.num * 1000 / (t_float)ratio.den;
	t_atom pos = { .a_type=A_FLOAT ,.a_w={.w_float = f} };
	outlet_anything(x->o_meta ,s_pos ,1 ,&pos);
}

static t_int *ffplay_perform(t_int *w) {
	t_ffplay *x = (t_ffplay*)(w[1]);
	unsigned nch = x->nch;
	t_sample *outs[nch];
	for (int i = nch; i--;)
		outs[i] = x->outs[i];
	int n = (int)w[2];

	if (x->play)
	{	SRC_DATA *data = &x->data;
		while (n--)
		{	if (data->output_frames_gen > 0)
			{	perform:
				for (int i = nch; i--;)
					*outs[i]++ = data->data_out[i];
				data->data_out += nch;
				data->output_frames_gen--;
				continue;
			}
			else if (data->input_frames > 0)
			{	resample:
				data->data_out = x->out;
				src_process(x->state ,data);
				data->input_frames -= data->input_frames_used;
				if (data->input_frames <= 0)
				{	data->data_in = x->in;
					data->input_frames =
						swr_convert(x->swr ,(uint8_t**)&x->in ,FRAMES ,0 ,0);  }
				else data->data_in += data->input_frames_used * nch;
				goto perform;
			}
			else
			{	// receive
				data->data_in = x->in;
				for (; av_read_frame(x->ic ,x->pkt) >= 0; av_packet_unref(x->pkt))
				{	if (x->pkt->stream_index == x->a.idx)
					{	if (avcodec_send_packet(x->a.ctx ,x->pkt) < 0
						 || avcodec_receive_frame(x->a.ctx ,x->frm) < 0)
							continue;
						data->input_frames = swr_convert(x->swr ,(uint8_t**)&x->in ,FRAMES
							,(const uint8_t**)x->frm->extended_data ,x->frm->nb_samples);
						av_packet_unref(x->pkt);
						goto resample;  }  }
			}

			// reached the end
			if (x->play)
			{	x->play = 0;
				n++; // don't iterate in case there's another track
				outlet_anything(x->o_meta ,s_done ,0 ,0);  }
			else
			{	ffplay_seek(x ,0);
				goto silence;  }
		}
	}
	else while (n--)
	{	silence:
		for (int i = nch; i--;)
			*outs[i]++ = 0;  }
	return (w+3);
}

static void ffplay_dsp(t_ffplay *x ,t_signal **sp) {
	for (int i = x->nch; i--;)
		x->outs[i] = sp[i]->s_vec;
	dsp_add(ffplay_perform ,2 ,x ,sp[0]->s_n);
}

static void ffplay_speed(t_ffplay *x ,t_float f) {
	x->speed = f;
	f *= x->ratio;
	f = f > frames ? frames : (f < inv_frames ? inv_frames : f);
	x->data.src_ratio = 1. / f;
}

static inline err_t ffplay_m3u(t_ffplay *x ,t_symbol *s) {
	int size = 0;
	char str[MAXPDSTRING];
	t_playlist *pl = &x->plist;
	FILE *fp = fopen(s->s_name ,"r");
	if (!fp)
		return "Could not open m3u";

	while (fgets(str ,MAXPDSTRING ,fp) != NULL)
		size++;
	if (size > pl->max)
	{	pl->trk = (t_symbol**)resizebytes(pl->trk
			,pl->max * sizeof(t_symbol*) ,size * sizeof(t_symbol*));
		pl->max = size;  }
	pl->siz = size;
	rewind(fp);

	for (int i=0; fgets(str ,MAXPDSTRING ,fp) != NULL; i++)
	{	str[strcspn(str ,"\r\n")] = 0;
		pl->trk[i] = gensym(str);  }

	fclose(fp);
	return 0;
}

static inline err_t ffplay_stream(t_ffplay *x ,t_avstream *s ,enum AVMediaType type) {
	int i = -1;
	for (unsigned j = x->ic->nb_streams; j--;)
		if (x->ic->streams[j]->codecpar->codec_type == type)
		{	i = j;
			break;  }
	s->idx = i;
	if (i < 0)
	{	post("stream type: %s" ,av_get_media_type_string(type));
		return "No stream found";  }

	avcodec_free_context(&s->ctx);
	s->ctx = avcodec_alloc_context3(NULL);
	if (!s->ctx)
		return "Out of memory";
	if (avcodec_parameters_to_context(s->ctx ,x->ic->streams[i]->codecpar) < 0)
		return "Out of memory";
	s->ctx->pkt_timebase = x->ic->streams[i]->time_base;

	AVCodec *codec = avcodec_find_decoder(s->ctx->codec_id);
	if (!codec)
		return "Codec not found";
	if (avcodec_open2(s->ctx ,codec ,NULL) < 0)
		return "Could not open codec";

	return 0;
}

static err_t ffplay_load(t_ffplay *x ,int track) {
	if (!x->state)
		return "SRC has not been initialized";
	char fname[MAXPDSTRING];
	sprintf(fname ,"%s/%s"
		,x->plist.dir->s_name
		,x->plist.trk[track-1]->s_name);

	avformat_close_input(&x->ic);
	x->ic = avformat_alloc_context();
	if (avformat_open_input(&x->ic ,fname ,NULL ,NULL) != 0)
		return "Couldn't open input stream";
	if (avformat_find_stream_info(x->ic ,NULL) < 0)
		return "Couldn't find stream information";
	x->ic->seek2any = 1;

	err_t err_msg = ffplay_stream(x ,&x->a ,AVMEDIA_TYPE_AUDIO);
	if (err_msg) return err_msg;

	swr_free(&x->swr);
	int64_t layout_in = av_get_default_channel_layout(x->a.ctx->channels);
	x->swr = swr_alloc_set_opts(x->swr
		,x->layout ,AV_SAMPLE_FMT_FLT  ,x->a.ctx->sample_rate
		,layout_in ,x->a.ctx->sample_fmt ,x->a.ctx->sample_rate
		,0 ,NULL);
	if (swr_init(x->swr) < 0)
		return "SWResampler initialization failed";

	x->ratio = (double)x->a.ctx->sample_rate / sys_getsr();
	ffplay_speed(x ,x->speed);
	ffplay_reset_src(x);
	x->frm->pts = 0;
	return 0;
}

static void ffplay_open(t_ffplay *x ,t_symbol *s) {
	x->play = 0;
	int len = 0;
	char dir[MAXPDSTRING];
	const char *path = strrchr(s->s_name ,'/');
	if (path)
	{	len = path - s->s_name;
		strncpy(dir ,s->s_name ,len);
		path++;  }
	else
	{	len = 1;
		dir[0] = '.';
		path = s->s_name;  }
	dir[len] = '\0';
	x->plist.dir = gensym(dir);

	err_t err_msg = 0;
	char *ext = strrchr(s->s_name ,'.');
	if (ext && !strcmp(ext+1 ,"m3u"))
		err_msg = ffplay_m3u(x ,s);
	else
	{	x->plist.siz = 1;
		x->plist.trk[0] = gensym(path);  }

	if ( err_msg || (err_msg = ffplay_load(x ,1)) )
		post("Error: %s." ,err_msg);
	x->open = !err_msg;
	t_atom open = { .a_type=A_FLOAT ,.a_w={.w_float = x->open} };
	outlet_anything(x->o_meta ,s_open ,1 ,&open);
}

static void ffplay_interp(t_ffplay *x ,t_float f) {
	int d = f;
	if (d < SRC_SINC_BEST_QUALITY || d > SRC_LINEAR)
		return;

	int play = x->play;
	x->play = 0;
	int err;
	src_delete(x->state);
	if ((x->state = src_new(d ,x->nch ,&err)) == NULL)
	{	post("Error : src_new() failed : %s." ,src_strerror(err));
		x->open = 0;  }
	else x->play = play;
}

static inline t_atom ffplay_time(t_ffplay *x) {
	t_float f = x->ic->duration / 1000.; // AV_TIME_BASE is in microseconds
	return (t_atom){ .a_type=A_FLOAT ,.a_w={.w_float = f} };
}

static inline t_atom ffplay_ftime(t_ffplay *x) {
	char time[33] ,*t = time;
	int64_t ms  = x->ic->duration / 1000;
	int64_t min =  ms / 60000;
	int     sec = (ms - 60000 * min) / 1000;
	if (min >= 60)
	{	sprintf(t ,"%d:" ,(int)min/60);
		t += strlen(t);  }
	sprintf(t ,"%02d:%02d" ,(int)min%60 ,sec);
	return (t_atom){ .a_type=A_SYMBOL ,.a_w={.w_symbol = gensym(time)} };
}

static t_symbol *dict[9];

static t_atom ffplay_meta(t_ffplay *x ,t_symbol *s) {
	t_atom meta;
	if      (s == dict[0]
	      || s == dict[1]) SETSYMBOL(&meta ,gensym(x->ic->url));
	else if (s == dict[2])
	{	const char *name = strrchr(x->ic->url ,'/');
		name = name ? name+1 : x->ic->url;
		SETSYMBOL(&meta ,gensym(name));  }
	else if (s == dict[3]) meta = ffplay_time(x);
	else if (s == dict[4]) meta = ffplay_ftime(x);
	else if (s == dict[5]) SETFLOAT (&meta ,x->plist.siz);
	else if (s == dict[6]) SETSYMBOL(&meta
		,gensym(av_get_sample_fmt_name(x->a.ctx->sample_fmt)));
	else if (s == dict[7]) SETFLOAT (&meta ,x->a.ctx->sample_rate);
	else if (s == dict[8]) SETFLOAT (&meta ,x->ic->bit_rate / 1000.);
	else
	{	AVDictionaryEntry *entry = av_dict_get(x->ic->metadata ,s->s_name ,0 ,0);
		if (!entry && !strcmp(s->s_name ,"date") // try a few other 'date' aliases
			&& !(entry = av_dict_get(x->ic->metadata ,"time" ,0 ,0))
			&& !(entry = av_dict_get(x->ic->metadata ,"tyer" ,0 ,0))
			&& !(entry = av_dict_get(x->ic->metadata ,"tdat" ,0 ,0))
			&& !(entry = av_dict_get(x->ic->metadata ,"tdrc" ,0 ,0))
		);
		if (entry) SETSYMBOL(&meta ,gensym(entry->value));
		else meta = (t_atom){ A_NULL };  }

	return meta;
}

static void ffplay_info_custom(t_ffplay *x ,int ac ,t_atom *av) {
	for (; ac--; av++)
	if (av->a_type == A_SYMBOL)
	{	const char *sym = av->a_w.w_symbol->s_name ,*pct ,*end;
		while ( (pct = strchr(sym ,'%')) && (end = strchr(pct+1 ,'%')) )
		{	int len = pct - sym;
			if (len)
			{	char before[len + 1];
				strncpy(before ,sym ,len);
				before[len] = 0;
				startpost("%s" ,before);
				sym += len;  }
			pct++;
			len = end - pct;
			char buf[len + 1];
			strncpy(buf ,pct ,len);
			buf[len] = 0;
			t_atom meta = ffplay_meta(x ,gensym(buf));
			switch (meta.a_type)
			{	case A_FLOAT  : startpost("%g" ,meta.a_w.w_float);          break;
				case A_SYMBOL : startpost("%s" ,meta.a_w.w_symbol->s_name); break;
				default       : startpost("");  }
			sym += len + 2;  }
		startpost("%s%s" ,sym ,ac ? " " : "");  }
	else if (av->a_type == A_FLOAT)
		startpost("%g%s" ,av->a_w.w_float ,ac ? " " : "");
	endpost();
}

static void ffplay_info(t_ffplay *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (!x->open) return post("No file opened.");
	if (ac) return ffplay_info_custom(x ,ac ,av);

	AVDictionary *meta = x->ic->metadata;
	AVDictionaryEntry *artist = av_dict_get(meta ,"artist" ,0 ,0);
	AVDictionaryEntry *title  = av_dict_get(meta ,"title" ,0 ,0);
	if (artist || title)
		post("%s%s%s"
			,artist ? artist->value : ""
			," - "
			,title  ? title->value  : "");
}

static void ffplay_send(t_ffplay *x ,t_symbol *s) {
	if (!x->open) return post("No file opened.");
	t_atom meta = ffplay_meta(x ,s);
	if (meta.a_type)
		outlet_anything(x->o_meta ,s ,1 ,&meta);
	else post("no metadata for '%s'" ,s->s_name);
}

static void ffplay_anything(t_ffplay *x ,t_symbol *s ,int ac ,t_atom *av) {
	ffplay_send(x ,s);
}

static void ffplay_bang(t_ffplay *x) {
	if (!x->open) return post("No file opened.");
	x->play = !x->play;
	t_atom play = { .a_type=A_FLOAT ,.a_w={.w_float = x->play} };
	outlet_anything(x->o_meta ,s_play ,1 ,&play);
}

static void ffplay_float(t_ffplay *x ,t_float f) {
	x->play = 0;
	int track = f;
	err_t err_msg = "";
	if (track > 0 && track <= x->plist.siz)
	{	if ( (err_msg = ffplay_load(x ,track)) )
			post("Error: %s." ,err_msg);
		x->open = !err_msg;  }
	else ffplay_seek(x ,0);
	x->play = !err_msg;
	t_atom play = { .a_type=A_FLOAT ,.a_w={.w_float = x->play} };
	outlet_anything(x->o_meta ,s_play ,1 ,&play);
}

static void ffplay_stop(t_ffplay *x) {
	ffplay_float(x ,0);
	x->frm->pts = 0; // reset internal position
}

static void *ffplay_new(t_symbol *s ,int ac ,t_atom *av) {
	t_ffplay *x = (t_ffplay*)pd_new(ffplay_class);
	x->pkt = av_packet_alloc();
	x->frm = av_frame_alloc();
	x->frm->pts = 0;
	t_atom defarg[2];

	if (!ac)
	{	av = defarg;
		ac = 2;
		SETFLOAT(&defarg[0] ,1);
		SETFLOAT(&defarg[1] ,2);  }
	else if (ac > MAXCH)
		ac = MAXCH;
	x->nch = ac;
	x->in  = (t_sample*)getbytes(x->nch * FRAMES * sizeof(t_sample));
	x->out = (t_sample*)getbytes(x->nch * FRAMES * sizeof(t_sample));

	// channel layout masking details: libavutil/channel_layout.h
	x->layout = 0;
	for (int i=ac; i--;)
	{	outlet_new(&x->obj ,&s_signal);
		int ch = atom_getfloatarg(i ,ac ,av);
		if (ch > 0) x->layout |= 1 << (ch-1);  }
	x->o_meta = outlet_new(&x->obj ,0);

	int err;
	if ((x->state = src_new(SRC_LINEAR ,x->nch ,&err)) == NULL)
		post("Error : src_new() failed : %s." ,src_strerror(err));
	x->data.output_frames = FRAMES;

	x->plist.siz = 0;
	x->plist.max = 1;
	x->plist.trk = (t_symbol**)getbytes(sizeof(t_symbol*));

	x->speed = 1.;
	x->open = x->play = 0;
	return (x);
}

static void ffplay_free(t_ffplay *x) {
	avcodec_free_context(&x->a.ctx);
	avformat_close_input(&x->ic);
	av_packet_free(&x->pkt);
	av_frame_free(&x->frm);
	src_delete(x->state);
	swr_free(&x->swr);

	t_playlist *pl = &x->plist;
	freebytes(pl->trk ,pl->max * sizeof(t_symbol*));
	freebytes(x->in  ,x->nch * FRAMES * sizeof(t_sample));
	freebytes(x->out ,x->nch * FRAMES * sizeof(t_sample));
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

	s_open = gensym("open");
	s_play = gensym("play");
	s_done = gensym("done");
	s_pos  = gensym("pos");

	ffplay_class = class_new(gensym("ffplay~")
		,(t_newmethod)ffplay_new ,(t_method)ffplay_free
		,sizeof(t_ffplay) ,0
		,A_GIMME ,0);
	class_addbang     (ffplay_class ,ffplay_bang);
	class_addfloat    (ffplay_class ,ffplay_float);
	class_addanything (ffplay_class ,ffplay_anything);

	class_addmethod(ffplay_class ,(t_method)ffplay_dsp    ,gensym("dsp")    ,A_CANT   ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_seek   ,gensym("seek")   ,A_FLOAT  ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_speed  ,gensym("speed")  ,A_FLOAT  ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_interp ,gensym("interp") ,A_FLOAT  ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_info   ,gensym("info")   ,A_GIMME  ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_info   ,gensym("print")  ,A_GIMME  ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_send   ,gensym("send")   ,A_SYMBOL ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_open   ,gensym("open")   ,A_SYMBOL ,0);
	class_addmethod(ffplay_class ,(t_method)ffplay_bang   ,gensym("play")   ,A_NULL);
	class_addmethod(ffplay_class ,(t_method)ffplay_stop   ,gensym("stop")   ,A_NULL);
	class_addmethod(ffplay_class ,(t_method)ffplay_position ,gensym("pos")  ,A_NULL);
}
