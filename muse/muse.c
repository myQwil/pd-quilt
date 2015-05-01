#include "../m_pd.h"

/* -------------------------- muse -------------------------- */

static t_class *muse_class;

typedef struct _muse {
	t_object x_obj;
	t_int x_n, x_max;		/* # of notes in a scale */
	t_float x_oct;			/* octave */
	t_float *x_scl;			/* scale-input values */
	t_outlet *f_out, *m_out;/* frequency, midi */
} t_muse;

static double getnote(t_muse *x, int d) {
	int n=x->x_n, dn=d%n;
	double root = x->x_scl[0];
	int oct = d/n - (dn<0); // floor negatives
	d = (dn+n) % n; // modulo always positive
	double step = (d ? x->x_scl[d] : 0);
	return (root + step + (oct * x->x_oct));
}

static void muse_float(t_muse *x, t_float f) {
	int d = f;
	double note = getnote(x, d);
	if (f!=d) {
		if (f<0) d=f-1, f*=-1; else d=f+1;
		double next = getnote(x, d);
		note = (f-(int)f) / (1 / (next-note)) + note;
	}
	outlet_float(x->f_out, mtof(note));
	outlet_float(x->m_out, note);
}

static void muse_list(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (!ac||ac>=x->x_max)
	{ pd_error(x, "muse: too many/few args"); return; }
	
	int i; t_float *fp = x->x_scl+1;
	x->x_n=ac+1;
	for (i=ac; i--; av++, fp++)
		if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
}

static void muse_key(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (!ac||ac>x->x_max)
	{ pd_error(x, "muse: too many/few args"); return; }
	
	if (av->a_type == A_FLOAT) *x->x_scl = av->a_w.w_float;
	if (ac>1) muse_list(x, 0, ac-1, av+1);
}

static void muse_size(t_muse *x, t_floatarg f) {
	x->x_n = f;
}

static void muse_octave(t_muse *x, t_floatarg f) {
	x->x_oct = f;
}

static void *muse_new(t_symbol *s, int argc, t_atom *argv) {
	t_muse *x = (t_muse *)pd_new(muse_class);
	
	x->x_oct = 12;
	x->x_max = (argc > 12 ? argc : 12); // enough space for a chromatic scale
	x->x_scl = (t_float *)getbytes(x->x_max * sizeof(*x->x_scl));
	
	if (argc < 2) {
		*x->x_scl = (argc ? atom_getfloat(argv) : 0);
		floatinlet_new(&x->x_obj, x->x_scl);
		*(x->x_scl+1) = 7; // perfect fifth
		x->x_n = 2;
		argc = 0;
	} else x->x_n = argc;
	
	int i; t_float *fp;
	for (i=argc, fp=x->x_scl; i--; argv++, fp++) {
		*fp = atom_getfloat(argv);
		floatinlet_new(&x->x_obj, fp);
	}
	x->f_out = outlet_new(&x->x_obj, &s_float); // frequency
	x->m_out = outlet_new(&x->x_obj, &s_float); // midi note
	return (x);
}

static void muse_free(t_muse *x) {
	freebytes(x->x_scl, x->x_max * sizeof(*x->x_scl));
}

void muse_setup(void) {
	muse_class = class_new(gensym("muse"),
		(t_newmethod)muse_new, (t_method)muse_free,
		sizeof(t_muse), 0,
		A_GIMME, 0);
		
	class_addfloat(muse_class, muse_float);
	class_addlist(muse_class, muse_list);
	class_addmethod(muse_class, (t_method)muse_key,
		gensym("k"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_octave,
		gensym("oct"), A_FLOAT, 0);
}
