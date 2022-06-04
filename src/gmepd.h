#include "player.h"
#include <gme.h>

static const float short_frac = 1.f / 0x8000;
static t_symbol *s_mask;

/* ------------------------- Game Music Emu player ------------------------- */
typedef struct {
	t_player z;
	Music_Emu  *emu;
	gme_info_t *info;   /* current track info */
	t_symbol   *path;   /* path to the most recently read file */
	t_float    *tempo;  /* rate of emulation (inlet pointer) */
	t_float     tempo_; /* rate of emulation (prev value) */
	int      voices;    /* number of voices */
	int      mask;      /* muting mask */
} t_gme;

static void gmepd_seek(t_gme *x ,t_float f) {
	if (!x->z.open) return; // quietly
	gme_seek(x->emu ,f);
	gme_set_fade(x->emu ,-1 ,0);
	player_reset(&x->z);
}

static inline void gmepd_tempo_(t_gme *x ,t_float f) {
	x->tempo_ = f;
	if (x->emu) gme_set_tempo(x->emu ,x->tempo_);
}

static void gmepd_tempo(t_gme *x ,t_float f) {
	*x->tempo = f;
}

static t_int *gmepd_perform(t_int *w) {
	t_gme *y = (t_gme*)(w[1]);
	int n = (int)(w[4]);

	t_player *x = &y->z;
	unsigned nch = x->nch;
	t_sample *outs[nch];
	for (int i = nch; i--;)
		outs[i] = x->outs[i];

	if (x->play)
	{	t_sample *in2 = (t_sample*)(w[2]);
		t_sample *in3 = (t_sample*)(w[3]);
		int buf_size = nch * FRAMES;
		SRC_DATA *data = &x->data;
		for (; n--; in2++ ,in3++)
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
				if (x->speed_ != *in2)
					player_speed_(x ,*in2);
				data->data_out = x->out;
				src_process(x->state ,data);
				data->input_frames -= data->input_frames_used;
				data->data_in += data->input_frames_used * nch;
				goto perform;
			}
			else
			{	// receive
				if (y->tempo_ != *in3)
					gmepd_tempo_(y ,*in3);
				data->data_in = x->in;
				float *in = x->in;
				short arr[buf_size] ,*buf = arr;
				gme_play(y->emu ,buf_size ,buf);
				for (int i = buf_size; i--; in++ ,buf++)
					*in = *buf * short_frac;
				data->input_frames = FRAMES;
				goto resample;
			}
		}
	}
	else while (n--)
		for (int i = nch; i--;)
			*outs[i]++ = 0;
	return (w + 5);
}

static void gmepd_dsp(t_gme *y ,t_signal **sp) {
	t_player *x = &y->z;
	for (int i = x->nch; i--;)
		x->outs[i] = sp[i+2]->s_vec;
	dsp_add(gmepd_perform ,4 ,y ,sp[0]->s_vec ,sp[1]->s_vec ,sp[0]->s_n);
}

static inline int domask(int mask ,int voices ,int ac ,t_atom *av) {
	for (; ac--; av++) if (av->a_type == A_FLOAT)
	{	int d = av->a_w.w_float;
		if (!d)
		{	mask = 0;
			continue;  }
		if (d > 0) d--;
		d %= voices;
		if (d < 0) d += voices;
		mask ^= 1 << d;  }
	return mask;
}

static void gmepd_mute(t_gme *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	x->mask = domask(x->mask ,x->voices ,ac ,av);
	if (x->emu) gme_mute_voices(x->emu ,x->mask);
}

static void gmepd_solo(t_gme *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	int mask = domask(~0 ,x->voices ,ac ,av);
	mask &= (1 << x->voices) - 1;
	x->mask = (x->mask == mask ? 0 : mask);
	if (x->emu) gme_mute_voices(x->emu ,x->mask);
}

static void gmepd_mask(t_gme *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	if (ac && av->a_type == A_FLOAT)
	{	x->mask = av->a_w.w_float;
		if (x->emu) gme_mute_voices(x->emu ,x->mask);  }
	else
	{	t_atom flt = { .a_type=A_FLOAT ,.a_w={.w_float = x->mask} };
		outlet_anything(x->z.o_meta ,s_mask ,1 ,&flt);  }
}

static gme_err_t gmepd_load(t_gme *x ,int index) {
	if (!x->z.state)
		return "SRC has not been initialized";

	gme_err_t err_msg;
	if ( (err_msg = gme_start_track(x->emu ,index)) )
		return err_msg;

	gme_free_info(x->info);
	if ( (err_msg = gme_track_info(x->emu ,&x->info ,index)) )
		return err_msg;

	gme_set_fade(x->emu ,-1 ,0);
	player_reset(&x->z);
	return 0;
}

static void gmepd_open(t_gme *x ,t_symbol *s) {
	x->z.play = 0;
	gme_err_t err_msg;
	gme_delete(x->emu); x->emu = NULL;
	if ( !(err_msg = gme_open_file(s->s_name ,&x->emu ,sys_getsr() ,x->z.nch > 2)) )
	{	// check for a .m3u file of the same name
		char m3u_path [256 + 5];
		strncpy(m3u_path ,s->s_name ,256);
		m3u_path [256] = 0;
		char *p = strrchr(m3u_path ,'.');
		if (!p) p = m3u_path + strlen(m3u_path);
		strcpy(p ,".m3u");
		gme_load_m3u(x->emu ,m3u_path);

		gme_ignore_silence ( x->emu ,1         );
		gme_mute_voices    ( x->emu ,x->mask   );
		gme_set_tempo      ( x->emu ,*x->tempo );
		x->voices = gme_voice_count(x->emu);
		err_msg = gmepd_load(x ,0);
		x->path = s;  }
	if (err_msg)
		post("Error: %s" ,err_msg);
	x->z.open = !err_msg;
	t_atom open = { .a_type=A_FLOAT ,.a_w={.w_float = x->z.open} };
	outlet_anything(x->z.o_meta ,s_open ,1 ,&open);
}

static inline t_float gmepd_length(t_gme *x) {
	t_float f = x->info->length;
	if (f < 0) // try intro + 2 loops
	{	int intro = x->info->intro_length ,loop = x->info->loop_length;
		if (intro < 0 && loop < 0)
			return f;
		f = (intro >= 0 ? intro : 0) + (loop >= 0 ? loop * 2 : 0);  }
	return f;
}

static inline t_atom gmepd_ftime(t_gme *x) {
	int ms = gmepd_length(x);
	if (ms < 0) ms = 0;
	if (x->info->fade_length > 0)
		ms += x->info->fade_length;
	return player_ftime(ms);
}

static const t_symbol *dict[15];

static t_atom gmepd_meta(void *y ,t_symbol *s) {
	t_gme *x = (t_gme*)y;
	t_atom meta;
	if      (s == dict[0])  SETSYMBOL(&meta ,x->path);
	else if (s == dict[1])  meta = player_time(gmepd_length(x));
	else if (s == dict[2])  meta = gmepd_ftime(x);
	else if (s == dict[3])  SETFLOAT (&meta ,x->info->fade_length);
	else if (s == dict[4])  SETFLOAT (&meta ,gme_track_count(x->emu));
	else if (s == dict[5])  SETFLOAT (&meta ,x->mask);
	else if (s == dict[6])  SETFLOAT (&meta ,x->voices);
	else if (s == dict[7])
	{	char buf[33] ,*b = buf;
		int m = x->mask;
		int v = x->voices;
		for (int i = 0; i < v; i++ ,b++)
			*b = ((m >> i) & 1) + '0';
		*b = '\0';
		SETSYMBOL(&meta ,gensym(buf));  }

	else if (s == dict[8])  SETSYMBOL(&meta ,gensym(x->info->system));
	else if (s == dict[9])  SETSYMBOL(&meta ,gensym(x->info->game));
	else if (s == dict[10]) SETSYMBOL(&meta ,gensym(x->info->song));
	else if (s == dict[11]) SETSYMBOL(&meta ,gensym(x->info->author));
	else if (s == dict[12]) SETSYMBOL(&meta ,gensym(x->info->copyright));
	else if (s == dict[13]) SETSYMBOL(&meta ,gensym(x->info->comment));
	else if (s == dict[14]) SETSYMBOL(&meta ,gensym(x->info->dumper));
	else meta = (t_atom){ A_NULL,{0} };
	return meta;
}

static void gmepd_info(t_gme *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	if (!x->z.open) return post("No file opened.");
	if (ac) return player_info_custom(&x->z ,ac ,av);

	if (x->info->game || x->info->song)
		post("%s%s%s"
			,*x->info->game ? x->info->game : ""
			," - "
			,*x->info->song ? x->info->song : "");
}

static void gmepd_float(t_gme *x ,t_float f) {
	if (!x->emu) return post("No file opened.");
	int track = f;
	gme_err_t err_msg = "";
	if (track > 0 && track <= gme_track_count(x->emu))
	{	if ( (err_msg = gmepd_load(x ,track-1)) )
			post("Error: %s" ,err_msg);
		x->z.open = !err_msg;  }
	else gmepd_seek(x ,0);
	x->z.play = !err_msg;
	t_atom play = { .a_type=A_FLOAT ,.a_w={.w_float = x->z.play} };
	outlet_anything(x->z.o_meta ,s_play ,1 ,&play);
}

static void gmepd_stop(t_gme *x) {
	gmepd_float(x ,0);
}

static void *gmepd_new(t_class *gmeclass ,int nch ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	t_gme *x = (t_gme*)player_new(gmeclass ,nch);

	x->tempo_ = 1.;
	t_inlet *in3 = signalinlet_new(&x->z.obj ,x->tempo_);
	x->tempo = &in3->i_un.iu_floatsignalvalue;

	x->mask = 0;
	x->voices = 32;
	x->path = gensym("no track loaded");
	if (ac) gmepd_solo(x ,NULL ,ac ,av);
	return x;
}

static void gmepd_free(t_gme *x) {
	gme_free_info(x->info);
	gme_delete(x->emu);
	player_free(&x->z);
}

static t_class *gmepd_setup(t_symbol *s ,t_newmethod newm) {
	dict[0] = gensym("path");
	dict[1] = gensym("time");
	dict[2] = gensym("ftime");
	dict[3] = gensym("fade");
	dict[4] = gensym("tracks");
	dict[5] = gensym("mask");
	dict[6] = gensym("voices");
	dict[7] = gensym("bmask");
	dict[8] = gensym("system");
	dict[9] = gensym("game");
	dict[10] = gensym("song");
	dict[11] = gensym("author");
	dict[12] = gensym("copyright");
	dict[13] = gensym("comment");
	dict[14] = gensym("dumper");

	s_mask  = gensym("mask");
	fn_meta = gmepd_meta;

	t_class *cls = class_player(s ,newm ,(t_method)gmepd_free ,sizeof(t_gme));
	class_addfloat(cls ,gmepd_float);

	class_addmethod(cls ,(t_method)gmepd_seek  ,gensym("seek")  ,A_FLOAT  ,0);
	class_addmethod(cls ,(t_method)gmepd_tempo ,gensym("tempo") ,A_FLOAT  ,0);
	class_addmethod(cls ,(t_method)gmepd_mute  ,gensym("mute")  ,A_GIMME  ,0);
	class_addmethod(cls ,(t_method)gmepd_solo  ,gensym("solo")  ,A_GIMME  ,0);
	class_addmethod(cls ,(t_method)gmepd_mask  ,gensym("mask")  ,A_GIMME  ,0);
	class_addmethod(cls ,(t_method)gmepd_info  ,gensym("info")  ,A_GIMME  ,0);
	class_addmethod(cls ,(t_method)gmepd_info  ,gensym("print") ,A_GIMME  ,0);
	class_addmethod(cls ,(t_method)gmepd_open  ,gensym("open")  ,A_SYMBOL ,0);
	class_addmethod(cls ,(t_method)gmepd_stop  ,gensym("stop")  ,A_NULL);

	return cls;
}
