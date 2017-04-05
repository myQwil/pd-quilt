#include "m_pd.h"
#include <stdlib.h>
#include <math.h>

union inletunion {
	t_symbol *iu_symto;
	t_gpointer *iu_pointerslot;
	t_float *iu_floatslot;
	t_symbol **iu_symslot;
	t_float iu_floatsignalvalue;
};

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	union inletunion i_un;
};

#define i_symto i_un.iu_symto
#define i_pointerslot i_un.iu_pointerslot
#define i_floatslot i_un.iu_floatslot
#define i_symslot i_un.iu_symslot

t_float ntof(t_float f, t_float root, t_float semi) {
	return (root * exp(semi*f));
}

/* -------------------------- harm -------------------------- */

static t_class *harm_class;

typedef struct harmout {
	t_outlet *u_outlet;
} t_harmout;

typedef struct _harm {
	t_object x_obj;
	t_int x_n, x_max, x_inl;/* # of notes in a scale, # of inlets */
	unsigned x_imp:1,		/* implicit scale size toggle */
		x_midi:1, x_all:1;	/* midi-note and all-note toggles */
	t_float x_oct,			/* # of notes between octaves */
		x_ref, x_tet,		/* ref-pitch, # of tones */
		x_rt, x_st,			/* root tone, semi-tone */
		*x_scl;				/* scale-input values */
	t_harmout *x_out;		/* outlets */
} t_harm;

static void harm_ptr(t_harm *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->x_max);
}

static void harm_peek(t_harm *x, t_symbol *s) {
	int i;
	t_float *fp = x->x_scl;
	if (*s->s_name) startpost("%s: ", s->s_name);
	for (i=x->x_n; i--; fp++) startpost("%g ", *fp);
	endpost();
}

static void harm_operate(t_float *fp, t_atom *av) {
	char *cp = av->a_w.w_symbol->s_name;
	if (cp[1])
	{	t_float f = cp[2] ? atof(cp+2) : 1;
			 if (cp[1]=='+') *fp += f;
		else if (cp[1]=='-') *fp -= f;
		else if (cp[1]=='*') *fp *= f;
		else if (cp[1]=='/') *fp /= f;   }
}

static void harm_resize(t_harm *x, t_floatarg n) {
	int size = 2*x->x_max;
	size = size<n?n:size;
	x->x_scl = (t_float *)resizebytes(x->x_scl,
		x->x_max * sizeof(t_float), size * sizeof(t_float));
	x->x_max=size;
	
	int i;
	t_float *fp = x->x_scl;
	t_inlet *ip = ((t_object *)x)->ob_inlet;
	for (i=x->x_inl; i--; fp++, ip=ip->i_next)
		ip->i_floatslot = fp;
}

static void harm_scl(t_harm *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = av->a_w.w_float;
		if (i>=0)
		{	if (i>=x->x_max) harm_resize(x,i+1);
			if ((av+1)->a_type == A_FLOAT)
				x->x_scl[i] = (av+1)->a_w.w_float;
			else if ((av+1)->a_type == A_SYMBOL)
				harm_operate(x->x_scl+i, av+1);   }   }
	else pd_error(x, "harm_scl: bad arguments");
}

static void harm_imp(t_harm *x, int ac, int offset) {
	int n = x->x_n = ac+offset;
	if (n>x->x_max) harm_resize(x,n);
}

static void harm_scale(t_harm *x, int ac, t_atom *av, int offset) {
	t_float *fp = x->x_scl+offset;
	for (; ac--; av++, fp++)
	{	if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL) harm_operate(fp, av);   }
}

static void harm_scimp(t_harm *x, int ac, t_atom *av, int offset) {
	if (x->x_imp) harm_imp(x, ac, offset);
	harm_scale(x, ac, av, offset);
}

static void harm_do(t_harm *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) harm_scimp(x, ac, av, 1);
}

static void harm_list(t_harm *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) harm_scimp(x, ac, av, 0);
}

static void harm_im(t_harm *x, t_symbol *s, int ac, t_atom *av) {
	harm_imp(x, ac, 0);
	if (ac) harm_scale(x, ac, av, 0);
}

static void harm_ex(t_harm *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) harm_scale(x, ac, av, 0);
}

static void harm_size(t_harm *x, t_floatarg n) {
	if (n>0)
	{	if (n>x->x_max) harm_resize(x,n);
		x->x_n=n;   }
}

static void harm_implicit(t_harm *x, t_floatarg f) {
	x->x_imp=f;
}

static void harm_midi(t_harm *x, t_floatarg f) {
	x->x_midi = f;
}

static void harm_all(t_harm *x, t_floatarg f) {
	x->x_all = f;
}

static void harm_octave(t_harm *x, t_floatarg f) {
	x->x_oct=f;
}

static void harm_ref(t_harm *x, t_floatarg f) {
	x->x_rt = (x->x_ref=f) * pow(2,-69/x->x_tet);
}

static void harm_tet(t_harm *x, t_floatarg f) {
	x->x_rt = x->x_ref * pow(2,-69/f);
	x->x_st = log(2) / (x->x_tet=f);
}

static void harm_octet(t_harm *x, t_floatarg f) {
	harm_octave(x,f);   harm_tet(x,f);
}

static double getnote(t_harm *x, int d) {
	int n=x->x_n, p=d%n, b=p<0,
	q = d/n-b;
	d = b*n+p;
	t_float root = x->x_scl[0],
		step = d ? x->x_scl[d] : 0;
	return (x->x_oct*q + root+step);
}

static void harm_float(t_harm *x, t_float f) {
	int n=x->x_inl, d=f;
	double note = getnote(x, d);
	if (f!=d)
	{	int b = f<0?-1:1;
		double next = getnote(x, d+b);
		note += b*(f-d) * (next-note);   }
	int p=d%n; if (p<0) p+=n;
	d = (d&&!p)?n:p;
	outlet_float((x->x_out+d)->u_outlet, x->x_midi ?
		note : ntof(note, x->x_rt, x->x_st));
}

static void harm_bang(t_harm *x) {
	int n=x->x_n, i=x->x_inl+1;
	i = x->x_all ? i : (n>i?i:n);
	t_harmout *u;
	for (u=x->x_out+i; u--, i--;)
	{	double note = getnote(x, i);
		outlet_float(u->u_outlet, x->x_midi ?
			note : ntof(note, x->x_rt, x->x_st));   }
}

static void *harm_new(t_symbol *s, int argc, t_atom *argv) {
	t_harm *x = (t_harm *)pd_new(harm_class);
	t_float ref=x->x_ref=440, tet=x->x_tet=12;
	x->x_imp=1;
	
	x->x_rt = ref * pow(2,-69/tet);
	x->x_st = log(2) / tet;
	
	x->x_oct = tet;
	x->x_max = x->x_inl = argc>1?argc:2;
	x->x_scl = (t_float *)getbytes(x->x_max * sizeof(t_float));
	x->x_out = (t_harmout *)getbytes((x->x_inl+1) * sizeof(t_harmout));
	t_harmout *u = x->x_out;
	
	if (argc<2)
	{	x->x_scl[0] = (argc ? atom_getfloat(argv) : 69);
		floatinlet_new(&x->x_obj, x->x_scl);
		x->x_scl[1] = (argc>1 ? atom_getfloat(argv+1) : 7);
		floatinlet_new(&x->x_obj, x->x_scl+1);
		u->u_outlet = outlet_new(&x->x_obj, &s_float);
		(u+1)->u_outlet = outlet_new(&x->x_obj, &s_float);
		(u+2)->u_outlet = outlet_new(&x->x_obj, &s_float);
		x->x_n=2, argc=0;   }
	else
	{	x->x_n = argc;
		u->u_outlet = outlet_new(&x->x_obj, &s_float); // extra octave
		u++;   }
	
	int i; t_float *fp;
	for (i=argc, fp=x->x_scl; i--; u++, argv++, fp++)
	{	*fp = atom_getfloat(argv);
		floatinlet_new(&x->x_obj, fp);
		u->u_outlet = outlet_new(&x->x_obj, &s_float);   }
	return (x);
}

static void harm_free(t_harm *x) {
	freebytes(x->x_scl, x->x_max * sizeof(t_float));
}

void harm_setup(void) {
	harm_class = class_new(gensym("harm"),
		(t_newmethod)harm_new, (t_method)harm_free,
		sizeof(t_harm), 0,
		A_GIMME, 0);
	
	class_addbang(harm_class, harm_bang);
	class_addlist(harm_class, harm_list);
	class_addfloat(harm_class, harm_float);
	class_addmethod(harm_class, (t_method)harm_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(harm_class, (t_method)harm_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(harm_class, (t_method)harm_scl,
		gensym("scl"), A_GIMME, 0);
	class_addmethod(harm_class, (t_method)harm_do,
		gensym("d"), A_GIMME, 0);
	class_addmethod(harm_class, (t_method)harm_list,
		gensym("l"), A_GIMME, 0);
	class_addmethod(harm_class, (t_method)harm_im,
		gensym("i"), A_GIMME, 0);
	class_addmethod(harm_class, (t_method)harm_ex,
		gensym("x"), A_GIMME, 0);
	class_addmethod(harm_class, (t_method)harm_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_implicit,
		gensym("imp"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_midi,
		gensym("midi"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_all,
		gensym("all"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_octave,
		gensym("oct"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_tet,
		gensym("tet"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_octet,
		gensym("octet"), A_FLOAT, 0);
	class_addmethod(harm_class, (t_method)harm_octet,
		gensym("ot"), A_FLOAT, 0);
}
