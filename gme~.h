/*
Game_Music_Emu library copyright (C) 2003-2009 Shay Green.
Sega Genesis YM2612 emulator copyright (C) 2002 Stephane Dallongeville.
MAME YM2612 emulator copyright (C) 2003 Jarek Burczynski, Tatsuyuki Satoh
Nuked OPN2 emulator copyright (C) 2017 Alexey Khokholov (Nuke.YKT)

--
Shay Green <gblargg@gmail.com>
*/

#include "m_pd.h"
#include "game-music-emu/gme/gme.h"
#include <string.h>

#ifndef NCH
#define NCH 2
#endif
#ifndef MULTI
#define MULTI 0
#endif

#if defined MSW                   // when compiling for Windows
#define EXPORT __declspec(dllexport)
#elif __GNUC__ >= 4               // else, when compiling with GCC 4.0 or higher
#define EXPORT __attribute__((visibility("default")))
#endif
#ifndef EXPORT
#define EXPORT                    // empty definition for other cases
#endif

static void hnd_err( const char *str ) {
	if (str) post("Error: %s", str);
}

typedef struct _gme_tilde {
	t_object x_obj;
	Music_Emu *x_emu;   /* emulator object */
	Music_Emu *x_info;  /* info-only emu fallback */
	const char *x_path; /* path to the most recently read file */
	int x_track;        /* current track number */
	t_float x_tempo;    /* current tempo */
	unsigned x_read:1;  /* when a new file path is read but not opened yet */
	unsigned x_open:1;  /* when a request for playback is made */
	unsigned x_stop:1;  /* flag to start from beginning on next playback */
	unsigned x_play:1;  /* play/pause flag */
	unsigned x_mask:8;  /* muting mask */
	t_outlet *o_len;    /* outputs track length and fade */
} t_gme_tilde;

static void gme_tilde_m3u(t_gme_tilde *x, Music_Emu *emu) {
	char m3u_path [256 + 5];
	strncpy(m3u_path, x->x_path, 256);
	m3u_path [256] = 0;
	char *p = strrchr(m3u_path, '.');
	if (!p) p = m3u_path + strlen(m3u_path);
	strcpy(p, ".m3u");
	if (gme_load_m3u(emu, m3u_path)) { } // ignore error
}

static Music_Emu *gme_tilde_emu(t_gme_tilde *x) {
	if (x->x_read && x->x_info) return x->x_info;
	else if (x->x_emu) return x->x_emu;
	else return NULL;
}

static void gme_tilde_time(t_gme_tilde *x, t_symbol *s, int ac, t_atom *av) {
	int track = (ac && av->a_type == A_FLOAT) ? av->a_w.w_float : x->x_track;
	gme_info_t *info;
	Music_Emu *emu = gme_tilde_emu(x);
	hnd_err(gme_track_info(emu, &info, track-1));
	if (info)
	{	t_atom flts[] =
		{	{A_FLOAT, {(t_float)info->length}},
			{A_FLOAT, {(t_float)info->fade_length}}   };
		outlet_list(x->o_len, 0, 2, flts);   }
	gme_free_info(info);
}

static void gme_tilde_start(t_gme_tilde *x) {
	hnd_err(gme_start_track(x->x_emu, x->x_track-1));
	gme_set_fade(x->x_emu, -1, 0);
	gme_tilde_time(x,0,0,0);
	x->x_stop = 0, x->x_play = 1;
}

static t_int *gme_tilde_perform(t_int *w) {
	t_gme_tilde *x = (t_gme_tilde *)(w[1]);
	t_sample *outs[NCH];
	for (int i=NCH; i--;) outs[i] = (t_sample *)(w[i+2]);
	int n = (int)(w[NCH+2]);

	if (x->x_open)
	{	gme_delete(x->x_emu); x->x_emu = NULL;
		hnd_err(gme_open_file(x->x_path, &x->x_emu, sys_getsr(), MULTI));
		if (x->x_emu)
		{	gme_tilde_m3u(x, x->x_emu);
			gme_ignore_silence(x->x_emu, 1);
			gme_mute_voices(x->x_emu, x->x_mask);
			gme_set_tempo(x->x_emu, x->x_tempo);
			if (x->x_track < 1 || x->x_track > gme_track_count(x->x_emu))
				x->x_track = 1;
			gme_tilde_start(x);   }
		x->x_open = x->x_read = 0;   }

	if (x->x_emu && x->x_play)
	{	short buf[NCH];
		while (n--)
		{	hnd_err(gme_play(x->x_emu, NCH, buf));
			for (int i=NCH; i--;)
				*outs[i]++ = ((t_sample) buf[i]) / (t_sample) 32768;   }   }
	else while (n--) for (int i=NCH; i--;) *outs[i]++ = 0;
	return (w+NCH+3);
}

static void gme_tilde_read(t_gme_tilde *x, t_symbol *s) {
	if (*s->s_name) x->x_path = s->s_name, x->x_track = x->x_read = 1;

	gme_delete(x->x_info); x->x_info = NULL;
	hnd_err(gme_open_file(x->x_path, &x->x_info, gme_info_only, 0));
	if (x->x_info) gme_tilde_m3u(x, x->x_info);
}

static void gme_tilde_bang(t_gme_tilde *x) {
	if (x->x_read) x->x_open = 1;
	else if (x->x_stop && x->x_emu) gme_tilde_start(x);
	else x->x_play = !x->x_play;
}

static void gme_tilde_stop(t_gme_tilde *x) {
	x->x_play = 0, x->x_stop = 1;
}

static void gme_tilde_float(t_gme_tilde *x, t_float f) {
	if (!f)
	{	gme_tilde_stop(x);
		return;   }
	else if (x->x_read) x->x_open = 1;

	Music_Emu *emu = gme_tilde_emu(x);
	if (emu && f >= 1 && f <= gme_track_count(emu))
	{	x->x_track = f;
		if (x->x_emu) gme_tilde_start(x);   }
}

static void gme_tilde_track(t_gme_tilde *x, t_floatarg f) {
	Music_Emu *emu = gme_tilde_emu(x);
	if (emu && f >= 0 && f < gme_track_count(emu))
		x->x_track = f;
}

static void gme_tilde_prinfo(Music_Emu *emu, int track) {
	gme_info_t *info;
	hnd_err(gme_track_info(emu, &info, track-1));
	if (info)
	{	startpost("%s", info->game);
		int c = gme_track_count(emu);
		int plist = c > 1;
		if (plist) startpost(" (%d/%d)", track, c);
		if (*info->song) startpost("%s%s", (plist) ? " " : " - ", info->song);
		endpost();
		gme_free_info(info);   }
}

static void gme_tilde_info(t_gme_tilde *x, t_symbol *s) {
	if (*s->s_name) startpost("%s: ", s->s_name);

	Music_Emu *emu = gme_tilde_emu(x);
	if (emu) gme_tilde_prinfo(emu, x->x_track);
	else post("no track loaded");
}

static void gme_tilde_path(t_gme_tilde *x, t_symbol *s) {
	if (*s->s_name) startpost("%s: ", s->s_name);
	if (x->x_path) post("%s", x->x_path);
	else post("no track loaded");
}

static void gme_tilde_goto(t_gme_tilde *x, t_floatarg f) {
	if (x->x_emu)
	{	gme_seek(x->x_emu, f);
		gme_set_fade(x->x_emu, -1, 0);   }
}

static void gme_tilde_tempo(t_gme_tilde *x, t_floatarg f) {
	x->x_tempo = f;
	if (x->x_emu) gme_set_tempo(x->x_emu, x->x_tempo);
}

static void gme_tilde_mute(t_gme_tilde *x, t_symbol *s, int ac, t_atom *av) {
	for (;ac--; av++)
		if (av->a_type == A_FLOAT)
			x->x_mask ^= 1 << (int)av->a_w.w_float;
	if (x->x_emu) gme_mute_voices(x->x_emu, x->x_mask);
}

static void gme_tilde_solo(t_gme_tilde *x, t_symbol *s, int ac, t_atom *av) {
	int mask = ~0;
	for (;ac--; av++)
		if (av->a_type == A_FLOAT)
			mask ^= 1 << (int)av->a_w.w_float;
	x->x_mask = (x->x_mask == mask) ? 0 : mask;
	if (x->x_emu) gme_mute_voices(x->x_emu, x->x_mask);
}

static void gme_tilde_mask(t_gme_tilde *x, t_symbol *s, int ac, t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
	{	x->x_mask = av->a_w.w_float;
		if (x->x_emu) gme_mute_voices(x->x_emu, x->x_mask);   }
	else
	{	if (ac && av->a_type == A_SYMBOL)
			startpost("%s: ", av->a_w.w_symbol->s_name);
		int m = x->x_mask;
		post("muting-mask = %d%d%d%d%d%d%d%d", m&1, (m>>1)&1, (m>>2)&1,
			(m>>3)&1, (m>>4)&1, (m>>5)&1, (m>>6)&1, (m>>7)&1);   }
}

static void *gme_new(t_class *gmeclass, t_symbol *s, int ac, t_atom *av) {
	t_gme_tilde *x = (t_gme_tilde *)pd_new(gmeclass);
	int i = NCH;
	while (i--) outlet_new(&x->x_obj, &s_signal);
	x->o_len = outlet_new(&x->x_obj, &s_list);
	if (ac) gme_tilde_solo(x, NULL, ac, av);
	x->x_tempo = 1;
	return (x);
}

static void gme_tilde_free(t_gme_tilde *x) {
	gme_delete(x->x_emu); x->x_emu = NULL;
	gme_delete(x->x_info); x->x_info = NULL;
}
