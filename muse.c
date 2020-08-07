#include "music.h"

/* -------------------------- muse -------------------------- */
static t_class *muse_class;

typedef struct _muse {
	t_music z;
	t_outlet *o_freq;    /* frequency outlet */
	t_outlet *o_midi;    /* midi outlet */
} t_muse;

static double muse_note(t_music *x, int d) {
	int n = x->x_n, i = d%n, neg = i<0;
	i += n * neg;
	t_float step = i ? fin.x_fp[i] : 0;
	return (x->x_oct * (d/n - neg) + fin.x_fp[0] + step);
}

static void muse_float(t_muse *y, t_float f) {
	t_music *x = &y->z;
	int d = f;
	double nte = muse_note(x, d);
	if (f != d)
	{	int dir = f<0 ? -1 : 1;
		double nxt = muse_note(x, d+dir);
		nte += dir * (f-d) * (nxt-nte);   }
	outlet_float(y->o_midi, nte);
	outlet_float(y->o_freq, ntof(&note, nte));
}

static void *muse_new(t_symbol *s, int ac, t_atom *av) {
	int n = (ac<2 ? 2 : ac);
	t_muse *y = (t_muse *)music_new(muse_class, n);
	t_music *x = &y->z;

	y->o_freq = outlet_new(&fin.x_obj, &s_float);
	y->o_midi = outlet_new(&fin.x_obj, &s_float);

	t_float *fp = fin.x_fp;
	fp[0]=69, fp[1]=7;

	for (int i=0; n--; fp++, i++)
	{	floatinlet_new(&fin.x_obj, fp);
		if (i<ac) *fp = atom_getfloat(av++);   }

	return (y);
}

void muse_setup(void) {
	muse_class = music_setup(gensym("muse"),
		(t_newmethod)muse_new, (t_method)fin_free, sizeof(t_muse));
	class_addfloat(muse_class, muse_float);
}
