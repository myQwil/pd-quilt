#include "../m_pd.h"
#include <math.h>

/* -------------------------- muse -------------------------- */

t_float ntof(t_float f, t_float rt, t_float st) {
	if (f <= -1500) return(0);
	else if (f > 1499) return(ntof(1499, rt, st));
	else return (rt * exp(st*f));
}

static t_class *muse_class;

typedef struct _muse {
	t_object x_obj;
	t_int x_n, x_max;		/* # of notes in a scale */
	t_float x_oct;			/* octave */
	t_float x_ref, x_tet;	/* ref-pitch, # of tones */
	t_float x_rt, x_st;		/* root tone, semi-tone */
	t_float *x_scl;			/* scale-input values */
	t_outlet *f_out, *m_out;/* frequency, midi */
} t_muse;

static void muse_scale(t_muse *x, int ac, t_atom *av, int offset) {
	if (!ac || ac+offset > x->x_max) {
		pd_error(x, "muse: too many/few args"); return; }
	int i;
	t_float *fp = x->x_scl+offset;
	x->x_n=ac+offset;
	for (i=ac; i--; av++, fp++)
		if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
}

static void muse_key(t_muse *x, t_symbol *s, int ac, t_atom *av)
{ muse_scale(x, ac, av, 0); }

static void muse_list(t_muse *x, t_symbol *s, int ac, t_atom *av)
{ muse_scale(x, ac, av, 1); }

static void muse_skip(t_muse *x, t_symbol *s, int ac, t_atom *av)
{ muse_scale(x, ac, av, 2); }

static void muse_size(t_muse *x, t_floatarg n) {
	if (n<1 || n>x->x_max) {
		pd_error(x, "muse: bad scale size"); return; }
	x->x_n=n;
}

static void muse_set(t_muse *x, t_floatarg i, t_floatarg f) {
	if (i<0 || i>=x->x_max) {
		pd_error(x, "muse: bad index range"); return; }
	*(x->x_scl+(int)i)=f;
}

static void muse_octave(t_muse *x, t_floatarg f)
{ x->x_oct=f; }

static void muse_ref(t_muse *x, t_floatarg f)
{ x->x_rt = (x->x_ref=f) * pow(2,-69/x->x_tet); }

static void muse_tet(t_muse *x, t_floatarg f) {
	x->x_rt = x->x_ref * pow(2,-69/f);
	x->x_st = log(2) / (x->x_tet=f);
}

static void muse_octet(t_muse *x, t_floatarg f) {
	muse_octave(x,f); muse_tet(x,f);
}

static double getnote(t_muse *x, int d) {
	int n=x->x_n, dn=d%n;
	double root = x->x_scl[0];
	int oct = d/n - (dn<0); // floor negatives
	d = (dn+n) % n; // modulo always positive
	double step = (d ? x->x_scl[d] : 0);
	return (root + step + (oct * x->x_oct));
}

static void muse_float(t_muse *x, t_float f) {
	int d=f;
	double note = getnote(x, d);
	if (f!=d) {
		int b = f<0?-1:1;
		double next = getnote(x, d+b);
		note = b*(f-d) / (1/(next-note)) + note; }
	outlet_float(x->m_out, note);
	outlet_float(x->f_out, ntof(note, x->x_rt, x->x_st));
}

static void *muse_new(t_symbol *s, int argc, t_atom *argv) {
	t_muse *x = (t_muse *)pd_new(muse_class);
	t_float ref=x->x_ref=440, tet=x->x_tet=12;
	
	x->x_rt = ref * pow(2,-69/tet);
	x->x_st = log(2) / tet;
	
	x->x_oct = tet;
	x->x_max = argc>tet ? argc:tet;
	x->x_scl = (t_float *)getbytes(x->x_max * sizeof(*x->x_scl));
	
	if (argc<2) {
		*x->x_scl = (argc ? atom_getfloat(argv) : 0);
		floatinlet_new(&x->x_obj, x->x_scl);
		*(x->x_scl+1)=7, x->x_n=2, argc=0; }
	else x->x_n = argc;
	
	int i; t_float *fp;
	for (i=argc, fp=x->x_scl; i--; argv++, fp++) {
		*fp = atom_getfloat(argv);
		floatinlet_new(&x->x_obj, fp); }
	x->f_out = outlet_new(&x->x_obj, &s_float); // frequency
	x->m_out = outlet_new(&x->x_obj, &s_float); // midi note
	return (x);
}

static void muse_free(t_muse *x)
{ freebytes(x->x_scl, x->x_max * sizeof(*x->x_scl)); }

void muse_setup(void) {
	muse_class = class_new(gensym("muse"),
		(t_newmethod)muse_new, (t_method)muse_free,
		sizeof(t_muse), 0,
		A_GIMME, 0);
		
	class_addlist(muse_class, muse_list);
	class_addfloat(muse_class, muse_float);
	class_addmethod(muse_class, (t_method)muse_key,
		gensym("k"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_skip,
		gensym("s"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_size,
		gensym("n"), A_FLOAT, 0);		
	class_addmethod(muse_class, (t_method)muse_octave,
		gensym("oct"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_tet,
		gensym("tet"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_octet,
		gensym("octet"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_set,
		gensym("set"), A_FLOAT, A_FLOAT, 0);
}
