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

/* -------------------------- chrd -------------------------- */

static t_class *chrd_class;

typedef struct _chrd {
	t_object x_obj;
	int x_n, x_in, x_p,		/* count notes, inlets, pointer */
		x_midi, x_all,		/* midi-note and all-note toggles */
		x_exp;				/* explicit scale size toggle */
	double x_rt, x_st;		/* root tone, semi-tone */
	t_float x_oct,			/* # of notes between octaves */
		x_ref, x_tet,		/* ref-pitch, # of tones */
		*x_scl;				/* scale intervals */
	t_outlet **x_outs;		/* outlets */
} t_chrd;

#define MAX 1024

static void chrd_ptr(t_chrd *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->x_p);
}

static void chrd_peek(t_chrd *x, t_symbol *s) {
	int i;
	t_float *fp = x->x_scl;
	if (*s->s_name) startpost("%s: ", s->s_name);
	for (i=x->x_n; i--; fp++) startpost("%g ", *fp);
	endpost();
}

static void chrd_operate(t_float *fp, t_atom *av) {
	char *cp = av->a_w.w_symbol->s_name;
	if (cp[1])
	{	t_float f = cp[2] ? atof(cp+2) : 1;
			 if (cp[1]=='+') *fp += f;
		else if (cp[1]=='-') *fp -= f;
		else if (cp[1]=='*') *fp *= f;
		else if (cp[1]=='/') *fp /= f;   }
}

static void chrd_resize(t_chrd *x, int d) {
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

int limtr(t_chrd *x, int n, int l) {
	n+=l;
	if (n<1) n=1; else if (n>MAX) n=MAX;
	if (x->x_p<n) chrd_resize(x,n);
	return (n-l);
}

static void chrd_set(t_chrd *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = limtr(x, av->a_w.w_float, 1);
		t_atomtype typ = (av+1)->a_type;
		if (typ == A_FLOAT) x->x_scl[i] = (av+1)->a_w.w_float;
		else if (typ == A_SYMBOL) chrd_operate(x->x_scl+i, av+1);   }
	else pd_error(x, "chrd_set: bad arguments");
}

static void chrd_imp(t_chrd *x, int ac, int offset) {
	int n = x->x_n = ac+offset;
	if (x->x_p<n) chrd_resize(x,n);
}

static void chrd_scale(t_chrd *x, int ac, t_atom *av, int offset) {
	t_float *fp = x->x_scl+offset;
	for (; ac--; av++, fp++)
	{	if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL) chrd_operate(fp, av);   }
}

static void chrd_scimp(t_chrd *x, int ac, t_atom *av, int offset) {
	if (!x->x_exp) chrd_imp(x, ac, offset);
	chrd_scale(x, ac, av, offset);
}

static void chrd_doremi(t_chrd *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) chrd_scimp(x, ac, av, 1);
}

static void chrd_list(t_chrd *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) chrd_scimp(x, ac, av, 0);
}

static void chrd_im(t_chrd *x, t_symbol *s, int ac, t_atom *av) {
	chrd_imp(x, ac, 0);
	if (ac) chrd_scale(x, ac, av, 0);
}

static void chrd_ex(t_chrd *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) chrd_scale(x, ac, av, 0);
}

static void chrd_size(t_chrd *x, t_floatarg n) {
	x->x_n = limtr(x,n,0);
}

static void chrd_explicit(t_chrd *x, t_floatarg f) {
	x->x_exp = f;
}

static void chrd_midi(t_chrd *x, t_floatarg f) {
	x->x_midi = f;
}

static void chrd_all(t_chrd *x, t_floatarg f) {
	x->x_all = f;
}

static void chrd_octave(t_chrd *x, t_floatarg f) {
	x->x_oct = f;
}

static void chrd_ref(t_chrd *x, t_floatarg f) {
	x->x_rt = (x->x_ref=f) * pow(2,-69/x->x_tet);
}

static void chrd_tet(t_chrd *x, t_floatarg f) {
	x->x_rt = x->x_ref * pow(2,-69/f);
	x->x_st = log(2) / (x->x_tet=f);
}

static void chrd_octet(t_chrd *x, t_floatarg f) {
	chrd_octave(x,f);   chrd_tet(x,f);
}

double getnote(t_chrd *x, int d) {
	int n=x->x_n, p=d%n, b=p<0,
	q = d/n-b;
	d = b*n+p;
	t_float root = x->x_scl[0],
		step = d ? x->x_scl[d] : 0;
	return (x->x_oct*q + root+step);
}

static void chrd_float(t_chrd *x, t_float f) {
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

static void chrd_bang(t_chrd *x) {
	int n=x->x_n, i=x->x_in+1;
	i = x->x_all ? i : (n>i?i:n);
	t_outlet **op;
	for (op=x->x_outs+i; op--, i--;)
	{	double note = getnote(x, i);
		outlet_float(*op, x->x_midi ?
			note : ntof(note, x->x_rt, x->x_st));   }
}

static void *chrd_new(t_symbol *s, int ac, t_atom *av) {
	t_chrd *x = (t_chrd *)pd_new(chrd_class);
	
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
	x->x_exp = 0;
	return (x);
}

static void chrd_free(t_chrd *x) {
	freebytes(x->x_scl, x->x_p * sizeof(t_float));
	freebytes(x->x_outs, (x->x_in+1) * sizeof(t_outlet *));
}

void chrd_setup(void) {
	chrd_class = class_new(gensym("chrd"),
		(t_newmethod)chrd_new, (t_method)chrd_free,
		sizeof(t_chrd), 0,
		A_GIMME, 0);
	class_addcreator((t_newmethod)chrd_new,
		gensym("chrd"), A_GIMME, 0);
	class_addbang(chrd_class, chrd_bang);
	class_addfloat(chrd_class, chrd_float);
	class_addlist(chrd_class, chrd_list);
	class_addmethod(chrd_class, (t_method)chrd_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(chrd_class, (t_method)chrd_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(chrd_class, (t_method)chrd_set,
		gensym("set"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)chrd_doremi,
		gensym("d"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)chrd_list,
		gensym("l"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)chrd_im,
		gensym("i"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)chrd_ex,
		gensym("x"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)chrd_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_explicit,
		gensym("exp"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_midi,
		gensym("midi"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_all,
		gensym("all"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_octave,
		gensym("oct"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_tet,
		gensym("tet"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_octet,
		gensym("octet"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_octet,
		gensym("ot"), A_FLOAT, 0);
}
