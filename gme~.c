#include "m_pd.h"
#include "gme.h"

void handle_error( const char* str ) {
	if (str) post("Error: %s", str);
}

/* -------------------------- gme~ ------------------------------ */
static t_class *gme_tilde_class;

typedef struct _gme_tilde {
	t_object x_obj;
	Music_Emu *x_emu;
	gme_info_t *x_info;
	t_symbol *x_path;
	int x_flag, x_track, x_play, x_mask;
} t_gme_tilde;

static t_int *gme_tilde_perform(t_int *w) {
	t_gme_tilde *x = (t_gme_tilde *)(w[1]);
	t_sample *out1 = (t_sample *)(w[2]);
	t_sample *out2 = (t_sample *)(w[3]);
	int n = (int)(w[4]);
	
	if (x->x_track)
	{	if (x->x_emu)
		{	gme_delete(x->x_emu);
			x->x_emu = NULL;   }
		handle_error(gme_open_file(x->x_path->s_name, &x->x_emu, 44100));

		if (x->x_emu)
		{	gme_mute_voices(x->x_emu, x->x_mask);
			gme_ignore_silence( x->x_emu, 1);
			
			gme_free_info(x->x_info);
			x->x_info = NULL;
			handle_error(gme_track_info(x->x_emu, &x->x_info, 0));
			handle_error(gme_start_track(x->x_emu, 0));
			#ifdef _WIN32
				gme_set_fade(x->x_emu, -1);
			#endif
			x->x_play = 1;   }
		x->x_track = 0;   }

	while (n--)
	{	if (x->x_emu && x->x_play)
		{	/* Sample buffer */
			#define buf_size 2
			short buf [buf_size];

			/* Fill sample buffer */
			handle_error(gme_play(x->x_emu, buf_size, buf));
			*out1++ = ((t_sample) buf[0]) / (t_sample) 32768;
			*out2++ = ((t_sample) buf[1]) / (t_sample) 32768;   }
		else *out1++ = *out2++ = 0;   }
	return (w+5);
}

static void gme_tilde_dsp(t_gme_tilde *x, t_signal **sp) {
	dsp_add(gme_tilde_perform, 4, x, sp[0]->s_vec, sp[1]->s_vec, sp[0]->s_n);
}

static void gme_tilde_bang(t_gme_tilde *x) {
	if (x->x_flag) x->x_track = 1, x->x_flag = 0;
	else x->x_play = !x->x_play;
}

static void gme_tilde_float(t_gme_tilde *x, t_float f) {
	int t=f;
	if (x->x_emu && t >= 0 && t < gme_track_count(x->x_emu))
	{	handle_error(gme_start_track(x->x_emu, t));
		#ifdef _WIN32
			gme_set_fade(x->x_emu, -1);
		#endif
	}
}

static void gme_tilde_info(t_gme_tilde *x, t_symbol *s) {
	if (*s->s_name) startpost("%s: ", s->s_name);
	if (x->x_path)
	{	Music_Emu *emu;
		gme_info_t *info;
		handle_error(gme_open_file(x->x_path->s_name, &emu, gme_info_only));

		if (emu)
		{	handle_error(gme_track_info(emu, &info, 0));
			int c = gme_track_count(emu);
			startpost("%s", info->game);
			if (info->song[0] != '\0') startpost(" - %s", info->song);
			if (c>1) startpost(" | %d tracks", c);
			post(" (%s)", x->x_path->s_name);
			gme_free_info(info);
			gme_delete(emu);   }   }
	else post("no track loaded");
}

static void gme_tilde_mask(t_gme_tilde *x, t_symbol *s, int ac, t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
	{	x->x_mask = (int)av->a_w.w_float;
		if (x->x_emu) gme_mute_voices(x->x_emu, x->x_mask);   }
	else
	{	if (ac && av->a_type == A_SYMBOL)
			startpost("%s: ", av->a_w.w_symbol->s_name);
		int m = x->x_mask;
		startpost("muting-mask=%d%d%d%d%d%d%d%d", m&1, (m>>1)&1, (m>>2)&1,
			(m>>3)&1, (m>>4)&1, (m>>5)&1, (m>>6)&1, (m>>7)&1);
		endpost();   }
}

static void gme_tilde_read(t_gme_tilde *x, t_symbol *s) {
	if (*s->s_name) x->x_path = s, x->x_flag = 1;
}

static void gme_tilde_stop(t_gme_tilde *x) {
    x->x_play = 0, x->x_flag = 1;
}

static void gme_tilde_tempo(t_gme_tilde *x, t_floatarg f) {
	gme_set_tempo(x->x_emu, f);
}

static void gme_tilde_mute(t_gme_tilde *x, t_symbol *s, int ac, t_atom *av) {
	for (; ac--; av++)
		if (av->a_type == A_FLOAT)
			x->x_mask ^= 1 << (int)av->a_w.w_float;
	if (x->x_emu) gme_mute_voices(x->x_emu, x->x_mask);
}

static void gme_tilde_solo(t_gme_tilde *x, t_symbol *s, int ac, t_atom *av) {
	int mask = ~0;
	for (; ac--; av++)
		if (av->a_type == A_FLOAT)
			mask ^= 1 << (int)av->a_w.w_float;
	x->x_mask = (x->x_mask == mask) ? 0 : mask;
	if (x->x_emu) gme_mute_voices(x->x_emu, x->x_mask);
}

static void *gme_tilde_new(t_symbol *s, int ac, t_atom *av) {
	t_gme_tilde *x = (t_gme_tilde *)pd_new(gme_tilde_class);
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	if (ac) gme_tilde_solo(x, NULL, ac, av);
	return (x);
}

static void gme_tilde_free(t_gme_tilde *x) {
	gme_free_info(x->x_info);
	gme_delete(x->x_emu);
}

void gme_tilde_setup(void) {
	gme_tilde_class = class_new(gensym("gme~"),
		(t_newmethod)gme_tilde_new, (t_method)gme_tilde_free,
		sizeof(t_gme_tilde), 0,
		A_GIMME, 0);
	class_addbang(gme_tilde_class, gme_tilde_bang);
	class_addfloat(gme_tilde_class, gme_tilde_float);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_dsp,
		gensym("dsp"), A_CANT, 0);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_info,
		gensym("info"), A_DEFSYM, 0);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_mask,
		gensym("mask"), A_GIMME, 0);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_read,
		gensym("read"), A_DEFSYM, 0);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_stop,
		gensym("stop"), 0);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_tempo,
		gensym("tempo"), A_FLOAT, 0);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_mute,
		gensym("mute"), A_GIMME, 0);
	class_addmethod(gme_tilde_class, (t_method)gme_tilde_solo,
		gensym("solo"), A_GIMME, 0);
}
