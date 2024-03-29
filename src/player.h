#include "inlet.h"
#include "pause.h"
#include <string.h>

static t_symbol *s_open;
static t_symbol *s_play;
static t_atom(*fn_meta)(void *, t_symbol *);

typedef struct _vinlet {
	t_float *p; // inlet pointer
	t_float v; // internal value
} t_vinlet;

typedef struct _player {
	t_object obj;
	t_sample **outs;
	unsigned char play; /* play/pause toggle */
	unsigned char open; /* true when a file has been successfully opened */
	unsigned nch;       /* number of channels */
	t_outlet *o_meta;   /* outputs track metadata */
} t_player;

static inline t_atom player_time(t_float ms) {
	return (t_atom) {
		.a_type = A_FLOAT, .a_w = { .w_float = ms }
	};
}

static inline t_atom player_ftime(int64_t ms) {
	char time[33], *t = time;
	double hr = ms / 3600000.;
	float mn = (hr - (int)hr) * 60;
	float sc = (mn - (int)mn) * 60;
	if (hr >= 1) {
		sprintf(t, "%d:", (int)hr);
		t += strlen(t);
	}
	sprintf(t, "%02d:%02d", (int)mn, (int)sc);
	return (t_atom) {
		.a_type = A_SYMBOL, .a_w = { .w_symbol = gensym(time) }
	};
}

static void player_info_custom(t_player *x, int ac, t_atom *av) {
	for (; ac--; av++) {
		if (av->a_type == A_SYMBOL) {
			const char *sym = av->a_w.w_symbol->s_name, *pct, *end;
			while ((pct = strchr(sym, '%')) && (end = strchr(pct + 1, '%'))) {
				int len = pct - sym;
				if (len) {
					char before[len + 1];
					strncpy(before, sym, len);
					before[len] = 0;
					startpost("%s", before);
					sym += len;
				}
				pct++;
				len = end - pct;
				char buf[len + 1];
				strncpy(buf, pct, len);
				buf[len] = 0;
				t_atom meta = fn_meta(x, gensym(buf));
				t_symbol *s = meta.a_w.w_symbol;
				switch (meta.a_type) {
				case A_FLOAT: startpost("%g", meta.a_w.w_float); break;
				case A_SYMBOL: startpost("%s", s == &s_bang ? "" : s->s_name); break;
				default: startpost("");
				}
				sym += len + 2;
			}
			startpost("%s%s", sym, ac ? " " : "");
		} else if (av->a_type == A_FLOAT) {
			startpost("%g%s", av->a_w.w_float, ac ? " " : "");
		}
	}
	endpost();
}

static void player_send(t_player *x, t_symbol *s) {
	if (!x->open) {
		return post("No file opened.");
	}
	t_atom meta = fn_meta(x, s);
	outlet_anything(x->o_meta, s, 1, &meta);
}

static void player_anything(t_player *x, t_symbol *s, int ac, t_atom *av) {
	(void)ac;
	(void)av;
	player_send(x, s);
}

static void player_play(t_player *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!x->open) {
		return post("No file opened.");
	}
	if (pause_state(&x->play, ac, av)) {
		return;
	}
	t_atom play = { .a_type = A_FLOAT, .a_w = {.w_float = x->play} };
	outlet_anything(x->o_meta, s_play, 1, &play);
}

static void player_bang(t_player *x) {
	player_play(x, 0, 0, 0);
}

static t_player *player_new(t_class *cl, unsigned nch) {
	t_player *x = (t_player *)pd_new(cl);
	x->nch = nch;
	x->outs = (t_sample **)getbytes(nch * sizeof(t_sample *));
	while (nch--) {
		outlet_new(&x->obj, &s_signal);
	}
	x->o_meta = outlet_new(&x->obj, 0);
	x->open = x->play = 0;
	return x;
}

static void player_free(t_player *x) {
	freebytes(x->outs, x->nch * sizeof(t_sample *));
}

static t_class *class_player
(t_symbol *s, t_newmethod newm, t_method free, size_t size) {
	s_open = gensym("open");
	s_play = gensym("play");

	t_class *cls = class_new(s, newm, free, size, 0, A_GIMME, 0);
	class_addbang(cls, player_bang);
	class_addanything(cls, player_anything);
	class_addmethod(cls, (t_method)player_send, gensym("send"), A_SYMBOL, 0);
	class_addmethod(cls, (t_method)player_play, gensym("play"), A_GIMME, 0);
	return cls;
}
