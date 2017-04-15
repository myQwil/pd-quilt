#include "m_pd.h"
#include <stdlib.h>
#include <math.h>

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	t_float *i_floatslot;
};

t_float ntof(t_float f, double root, double semi) {
	return (root * exp(semi*f));
}

/* -------------------------- muse -------------------------- */

static t_class *muse_class;

typedef struct _muse {
	t_object x_obj;
	int x_n, x_max, x_inl;	/* # of notes in a scale, # of inlets */
	unsigned x_imp:1;		/* implicit scale size toggle */
	double x_rt, x_st;		/* root tone, semi-tone */
	t_float x_oct,			/* # of notes between octaves */
		x_ref, x_tet,		/* ref-pitch, # of tones */
		*x_scl;				/* scale-input values */
	t_outlet *f_out, *m_out;/* frequency, midi */
} t_muse;

static void muse_ptr(t_muse *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->x_max);
}

static void muse_peek(t_muse *x, t_symbol *s) {
	int i;
	t_float *fp = x->x_scl;
	if (*s->s_name) startpost("%s: ", s->s_name);
	for (i=x->x_n; i--; fp++) startpost("%g ", *fp);
	endpost();
}

static void muse_operate(t_float *fp, t_atom *av) {
	char *cp = av->a_w.w_symbol->s_name;
	if (cp[1])
	{	t_float f = cp[2] ? atof(cp+2) : 1;
			 if (cp[1]=='+') *fp += f;
		else if (cp[1]=='-') *fp -= f;
		else if (cp[1]=='*') *fp *= f;
		else if (cp[1]=='/') *fp /= f;   }
}

static void muse_resize(t_muse *x, t_float n) {
	int size = 2*x->x_max;
	if (size<n) size=n;
	if (size>1024) size=1024;
	x->x_scl = (t_float *)resizebytes(x->x_scl,
		x->x_max * sizeof(t_float), size * sizeof(t_float));
	x->x_max=size;
	
	int i;
	t_float *fp = x->x_scl;
	t_inlet *ip = ((t_object *)x)->ob_inlet;
	for (i=x->x_inl; i--; fp++, ip=ip->i_next)
		ip->i_floatslot = fp;
}

static void muse_set(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = av->a_w.w_float;
		if (i>=0 && i<1024)
		{	if (i>=x->x_max) muse_resize(x,i+1);
			if ((av+1)->a_type == A_FLOAT)
				x->x_scl[i] = (av+1)->a_w.w_float;
			else if ((av+1)->a_type == A_SYMBOL)
				muse_operate(x->x_scl+i, av+1);   }   }
	else pd_error(x, "muse_set: bad arguments");
}

static void muse_imp(t_muse *x, int ac, int offset) {
	int n = x->x_n = ac+offset;
	if (n>x->x_max) muse_resize(x,n);
}

static void muse_scale(t_muse *x, int ac, t_atom *av, int offset) {
	t_float *fp = x->x_scl+offset;
	for (; ac--; av++, fp++)
	{	if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL) muse_operate(fp, av);   }
}

static void muse_scimp(t_muse *x, int ac, t_atom *av, int offset) {
	if (x->x_imp) muse_imp(x, ac, offset);
	muse_scale(x, ac, av, offset);
}

static void muse_doremi(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) muse_scimp(x, ac, av, 1);
}

static void muse_list(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) muse_scimp(x, ac, av, 0);
}

static void muse_im(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	muse_imp(x, ac, 0);
	if (ac) muse_scale(x, ac, av, 0);
}

static void muse_ex(t_muse *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) muse_scale(x, ac, av, 0);
}

static void muse_size(t_muse *x, t_float n) {
	if (n>0)
	{	if (n>1024) return;
		if (n>x->x_max) muse_resize(x,n);
		x->x_n=n;   }
	else x->x_n=1;
}

static void muse_implicit(t_muse *x, t_float f) {
	x->x_imp=f;
}

static void muse_octave(t_muse *x, t_float f) {
	x->x_oct=f;
}

static void muse_ref(t_muse *x, t_float f) {
	x->x_rt = (x->x_ref=f) * pow(2,-69/x->x_tet);
}

static void muse_tet(t_muse *x, t_float f) {
	x->x_rt = x->x_ref * pow(2,-69/f);
	x->x_st = log(2) / (x->x_tet=f);
}

static void muse_octet(t_muse *x, t_float f) {
	muse_octave(x,f);   muse_tet(x,f);
}

static double getnote(t_muse *x, int d) {
	int n=x->x_n, p=d%n, b=p<0,
	q = d/n-b;
	d = b*n+p;
	t_float root = x->x_scl[0],
		step = d ? x->x_scl[d] : 0;
	return (x->x_oct*q + root+step);
}

static void muse_float(t_muse *x, t_float f) {
	int d=f;
	double note = getnote(x, d);
	if (f!=d)
	{	int b = f<0?-1:1;
		double next = getnote(x, d+b);
		note += b*(f-d) * (next-note);   }
	outlet_float(x->m_out, note);
	outlet_float(x->f_out, ntof(note, x->x_rt, x->x_st));
}

static void *muse_new(t_symbol *s, int argc, t_atom *argv) {
	t_muse *x = (t_muse *)pd_new(muse_class);
	t_float ref=x->x_ref=440, tet=x->x_tet=12;
	x->x_imp=1;
	
	x->x_rt = ref * pow(2,-69/tet);
	x->x_st = log(2) / tet;
	
	x->x_oct = tet;
	x->x_max = x->x_inl = x->x_n = argc<2 ? 2:argc;
	x->x_scl = (t_float *)getbytes(x->x_max * sizeof(t_float));
	
	if (argc<2)
	{	x->x_scl[0] = (argc ? atom_getfloat(argv) : 69);
		floatinlet_new(&x->x_obj, x->x_scl);
		x->x_scl[1] = (argc>1 ? atom_getfloat(argv+1) : 7);
		floatinlet_new(&x->x_obj, x->x_scl+1);
		argc=0;   }
	
	t_float *fp;
	for (fp=x->x_scl; argc--; argv++, fp++)
	{	*fp = atom_getfloat(argv);
		floatinlet_new(&x->x_obj, fp);   }
	x->f_out = outlet_new(&x->x_obj, &s_float); // frequency
	x->m_out = outlet_new(&x->x_obj, &s_float); // midi note
	return (x);
}

static void muse_free(t_muse *x) {
	freebytes(x->x_scl, x->x_max * sizeof(t_float));
}

void muse_setup(void) {
	muse_class = class_new(gensym("muse"),
		(t_newmethod)muse_new, (t_method)muse_free,
		sizeof(t_muse), 0,
		A_GIMME, 0);
	
	class_addlist(muse_class, muse_list);
	class_addfloat(muse_class, muse_float);
	class_addmethod(muse_class, (t_method)muse_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(muse_class, (t_method)muse_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(muse_class, (t_method)muse_set,
		gensym("set"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_doremi,
		gensym("d"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_list,
		gensym("l"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_im,
		gensym("i"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_ex,
		gensym("x"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)muse_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_implicit,
		gensym("imp"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_octave,
		gensym("oct"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_tet,
		gensym("tet"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_octet,
		gensym("octet"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)muse_octet,
		gensym("ot"), A_FLOAT, 0);
}
