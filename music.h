#include "m_pd.h"
#include <stdlib.h> // strtof
#include <math.h>   // exp, pow, log

#define NMAX 1024

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	t_float *i_floatslot;
};

typedef struct _music {
	t_object obj;
	int n;            /* current scale size */
	int in;           /* # of inlets */
	int p;            /* pointer size */
	double rt;        /* root tone */
	double st;        /* semi-tone */
	t_float oct;      /* # of semitone steps per octave */
	t_float tet;      /* # of tones within an octave */
	t_float ref;      /* reference pitch */
	t_float *scale;   /* musical scale (root + intervals) */
	unsigned expl:1;  /* explicit scale size toggle */
} t_music;

static t_float ntof(t_float f, double root, double semi) {
	return (root * exp(semi*f));
}

static void music_ptr(t_music *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->p);
}

static void music_peek(t_music *x, t_symbol *s) {
	t_float *fp = x->scale;
	if (*s->s_name) startpost("%s: ", s->s_name);
	for (int i=x->n; i--; fp++) startpost("%g ", *fp);
	endpost();
}

static void music_operate(t_float *fp, t_atom *av) {
	const char *cp = av->a_w.w_symbol->s_name;
	if (cp[1])
	{	t_float f = cp[2] ? strtof(cp+2, NULL) : 1;
			 if (cp[1]=='+') *fp += f;
		else if (cp[1]=='-') *fp -= f;
		else if (cp[1]=='*') *fp *= f;
		else if (cp[1]=='/') *fp /= f;   }
}

static int music_resize(t_music *x, int n, int l) {
	n += l;
	if (n<1) n=1; else if (n>NMAX) n=NMAX;
	if (x->p < n)
	{	int d=2;
		while (d<NMAX && d<n) d*=2;
		x->scale = (t_float *)resizebytes(x->scale,
			x->p * sizeof(t_float), d * sizeof(t_float));
		x->p = d;
		t_float *fp = x->scale;
		t_inlet *ip = ((t_object *)x)->ob_inlet;
		for (int i=x->in; i--; fp++, ip=ip->i_next)
			ip->i_floatslot = fp;   }
	return (n-l);
}

static void music_at(t_music *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = music_resize(x, av->a_w.w_float, 1);
		t_atomtype typ = (av+1)->a_type;
		if (typ == A_FLOAT) x->scale[i] = (av+1)->a_w.w_float;
		else if (typ == A_SYMBOL) music_operate(x->scale+i, av+1);   }
	else pd_error(x, "music_at: bad arguments");
}

static void music_size(t_music *x, t_floatarg n) {
	x->n = music_resize(x, n, 0);
}

static void music_scale(t_music *x, int ac, t_atom *av, int offset) {
	for (t_float *fp=x->scale+offset; ac--; av++, fp++)
	{	if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL) music_operate(fp, av);   }
}

static void music_l(t_music *x, int ac, t_atom *av, int offset) {
	if (!x->expl) music_size(x, ac+offset);
	music_scale(x, ac, av, offset);
}

static void music_doremi(t_music *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) music_l(x, ac, av, 1);
}

static void music_list(t_music *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) music_l(x, ac, av, 0);
}

static void music_i(t_music *x, t_symbol *s, int ac, t_atom *av) {
	if (ac)
	{	music_size(x, ac);
		music_scale(x, ac, av, 0);   }
}

static void music_x(t_music *x, t_symbol *s, int ac, t_atom *av) {
	if (ac) music_scale(x, ac, av, 0);
}

static void music_expl(t_music *x, t_floatarg f) {
	x->expl = f;
}

static void music_octave(t_music *x, t_floatarg f) {
	x->oct = f;
}

static double music_root(t_music *x) {
	return (pow(2, -69/x->tet) * x->ref);
}

static double music_semi(t_music *x) {
	return (log(2) / x->tet);
}

static void music_ref(t_music *x, t_floatarg f) {
	x->ref = f;
	x->rt = music_root(x);
}

static void music_tet(t_music *x, t_floatarg f) {
	x->tet = f;
	x->rt = music_root(x);
	x->st = music_semi(x);
}

static void music_octet(t_music *x, t_floatarg f) {
	music_octave(x, f);
	music_tet(x, f);
}

static void music_free(t_music *x) {
	freebytes(x->scale, x->p * sizeof(t_float));
}

static t_music *music_new(t_class *mclass) {
	t_music *x = (t_music *)pd_new(mclass);

	double ref=x->ref=440, tet=x->tet=12;
	x->rt = music_root(x);
	x->st = music_semi(x);
	x->oct = tet;
	x->expl = 0;

	return x;
}
