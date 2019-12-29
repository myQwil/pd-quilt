#include "m_pd.h"
#include <stdlib.h> // strtof
#include <math.h>   // exp, pow, log

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	t_float *i_floatslot;
};

static t_float ntof(t_float f, double root, double semi) {
	return (root * exp(semi*f));
}

/* -------------------------- muse -------------------------- */

static t_class *muse_class;

typedef struct _muse {
	t_object x_obj;
	int x_n;          /* current scale size */
	int x_in;         /* # of inlets */
	int x_p;          /* pointer size */
	int x_exp;        /* explicit scale size toggle */
	double x_rt;      /* root tone */
	double x_st;      /* semi-tone */
	t_float x_oct;    /* # of semitone steps per octave */
	t_float x_tet;    /* # of tones within an octave */
	t_float x_ref;    /* reference pitch */
	t_float *x_scl;   /* the scale (root + intervals) */
	t_outlet *f_out;  /* frequency outlet */
	t_outlet *m_out;  /* midi outlet */
} t_muse;

#define MAX 1024

static void muse_ptr(t_muse *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->x_p);
}

static void muse_peek(t_muse *x, t_symbol *s) {
	int i;
	t_float *fp = x->x_scl;
	if (*s->s_name) startpost("%s: ", s->s_name);
	for (i=x->x_n; i--; fp++) startpost("%g ", *fp);
	endpost();
}

static void muse_operate(t_float *fp, t_atom *av) {
	const char *cp = av->a_w.w_symbol->s_name;
	if (cp[1])
	{	t_float f = cp[2] ? strtof(cp+2, NULL) : 1;
			 if (cp[1]=='+') *fp += f;
		else if (cp[1]=='-') *fp -= f;
		else if (cp[1]=='*') *fp *= f;
		else if (cp[1]=='/') *fp /= f;   }
}

static int muse_resize(t_muse *x, int n, int l) {
	n += l;
	if (n<1) n=1; else if (n>MAX) n=MAX;
	if (x->x_p<n)
	{	int d=2, i;
		while (d<MAX && d<n) d*=2;
		x->x_scl = (t_float *)resizebytes(x->x_scl,
			x->x_p * sizeof(t_float), d * sizeof(t_float));
		x->x_p = d;
		t_float *fp = x->x_scl;
		t_inlet *ip = ((t_object *)x)->ob_inlet;
		for (i=x->x_in; i--; fp++, ip=ip->i_next)
			ip->i_floatslot = fp;   }
	return (n-l);
}

static void muse_at(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = muse_resize(x, av->a_w.w_float, 1);
		t_atomtype typ = (av+1)->a_type;
		if (typ == A_FLOAT) x->x_scl[i] = (av+1)->a_w.w_float;
		else if (typ == A_SYMBOL) muse_operate(x->x_scl+i, av+1);   }
	else pd_error(x, "muse_at: bad arguments");
}

static void muse_size(t_muse *x, t_floatarg n) {
	x->x_n = muse_resize(x, n, 0);
}

static void muse_imp(t_muse *x, int ac, int offset) {
	x->x_n = muse_resize(x, ac+offset, 0);
}

static void muse_scale(t_muse *x, int ac, t_atom *av, int offset) {
	t_float *fp = x->x_scl+offset;
	for (; ac--; av++, fp++)
	{	if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL) muse_operate(fp, av);   }
}

static void muse_scimp(t_muse *x, int ac, t_atom *av, int offset) {
	if (!x->x_exp) muse_imp(x, ac, offset);
	muse_scale(x, ac, av, offset);
}

static void muse_doremi(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) muse_scimp(x, ac, av, 1);
}

static void muse_list(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) muse_scimp(x, ac, av, 0);
}

static void muse_i(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac)
	{	muse_imp(x, ac, 0);
		muse_scale(x, ac, av, 0);   }
}

static void muse_x(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) muse_scale(x, ac, av, 0);
}

static void muse_explicit(t_muse *x, t_floatarg f) {
	x->x_exp = f;
}

static void muse_octave(t_muse *x, t_floatarg f) {
	x->x_oct = f;
}

static void muse_ref(t_muse *x, t_floatarg f) {
	x->x_rt = pow(2, -69/x->x_tet) * (x->x_ref=f);
}

static void muse_tet(t_muse *x, t_floatarg f) {
	x->x_rt = pow(2, -69/f) * x->x_ref;
	x->x_st = log(2) / (x->x_tet=f);
}

static void muse_octet(t_muse *x, t_floatarg f) {
	muse_octave(x,f);   muse_tet(x,f);
}

static double muse_getnote(t_muse *x, int d) {
	int n=x->x_n, i=d%n, b=i<0, q=d/n-b;
	i += b*n;
	t_float root = x->x_scl[0],
		step = i ? x->x_scl[i] : 0;
	return (x->x_oct*q + root+step);
}

static void muse_float(t_muse *x, t_float f) {
	int d=f;
	double note = muse_getnote(x, d);
	if (f!=d)
	{	int b = f<0?-1:1;
		double next = muse_getnote(x, d+b);
		note += b*(f-d) * (next-note);   }
	outlet_float(x->m_out, note);
	outlet_float(x->f_out, ntof(note, x->x_rt, x->x_st));
}

static void *muse_new(t_symbol *s, int ac, t_atom *av) {
	t_muse *x = (t_muse *)pd_new(muse_class);
	x->f_out = outlet_new(&x->x_obj, &s_float);
	x->m_out = outlet_new(&x->x_obj, &s_float);

	int n = x->x_n = x->x_in = x->x_p = ac<2 ? 2 : ac;
	x->x_scl = (t_float *)getbytes(x->x_p * sizeof(t_float));
	t_float *fp = x->x_scl;
	fp[0]=69, fp[1]=7;

	// if no args, 'i' will prevent writing over default values
	for (int i=0; n--; fp++, i++)
	{	floatinlet_new(&x->x_obj, fp);
		if (i<ac) *fp = atom_getfloat(av++);   }

	double ref=x->x_ref=440, tet=x->x_tet=12;
	x->x_rt = pow(2, -69/tet) * ref;
	x->x_st = log(2) / tet;
	x->x_oct = tet;
	x->x_exp = 0;

	return (x);
}

static void muse_free(t_muse *x) {
	freebytes(x->x_scl, x->x_p * sizeof(t_float));
}

void muse_setup(void) {
	muse_class = class_new(gensym("muse"),
		(t_newmethod)muse_new, (t_method)muse_free,
		sizeof(t_muse), 0,
		A_GIMME, 0);
	class_addfloat(muse_class, muse_float);
	class_addlist(muse_class, muse_list);
	class_addmethod(muse_class, (t_method)muse_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(muse_class, (t_method)muse_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(muse_class, (t_method)muse_at,
		gensym("@"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_doremi,
		gensym("d"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_list,
		gensym("l"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_i,
		gensym("i"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_x,
		gensym("x"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_explicit,
		gensym("exp"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_octave,
		gensym("oct"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_tet,
		gensym("tet"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_octet,
		gensym("ot"), A_FLOAT, 0);
}
