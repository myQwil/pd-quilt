#include "player.h"
#include <rubberband/rubberband-c.h>
#include <gme.h>

#define FRAMES 0x10

static const t_float fastest = 1.0 * FRAMES;
static const t_float slowest = 1.0 / FRAMES;

static t_symbol *s_mask;

/* -------------------------- gmer~ ------------------------------ */
static t_class *gmer_tilde_class;

typedef struct _gme {
	t_player p;
	t_sample **buf;
	t_float *tempo;
	t_float *pitch;
	RubberBandState state;
	Music_Emu *emu;
	gme_info_t *info; /* current track info */
	t_symbol *path;   /* path to the most recently read file */
	int voices;       /* number of voices */
	int mask;         /* muting mask */
} t_gme;

static void gmepd_seek(t_gme *x, t_float f) {
	if (!x->p.open) {
		return;
	}
	gme_seek(x->emu, f);
	gme_set_fade(x->emu, -1, 0);
	rubberband_reset(x->state);
}

static void gmepd_tempo(t_gme *x, t_float f) {
	*x->tempo = f;
}

static void gmepd_pitch(t_gme *x, t_float f) {
	*x->pitch = f;
}

static t_int *gmepd_perform(t_int *w) {
	t_gme *x = (t_gme *)(w[1]);
	t_player *p = &x->p;
	unsigned nch = p->nch;
	t_sample *outs[nch];
	for (int i = nch; i--;) {
		outs[i] = p->outs[i];
	}

	int n = (int)(w[2]);
	if (p->play) {
		t_sample *in2 = (t_sample *)(w[3]);
		t_sample *in3 = (t_sample *)(w[4]);
		RubberBandState state = x->state;
		t_sample **buf = x->buf;
		Music_Emu *emu = x->emu;
		int buf_size = nch * FRAMES;
		short arr[buf_size];

		int m = rubberband_available(state);
		if (m > 0) {
			perform:
			m = rubberband_retrieve(state, outs, m < n ? m : n);
			if (m >= n) {
				return (w + 5);
			}
			n -= m, in2 += m, in3 += m;
			for (int i = nch; i--;) {
				outs[i] += m;
			}
		}
		rubberband_set_time_ratio(state, 1.0 /
			(*in2 > fastest ? fastest : (*in2 < slowest ? slowest : *in2)) );
		rubberband_set_pitch_scale(state,
			(*in3 > fastest ? fastest : (*in3 < slowest ? slowest : *in3)) );

		process:
		short *a = arr;
		gme_play(emu, buf_size, a);
		for (unsigned i = 0; i < FRAMES; i++) {
			for (unsigned j = 0; j < nch; j++, a++) {
				buf[j][i] = *a * 0x1p-15;
			}
		}

		rubberband_process(state, (const float *const *)buf, FRAMES, 0);
		if ((m = rubberband_available(state)) > 0) {
			goto perform;
		}
		goto process;
	} else while (n--) {
		for (int i = nch; i--;) {
			*outs[i]++ = 0;
		}
	}
	return (w + 5);
}

static void gmepd_dsp(t_gme *x, t_signal **sp) {
	t_player *p = &x->p;
	for (int i = p->nch; i--;) {
		p->outs[i] = sp[i + 2]->s_vec;
	}
	dsp_add(gmepd_perform, 4, x, sp[0]->s_n, sp[0]->s_vec, sp[1]->s_vec);
}

static void gmepd_mute(t_gme *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	for (; ac--; av++) {
		switch (av->a_type) {
		case A_FLOAT: {
			int d = av->a_w.w_float;
			if (d == 0) {
				x->mask = 0; // unmute all channels
				continue;
			}
			d = (d - (d > 0)) % x->voices;
			if (d < 0) {
				d += x->voices;
			}
			x->mask ^= 1 << d; // toggle the bit at d position
			break;
		}
		default:
			x->mask = ~0; // mute all channels
		}
	}
	if (x->emu) {
		gme_mute_voices(x->emu, x->mask);
	}
}

static void gmepd_mask(t_gme *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (ac && av->a_type == A_FLOAT) {
		x->mask = av->a_w.w_float;
		if (x->emu) {
			gme_mute_voices(x->emu, x->mask);
		}
	} else {
		t_atom flt = { .a_type = A_FLOAT, .a_w = {.w_float = x->mask} };
		outlet_anything(x->p.o_meta, s_mask, 1, &flt);
	}
}

static void gmepd_bmask(t_gme *x) {
	char buf[33], *b = buf;
	int m = x->mask;
	int v = x->voices;
	for (int i = 0; i < v; i++, b++) {
		*b = ((m >> i) & 1) + '0';
	}
	*b = '\0';
	post("%s", buf);
}

static gme_err_t gmepd_load(t_gme *x, int index) {
	gme_err_t err_msg;
	if ((err_msg = gme_start_track(x->emu, index))) {
		return err_msg;
	}

	gme_free_info(x->info);
	if ((err_msg = gme_track_info(x->emu, &x->info, index))) {
		return err_msg;
	}

	gme_set_fade(x->emu, -1, 0);

	// pad rubberband's buffer with silence
	rubberband_reset(x->state);
	unsigned nch = x->p.nch;
	unsigned pad = rubberband_get_preferred_start_pad(x->state);
	t_sample **buf = (t_sample **)getbytes(nch * sizeof(t_sample *));
	for (int i = nch; i--;) {
		buf[i] = (t_sample *)getbytes(pad * sizeof(t_sample));
	}
	rubberband_process(x->state, (const float *const *)buf, pad, 0);
	for (int i = nch; i--;) {
		freebytes(buf[i], pad * sizeof(t_sample));
	}
	freebytes(buf, nch * sizeof(t_sample *));

	return 0;
}

static void gmepd_open(t_gme *x, t_symbol *s) {
	x->p.play = 0;
	gme_err_t err_msg;
	gme_delete(x->emu); x->emu = NULL;
	if (!(err_msg = gme_open_file(s->s_name, &x->emu, sys_getsr(), x->p.nch > 2))) {
		// check for a .m3u file of the same name
		char m3u_path[256 + 5];
		strncpy(m3u_path, s->s_name, 256);
		m3u_path[256] = 0;
		char *p = strrchr(m3u_path, '.');
		if (!p) {
			p = m3u_path + strlen(m3u_path);
		}
		strcpy(p, ".m3u");
		gme_load_m3u(x->emu, m3u_path);

		gme_ignore_silence(x->emu, 1);
		gme_mute_voices(x->emu, x->mask);
		gme_set_tempo(x->emu, 1.0);
		x->voices = gme_voice_count(x->emu);
		err_msg = gmepd_load(x, 0);
		x->path = s;
	}
	if (err_msg) {
		pd_error(x, "%s.", err_msg);
	}
	x->p.open = !err_msg;
	t_atom open = { .a_type = A_FLOAT, .a_w = {.w_float = x->p.open} };
	outlet_anything(x->p.o_meta, s_open, 1, &open);
}

static inline t_float gmepd_length(t_gme *x) {
	t_float f = x->info->length;
	if (f < 0) { // try intro + 2 loops
		int intro = x->info->intro_length, loop = x->info->loop_length;
		if (intro < 0 && loop < 0) {
			return f;
		}
		f = (intro >= 0 ? intro : 0) + (loop >= 0 ? loop * 2 : 0);
	}
	return f;
}

static inline t_atom gmepd_ftime(t_gme *x) {
	int ms = gmepd_length(x);
	if (ms < 0) {
		ms = 0;
	}
	if (x->info->fade_length > 0) {
		ms += x->info->fade_length;
	}
	return player_ftime(ms);
}

static const t_symbol *dict[13];

static t_atom gmepd_meta(void *y, t_symbol *s) {
	t_gme *x = (t_gme *)y;
	t_atom meta;
	if (s == dict[0]) { // path
		SETSYMBOL(&meta, x->path);
	} else if (s == dict[1]) { // time
		meta = player_time(gmepd_length(x));
	} else if (s == dict[2]) { // ftime
		meta = gmepd_ftime(x);
	} else if (s == dict[3]) { // fade
		SETFLOAT(&meta, x->info->fade_length);
	} else if (s == dict[4]) { // tracks
		SETFLOAT(&meta, gme_track_count(x->emu));
	} else if (s == dict[5]) { // voices
		SETFLOAT(&meta, x->voices);
	} else if (s == dict[6]) { // system
		SETSYMBOL(&meta, gensym(x->info->system));
	} else if (s == dict[7]) { // game
		SETSYMBOL(&meta, gensym(x->info->game));
	} else if (s == dict[8]) { // song
		SETSYMBOL(&meta, gensym(x->info->song));
	} else if (s == dict[9]) { // author
		SETSYMBOL(&meta, gensym(x->info->author));
	} else if (s == dict[10]) { // copyright
		SETSYMBOL(&meta, gensym(x->info->copyright));
	} else if (s == dict[11]) { // comment
		SETSYMBOL(&meta, gensym(x->info->comment));
	} else if (s == dict[12]) { // dumper
		SETSYMBOL(&meta, gensym(x->info->dumper));
	} else {
		meta = (t_atom){ A_SYMBOL, {.w_symbol = &s_bang} };
	}
	return meta;
}

static void gmepd_print(t_gme *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!x->p.open) {
		return post("No file opened.");
	}
	if (ac) {
		return player_info_custom(&x->p, ac, av);
	}

	if (x->info->game || x->info->song) {
		// general track info: %game% - %song%
		post("%s%s%s"
		, *x->info->game ? x->info->game : ""
		, " - "
		, *x->info->song ? x->info->song : "");
	}
}

static void gmepd_float(t_gme *x, t_float f) {
	if (!x->emu) {
		return post("No file opened.");
	}
	int track = f;
	gme_err_t err_msg = "";
	if (0 < track && track <= gme_track_count(x->emu)) {
		if ((err_msg = gmepd_load(x, track - 1))) {
			pd_error(x, "%s.", err_msg);
		}
		x->p.open = !err_msg;
	} else {
		gmepd_seek(x, 0);
	}
	x->p.play = !err_msg;
	t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = x->p.play} };
	outlet_anything(x->p.o_meta, s_play, 1, &play);
}

static void gmepd_stop(t_gme *x) {
	gmepd_float(x, 0);
}

static void *gmepd_new(t_class *gmeclass, int nch, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_gme *x = (t_gme *)player_new(gmeclass, nch);
	t_inlet *in2 = signalinlet_new(&x->p.obj, 1.0);
	x->tempo = &in2->iu_floatsignalvalue;
	t_inlet *in3 = signalinlet_new(&x->p.obj, 1.0);
	x->pitch = &in3->iu_floatsignalvalue;

	RubberBandOptions options = RubberBandOptionProcessRealTime
	| RubberBandOptionEngineFiner;
	x->state = rubberband_new(sys_getsr(), nch, options, 1.0, 1.0);

	x->buf = (t_sample **)getbytes(ac * sizeof(t_sample *));
	for (int i = nch; i--;) {
		x->buf[i] = (t_sample *)getbytes(FRAMES * sizeof(t_sample));
	}

	x->mask = 0;
	x->voices = 16;
	x->path = gensym("no track loaded");
	if (ac) {
		x->mask = ~0;
		gmepd_mute(x, NULL, ac, av);
	}
	return x;
}

static void gmepd_free(t_gme *x) {
	gme_free_info(x->info);
	gme_delete(x->emu);
	player_free(&x->p);
	rubberband_delete(x->state);
	for (int i = x->p.nch; i--;) {
		freebytes(x->buf[i], FRAMES * sizeof(t_sample));
	}
	freebytes(x->buf, x->p.nch * sizeof(t_sample *));
}

static t_class *gmepd_setup(t_symbol *s, t_newmethod newm) {
	dict[0] = gensym("path");
	dict[1] = gensym("time");
	dict[2] = gensym("ftime");
	dict[3] = gensym("fade");
	dict[4] = gensym("tracks");
	dict[5] = gensym("voices");
	dict[6] = gensym("system");
	dict[7] = gensym("game");
	dict[8] = gensym("song");
	dict[9] = gensym("author");
	dict[10] = gensym("copyright");
	dict[11] = gensym("comment");
	dict[12] = gensym("dumper");

	s_mask = gensym("mask");
	fn_meta = gmepd_meta;

	t_class *cls = class_player(s, newm, (t_method)gmepd_free, sizeof(t_gme));
	class_addfloat(cls, gmepd_float);

	class_addmethod(cls, (t_method)gmepd_seek, gensym("seek"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)gmepd_tempo, gensym("tempo"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)gmepd_pitch, gensym("pitch"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)gmepd_mute, gensym("mute"), A_GIMME, 0);
	class_addmethod(cls, (t_method)gmepd_mask, gensym("mask"), A_GIMME, 0);
	class_addmethod(cls, (t_method)gmepd_print, gensym("print"), A_GIMME, 0);
	class_addmethod(cls, (t_method)gmepd_open, gensym("open"), A_SYMBOL, 0);
	class_addmethod(cls, (t_method)gmepd_stop, gensym("stop"), A_NULL);
	class_addmethod(cls, (t_method)gmepd_bmask, gensym("bmask"), A_NULL);

	return cls;
}

/* -------------------------- gmer~ ------------------------------ */
static t_class *gmer_tilde_class;

static void *gmer_tilde_new(t_symbol *s, int ac, t_atom *av) {
	return gmepd_new(gmer_tilde_class, 2, s, ac, av);
}

void gmer_tilde_setup(void) {
	gmer_tilde_class = gmepd_setup(gensym("gmer~"), (t_newmethod)gmer_tilde_new);
	class_addmethod(gmer_tilde_class, (t_method)gmepd_dsp
	, gensym("dsp"), A_CANT, 0);
}
