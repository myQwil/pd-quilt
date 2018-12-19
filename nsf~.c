/*
Game_Music_Emu library copyright (C) 2003-2009 Shay Green.
Sega Genesis YM2612 emulator copyright (C) 2002 Stephane Dallongeville.
MAME YM2612 emulator copyright (C) 2003 Jarek Burczynski, Tatsuyuki Satoh
Nuked OPN2 emulator copyright (C) 2017 Alexey Khokholov (Nuke.YKT)

--
Shay Green <gblargg@gmail.com>
*/

#include "m_pd.h"
#include "gme.h"
#include <string.h>

static void handle_error( const char* str ) {
	if (str) post("Error: %s", str);
}

/* -------------------------- nsf~ ------------------------------ */
static t_class *nsf_tilde_class;

typedef struct _nsf_tilde {
	t_object x_obj;
	Music_Emu *x_emu;
	t_symbol *x_path;
	int x_read, x_open, x_stop;	// flags
	int x_play, x_track;		// play/pause, track
	t_float x_tempo;
} t_nsf_tilde;

static void nsf_tilde_m3u(t_nsf_tilde *x, Music_Emu *emu) {
	char m3u_path [256 + 5];
	strncpy(m3u_path, x->x_path->s_name, 256);
	m3u_path [256] = 0;
	char* p = strrchr(m3u_path, '.');
	if (!p) p = m3u_path + strlen(m3u_path);
	strcpy(p, ".m3u");
	if (gme_load_m3u(emu, m3u_path)) { } // ignore error
}

static void nsf_tilde_track(t_nsf_tilde *x) {
	handle_error(gme_start_track(x->x_emu, x->x_track));
	#ifdef _WIN32
		gme_set_fade(x->x_emu, -1);
	#endif
	x->x_stop = 0, x->x_play = 1;
}

static t_int *nsf_tilde_perform(t_int *w) {
	t_nsf_tilde *x = (t_nsf_tilde *)(w[1]);
	t_sample *out1 = (t_sample *)(w[2]);
	t_sample *out2 = (t_sample *)(w[3]);
	t_sample *out3 = (t_sample *)(w[4]);
	t_sample *out4 = (t_sample *)(w[5]);
	t_sample *out5 = (t_sample *)(w[6]);
	int n = (int)(w[7]);
	
	if (x->x_open)
	{	if (!gme_load_file(x->x_emu, x->x_path->s_name)) // no error
		{	nsf_tilde_m3u(x, x->x_emu);
			if (x->x_track < 0 || x->x_track >= gme_track_count(x->x_emu))
				x->x_track = 0;
			nsf_tilde_track(x);   }
		x->x_open = 0;   }

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

static void nsf_tilde_read(t_nsf_tilde *x, t_symbol *s) {
	if (*s->s_name) x->x_path = s, x->x_track = 0, x->x_read = 1;
}

static void nsf_tilde_bang(t_nsf_tilde *x) {
	if (x->x_read) x->x_open = 1, x->x_read = 0;
	else if (x->x_stop && x->x_emu) nsf_tilde_track(x);
	else x->x_play = !x->x_play;
}

static void nsf_tilde_float(t_nsf_tilde *x, t_float f) {
	int t = f;
	if (x->x_read) x->x_open = 1, x->x_track = t, x->x_read = 0;
	else if (x->x_emu && t >= 0 && t < gme_track_count(x->x_emu))
	{	x->x_track = t; nsf_tilde_track(x);   }
}

static void nsf_tilde_stop(t_nsf_tilde *x) {
    x->x_play = 0, x->x_stop = 1;
}

static void nsf_tilde_prinfo(Music_Emu *emu, int track) {
	gme_info_t *info;
	handle_error(gme_track_info(emu, &info, track));
	if (info)
	{	startpost("%s[%d/%d]", info->game, track, gme_track_count(emu)-1);
		if (info->song[0] != '\0') startpost(" %s", info->song);
		endpost();
		gme_free_info(info);   }
}

static void nsf_tilde_info(t_nsf_tilde *x, t_symbol *s) {
	if (*s->s_name) startpost("%s: ", s->s_name);
	if (x->x_emu && !x->x_read) nsf_tilde_prinfo(x->x_emu, x->x_track);
	else if (x->x_path)
	{	Music_Emu *emu;
		handle_error(gme_open_file(x->x_path->s_name, &emu, gme_info_only));
		if (emu)
		{	nsf_tilde_m3u(x, emu);
			nsf_tilde_prinfo(emu, x->x_track);
			gme_delete(emu);   }   }
	else post("no track loaded");
}

static void nsf_tilde_path(t_nsf_tilde *x, t_symbol *s) {
	if (*s->s_name) startpost("%s: ", s->s_name);
	if (x->x_path) post("%s", x->x_path->s_name);
	else post("no track loaded");
}

static void nsf_tilde_tempo(t_nsf_tilde *x, t_floatarg f) {
	if (x->x_emu) gme_set_tempo(x->x_emu, (x->x_tempo=f));
}

static void *nsf_tilde_new(void) {
	t_nsf_tilde *x = (t_nsf_tilde *)pd_new(nsf_tilde_class);
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	outlet_new(&x->x_obj, gensym("signal"));
	x->x_emu = gme_new_emu_multi_channel(gme_nsf_type, sys_getsr());
	gme_ignore_silence(x->x_emu, 1);
	x->x_tempo = 1;
	return (x);
}

static void nsf_tilde_free(t_nsf_tilde *x) {
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
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_path,
		gensym("path"), A_DEFSYM, 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_read,
		gensym("read"), A_DEFSYM, 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_tempo,
		gensym("tempo"), A_FLOAT, 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_stop,
		gensym("stop"), 0);
	class_addmethod(nsf_tilde_class, (t_method)nsf_tilde_bang,
		gensym("play"), 0);
}
