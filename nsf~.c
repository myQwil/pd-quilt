#include "m_pd.h"
#include "gme.h"

void handle_error( const char* str ) {
	if (str) post("Error: %s", str);
}

/* -------------------------- nsf~ ------------------------------ */
static t_class *nsf_tilde_class;

typedef struct _nsf_tilde {
	t_object x_obj;
	Music_Emu *x_emu;
	gme_info_t *x_info;
	t_symbol *x_path;
	int x_flag, x_track, x_play;
} t_nsf_tilde;

static t_int *nsf_tilde_perform(t_int *w) {
	t_nsf_tilde *x = (t_nsf_tilde *)(w[1]);
	t_sample *out1 = (t_sample *)(w[2]);
	t_sample *out2 = (t_sample *)(w[3]);
	t_sample *out3 = (t_sample *)(w[4]);
	t_sample *out4 = (t_sample *)(w[5]);
	t_sample *out5 = (t_sample *)(w[6]);
	int n = (int)(w[7]);
	
	if (x->x_track)
	{	handle_error(gme_load_file(x->x_emu, x->x_path->s_name));
		if (x->x_emu)
		{	gme_ignore_silence( x->x_emu, 1);
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
			#define buf_size 16
			short buf [buf_size];

			/* Fill sample buffer */
			handle_error(gme_play(x->x_emu, buf_size, buf));
			*out1++ = ((t_sample) buf[0]) / (t_sample) 32768;
			*out2++ = ((t_sample) buf[2]) / (t_sample) 32768;
			*out3++ = ((t_sample) buf[4]) / (t_sample) 32768;
			*out4++ = ((t_sample) buf[6]) / (t_sample) 32768;
			*out5++ = ((t_sample) buf[8]) / (t_sample) 32768;   }
		else *out1++ = *out2++ = *out3++ = *out4++ = *out5++ = 0;   }
	return (w+8);
}

static void nsf_tilde_dsp(t_nsf_tilde *x, t_signal **sp) {
	dsp_add(nsf_tilde_perform, 7, x, sp[0]->s_vec, sp[1]->s_vec,
		sp[2]->s_vec, sp[3]->s_vec, sp[4]->s_vec, sp[0]->s_n);
}

static void nsf_tilde_bang(t_nsf_tilde *x) {
	if (x->x_flag) x->x_track = 1, x->x_flag = 0;
	else x->x_play = !x->x_play;
}

static void nsf_tilde_float(t_nsf_tilde *x, t_float f) {
	int t=f;
	if (x->x_emu && t >= 0 && t < gme_track_count(x->x_emu))
	{	handle_error(gme_start_track(x->x_emu, t));
		#ifdef _WIN32
			gme_set_fade(x->x_emu, -1);
		#endif
	}
}

static void nsf_tilde_info(t_nsf_tilde *x, t_symbol *s) {
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

static void nsf_tilde_read(t_nsf_tilde *x, t_symbol *s) {
	x->x_path = s, x->x_flag = 1;
}

static void nsf_tilde_stop(t_nsf_tilde *x) {
    x->x_play = 0, x->x_flag = 1;
}

static void nsf_tilde_tempo(t_nsf_tilde *x, t_floatarg f) {
	gme_set_tempo(x->x_emu, f);
}

static void *nsf_tilde_new(void) {
	t_nsf_tilde *x = (t_nsf_tilde *)pd_new(nsf_tilde_class);
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	x->x_emu = gme_new_emu_multi_channel(gme_nsf_type, 44100);
	return (x);
}

static void nsf_tilde_free(t_nsf_tilde *x) {
	gme_free_info(x->x_info);
	gme_delete(x->x_emu);
}

void nsf_tilde_setup(void) {
	nsf_tilde_class = class_new(gensym("nsf~"),
		(t_newmethod)nsf_tilde_new, (t_method)nsf_tilde_free,
		sizeof(t_nsf_tilde), 0,
		A_DEFFLOAT, 0);
	class_addbang(nsf_tilde_class, nsf_tilde_bang);
	class_addfloat(nsf_tilde_class, nsf_tilde_float);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_dsp,
		gensym("dsp"), A_CANT, 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_info,
		gensym("info"), A_DEFSYM, 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_read,
		gensym("read"), A_DEFSYM, 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_stop,
		gensym("stop"), 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_tempo,
		gensym("tempo"), A_FLOAT, 0);
}
