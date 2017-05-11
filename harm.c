#include "m_pd.h"
#include <stdlib.h> // atof
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

/* -------------------------- harm -------------------------- */

static t_class *harm_class;

typedef struct _harm {
	t_object x_obj;
	int x_n, x_in, x_p,		/* count notes, inlets, pointer */
		x_midi, x_all,		/* midi-note and all-note toggles */
		x_imp;				/* implicit scale size toggle */
	double x_rt, x_st;		/* root tone, semi-tone */
	t_float x_oct,			/* # of notes between octaves */
		x_ref, x_tet,		/* ref-pitch, # of tones */
		*x_scl;				/* scale intervals */
	t_outlet **x_outs;		/* outlets */
} t_harm;

#define MAX 1024

static void harm_ptr(t_harm *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->x_p);
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

static void harm_resize(t_harm *x, int d) {
	int n=2, i;
	while (n<MAX && n<d) n*=2;
	x->x_scl = (t_float *)resizebytes(x->x_scl,
		x->x_p * sizeof(t_float), n * sizeof(t_float));
	x->x_p = n;
	t_float *fp = x->x_scl;
	t_inlet *ip = ((t_object *)x)->ob_inlet;
	for (i=x->x_in; i--; fp++, ip=ip->i_next)
		ip->i_floatslot = fp;
}

int limtr(t_harm *x, int n, int i) {
	i=!i; // index/size toggle
	int mx=MAX+i; n+=i;
	if (n<1) n=1; else if (n>mx) n=mx;
	if (x->x_p<n) harm_resize(x,n);
	return (n-i);
}

static void harm_set(t_harm *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = limtr(x, av->a_w.w_float, 0);
		t_atomtype typ = (av+1)->a_type;
		if (typ == A_FLOAT) x->x_scl[i] = (av+1)->a_w.w_float;
		else if (typ == A_SYMBOL) harm_operate(x->x_scl+i, av+1);   }
	else pd_error(x, "harm_set: bad arguments");
}

static void harm_imp(t_harm *x, int ac, int offset) {
	int n = x->x_n = ac+offset;
	if (x->x_p<n) harm_resize(x,n);
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

static void harm_doremi(t_harm *x, t_symbol *s, int ac, t_atom *av) {
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
	x->x_n = limtr(x,n,1);
}

static void harm_implicit(t_harm *x, t_floatarg f) {
	x->x_imp = f;
}

static void harm_midi(t_harm *x, t_floatarg f) {
	x->x_midi = f;
}

static void harm_all(t_harm *x, t_floatarg f) {
	x->x_all = f;
}

static void harm_octave(t_harm *x, t_floatarg f) {
	x->x_oct = f;
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

double getnote(t_harm *x, int d) {
	int n=x->x_n, p=d%n, b=p<0,
	q = d/n-b;
	d = b*n+p;
	t_float root = x->x_scl[0],
		step = d ? x->x_scl[d] : 0;
	return (x->x_oct*q + root+step);
}

static void harm_float(t_harm *x, t_float f) {
	int n=x->x_in, d=f;
	double note = getnote(x, d);
	if (f!=d)
	{	int b = f<0?-1:1;
		double next = getnote(x, d+b);
		note += b*(f-d) * (next-note);   }
	int p=d%n; if (p<0) p+=n;
	d = (d&&!p)?n:p;
	outlet_float(x->x_outs[d], x->x_midi ?
		note : ntof(note, x->x_rt, x->x_st));
}

static void harm_bang(t_harm *x) {
	int n=x->x_n, i=x->x_in+1;
	i = x->x_all ? i : (n>i?i:n);
	t_outlet **op;
	for (op=x->x_outs+i; op--, i--;)
	{	double note = getnote(x, i);
		outlet_float(*op, x->x_midi ?
			note : ntof(note, x->x_rt, x->x_st));   }
}

static void *harm_new(t_symbol *s, int ac, t_atom *av) {
	t_harm *x = (t_harm *)pd_new(harm_class);
	
	int n = x->x_n = x->x_in = x->x_p = ac<2?2:ac, i=0;
	x->x_scl = (t_float *)getbytes(n * sizeof(t_float));
	x->x_outs = (t_outlet **)getbytes((n+1) * sizeof(t_outlet *));
	t_float *fp = x->x_scl;
	t_outlet **op = x->x_outs;
	fp[0]=69, fp[1]=7;
	op[0] = outlet_new(&x->x_obj, &s_float);
	for (; op++,n--; fp++,i++)
	{	*op = outlet_new(&x->x_obj, &s_float);
		floatinlet_new(&x->x_obj, fp);
		if (i<ac) *fp = atom_getfloat(av++);   }
	
	double ref=x->x_ref=440, tet=x->x_tet=12;
	x->x_rt = ref * pow(2,-69/tet);
	x->x_st = log(2) / tet;
	x->x_oct = tet;
	x->x_imp = 1;
	return (x);
}

static void harm_free(t_harm *x) {
	freebytes(x->x_scl, x->x_p * sizeof(t_float));
	freebytes(x->x_outs, (x->x_in+1) * sizeof(t_outlet *));
}

void harm_setup(void) {
	harm_class = class_new(gensym("harm"),
		(t_newmethod)harm_new, (t_method)harm_free,
		sizeof(t_harm), 0,
		A_GIMME, 0);
	
	class_addbang(harm_class, harm_bang);
	class_addfloat(harm_class, harm_float);
	class_addlist(harm_class, harm_list);
	class_addmethod(harm_class, (t_method)harm_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(harm_class, (t_method)harm_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(harm_class, (t_method)harm_set,
		gensym("set"), A_GIMME, 0);
	class_addmethod(harm_class, (t_method)harm_doremi,
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
