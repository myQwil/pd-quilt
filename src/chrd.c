#include "music.h"

/* -------------------------- chrd -------------------------- */
static t_class *chrd_class;

typedef struct _chrd {
	t_music z;
	unsigned ins;       /* number of inlets */
	unsigned char all;  /* all-outlets toggle */
	unsigned char midi; /* midi-note toggle */
	t_outlet **outs;    /* outlets */
} t_chrd;

static void chrd_midi(t_chrd *y, t_float f) {
	y->midi = f;
}

static void chrd_all(t_chrd *y, t_float f) {
	y->all = f;
}

static inline t_float chrd_step(t_music *x, int d) {
	if (!d) {
		return x->flin.fp[0];
	}
	int n = x->siz - (x->siz > 1);
	int i = (d - (d > 0)) % n, neg = i < 0;
	i += n * neg + 1;
	t_float step = x->flin.fp[i];
	return (x->oct * ((d - !neg) / n - neg) + x->flin.fp[0] + step);
}

static void music_f(t_music *x, t_float f, op_func op, t_float g) {
	t_chrd *y = (t_chrd *)x;
	int d = f;
	t_float nte = chrd_step(x, d);
	if (f != d) {
		int dir = f < 0 ? -1 : 1;
		t_float nxt = chrd_step(x, d + dir);
		nte += dir * (f - d) * (nxt - nte);
	}
	if (op) {
		op(&nte, g);
	}
	int n = y->ins - 1, i = (d - (d > 0)) % n;
	i += (i < 0) * n + 1;
	if (!d) {
		i = 0;
	}
	outlet_float(y->outs[i], y->midi ? nte : ntof(&x->note, nte));
}

static void chrd_bang(t_chrd *y) {
	t_music *x = &y->z;
	int n = x->siz, i = y->ins;
	i = y->all ? i : (n > i ? i : n);
	for (t_outlet **op = y->outs + i; op--, i--;) {
		double nte = chrd_step(x, i);
		outlet_float(*op, y->midi ? nte : ntof(&x->note, nte));
	}
}

static void *chrd_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	int n = ac < 3 ? 3 : ac;
	t_chrd *y = (t_chrd *)music_new(chrd_class, n);
	t_music *x = &y->z;

	y->ins = n;
	y->outs = (t_outlet **)getbytes(y->ins * sizeof(t_outlet *));
	t_float *fp = x->flin.fp;
	t_outlet **op = y->outs;
	fp[0] = 69, fp[1] = 7, fp[2] = 12;

	for (int i = 0; n--; op++, fp++, i++) {
		*op = outlet_new(&x->obj, &s_float);
		floatinlet_new(&x->obj, fp);
		if (i < ac) {
			*fp = atom_getfloat(av++);
		}
	}

	return y;
}

static void chrd_free(t_chrd *y) {
	t_music *x = &y->z;
	flin_free(&x->flin);
	freebytes(y->outs, y->ins * sizeof(t_outlet *));
}

void chrd_setup(void) {
	chrd_class = class_music(gensym("chrd")
	, (t_newmethod)chrd_new, (t_method)chrd_free
	, sizeof(t_chrd));
	class_addbang(chrd_class, chrd_bang);
	class_addmethod(chrd_class, (t_method)chrd_midi, gensym("midi"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_all, gensym("all"), A_FLOAT, 0);
}
