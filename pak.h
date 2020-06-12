#include "m_pd.h"
#include <string.h>

typedef struct _pak t_pak;

typedef struct _pak_pxy {
	t_object p_obj;
	t_pak *p_x;
	t_gpointer *p_ptr;   /* inlet's associated pointer */
	int p_i;             /* inlet index */
} t_pak_pxy;

struct _pak {
	t_object x_obj;
	t_pak_pxy **x_ins;   /* proxy inlets */
	t_atomtype *x_type;  /* value types */
	t_gpointer *x_ptr;   /* gobj pointers */
	t_atom *x_vec;       /* input values */
	t_atom *x_outvec;    /* reserved space for output values */
	t_int x_mute;        /* muting mask for printing errors */
	int x_n;             /* number of args */
	int x_nptr;          /* number of pointers */
};

static t_pak *pak_init(t_class *cl, t_class *pxy, int ac, t_atom *av, int r) {
	t_pak *x = (t_pak *)pd_new(cl);
	t_atom defarg[2], *vp, *ap;
	t_gpointer *gp;
	int nptr=0, i;

	if (!ac)
	{	av = defarg;
		ac = 2;
		SETFLOAT(&defarg[0], 0);
		SETFLOAT(&defarg[1], 0);   }

	x->x_n = ac;
	x->x_vec = (t_atom *)getbytes(ac * sizeof(t_atom));
	x->x_outvec = (t_atom *)getbytes(ac * sizeof(t_atom));
	x->x_type = (t_atomtype *)getbytes(ac * sizeof(t_atomtype));
	x->x_ins = (t_pak_pxy **)getbytes((ac-1) * sizeof(t_pak_pxy *));

	for (i=ac, ap=av; i--; ap++)
	{	if (ap->a_type == A_FLOAT) nptr++;
		else if (ap->a_type == A_SYMBOL)
		{	const char *name = ap->a_w.w_symbol->s_name;
			if (strcmp(name, "f") && strcmp(name, s_float.s_name)
			 && strcmp(name, "s") && strcmp(name, s_symbol.s_name))
				nptr++;   }   }
	gp = x->x_ptr = (t_gpointer *)t_getbytes(nptr * sizeof(t_gpointer));
	x->x_nptr = nptr;

	ap = av + (r ? ac-1 : 0);
	r = r ? -1 : 1;
	vp = x->x_vec;
	t_atomtype *tp = x->x_type;
	t_pak_pxy **pp = x->x_ins;
	for (i=0; i < ac; i++, vp++, tp++, ap+=r)
	{	if (ap->a_type == A_FLOAT)
		{	*tp = A_GIMME;
			*vp = *ap;   }
		else if (ap->a_type == A_SYMBOL)
		{	const char *nm = ap->a_w.w_symbol->s_name;
			if (!strcmp(nm, "b"))
			{	*tp = A_GIMME;
				SETSYMBOL(vp, &s_bang);   }
			else if (!strcmp(nm, "f") || !strcmp(nm, s_float.s_name))
			{	*tp = vp->a_type = A_FLOAT;
				vp->a_w.w_float = 0;   }
			else if (!strcmp(nm, "s") || !strcmp(nm, s_symbol.s_name))
			{	*tp = vp->a_type = A_SYMBOL;
				vp->a_w.w_symbol = &s_symbol;   }
			else if (!strcmp(nm, "p") || !strcmp(nm, s_pointer.s_name))
			{	*tp = vp->a_type = A_POINTER;
				vp->a_w.w_gpointer = gp;   }
			else
			{	*tp = A_GIMME;
				if (strcmp(nm, "a") && strcmp(nm, "any"))
					SETSYMBOL(vp, ap->a_w.w_symbol);
				else SETFLOAT(vp, 0);   }   }

		int hasptr = (*tp==A_POINTER || *tp==A_GIMME);
		if (i)
		{	*pp = (t_pak_pxy *)pd_new(pxy);
			(*pp)->p_x = x;
			(*pp)->p_i = i;
			if (hasptr) (*pp)->p_ptr = gp;
			inlet_new(&x->x_obj, (t_pd *)*pp, 0, 0);
			pp++;   }
		if (hasptr)
		{	gpointer_init(gp);
			gp++;   }   }
	outlet_new(&x->x_obj, &s_list);
	return x;
}

static const char *pak_check(t_atomtype type) {
	if (type==A_FLOAT) return s_float.s_name;
	else if (type==A_SYMBOL) return s_symbol.s_name;
	else if (type==A_POINTER) return s_pointer.s_name;
	else return "null";
}

static void pak_error(t_pak *x, int i, const char *t) {
	if (i) pd_error(x, "inlet: expected '%s' but got '%s'",
		pak_check(x->x_type[i]), t);
	else pd_error(x, "pak_%s: wrong type", t);
}

static void pak_bang(t_pak *x) {
	t_atom *vp = x->x_vec;
	t_atomtype *tp = x->x_type;
	t_gpointer *gp = x->x_ptr;
	for (int i=x->x_n; i--; vp++, tp++)
		if (*tp == A_GIMME && vp->a_type != A_POINTER) gp++;
		else if (vp->a_type == A_POINTER)
		{	if (!gpointer_check(gp, 1))
			{	pd_error(x, "%s: stale pointer %d",
					class_getname(*(t_pd *)x), i);
				return;   }
			else gp++;   }

	/* reentrancy protection.  The first time through use the pre-allocated
	x_outvec; if we're reentered we have to allocate new memory. */
	t_atom *outvec;
	int reentered = 0, size = (int)(x->x_n * sizeof(t_atom));
	if (!x->x_outvec)
	{	/* LATER figure out how to deal with reentrancy and pointers... */
		if (x->x_nptr)
			post("%s_bang: warning: reentry with pointers unprotected", 
				class_getname(*(t_pd *)x));
		outvec = t_getbytes(size);
		reentered = 1;   }
	else
	{	outvec = x->x_outvec;
		x->x_outvec = 0;   }
	memcpy(outvec, x->x_vec, size);
	outlet_list(x->x_obj.ob_outlet, &s_list, x->x_n, outvec);
	if (reentered) t_freebytes(outvec, size);
	else x->x_outvec = outvec;
}

static int pak_first(t_pak *x);
static int pak_index(t_pak_pxy *p);

static void pak_pxy_bang(t_pak_pxy *p) {
	t_pak *x = p->p_x;
	int i = pak_index(p);
	t_atomtype type = x->x_type[i];
	if (type == A_SYMBOL || type == A_GIMME)
		SETSYMBOL(x->x_vec+i, &s_bang);
	else if ((x->x_mute>>i)&1) pak_error(x, i, s_bang.s_name);
}

static void pak_p(t_pak *x, t_gpointer *ptr, t_gpointer *gp, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_POINTER || type == A_GIMME)
	{	gpointer_unset(ptr);
		*ptr = *gp;
		if (gp->gp_stub) gp->gp_stub->gs_refcount++;
		SETPOINTER(x->x_vec+i, ptr);
		if (i == pak_first(x)) pak_bang(x);   }
	else if ((x->x_mute>>i) & 1) pak_error(x, i, s_pointer.s_name);
}


static void pak_f(t_pak *x, t_float f, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_FLOAT || type == A_GIMME)
	{	SETFLOAT(x->x_vec+i, f);
		if (i == pak_first(x)) pak_bang(x);   }
	else if ((x->x_mute>>i) & 1) pak_error(x, i, s_float.s_name);
}
static void pak_float(t_pak *x, t_float f) {
	pak_f(x, f, pak_first(x));
}
static void pak_pxy_float(t_pak_pxy *p, t_float f) {
	pak_f(p->p_x, f, pak_index(p));
}


static void pak_s(t_pak *x, t_symbol *s, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_SYMBOL || type == A_GIMME)
	{	SETSYMBOL(x->x_vec+i, s);
		if (i == pak_first(x)) pak_bang(x);   }
	else if ((x->x_mute>>i) & 1) pak_error(x, i, s_symbol.s_name);
}
static void pak_symbol(t_pak *x, t_symbol *s) {
	pak_s(x, s, pak_first(x));
}
static void pak_pxy_symbol(t_pak_pxy *p, t_symbol *s) {
	pak_s(p->p_x, s, pak_index(p));
}


static int pak_set(t_pak *x, t_atom *v, t_gpointer *p, t_atom a, t_atomtype t) {
	if (t==a.a_type || t==A_GIMME)
	{	if (a.a_type == A_POINTER)
		{	t_gpointer *gp = a.a_w.w_gpointer;
			gpointer_unset(p);
			*p = *gp;
			if (gp->gp_stub) gp->gp_stub->gs_refcount++;
			SETPOINTER(v, p);   }
		else *v = a;
		return 1;   }
	else return 0;
}

static int pak_l(t_pak *x, t_symbol *s, int ac, t_atom *av, int i);
static void pak_list(t_pak *x, t_symbol *s, int ac, t_atom *av) {
	if (pak_l(x, 0, ac, av, pak_first(x))) pak_bang(x);
}
static void pak_pxy_list(t_pak_pxy *p, t_symbol *s, int ac, t_atom *av) {
	pak_l(p->p_x, s, ac, av, pak_index(p));
}


static int pak_a(t_pak *x, t_symbol *s, int ac, t_atom *av, int j) {
	t_atom *av2 = (t_atom *)getbytes((ac+1) * sizeof(t_atom));
	for (int i=0; i < ac; i++) av2[i+1] = av[i];
	SETSYMBOL(av2, s);
	int result = pak_l(x, 0, ac+1, av2, j);
	freebytes(av2, (ac+1) * sizeof(t_atom));
	return result;
}
static void pak_anything(t_pak *x, t_symbol *s, int ac, t_atom *av) {
	if (pak_a(x, s, ac, av, pak_first(x))) pak_bang(x);
}
static void pak_pxy_anything(t_pak_pxy *p, t_symbol *s, int ac, t_atom *av) {
	pak_a(p->p_x, s, ac, av, pak_index(p));
}


static void pak_mute(t_pak *x, t_floatarg f) {
	x->x_mute = ~(int)f;
}

static void pak_free(t_pak *x) {
	int i, n=x->x_n, pn=n-1;

	t_gpointer *gp;
	for (gp = x->x_ptr, i = (int)x->x_nptr; i--; gp++)
		gpointer_unset(gp);

	t_pak_pxy **pp;
	for (pp=x->x_ins, i=pn; i--; pp++)
		if (*pp) pd_free((t_pd *)*pp);

	freebytes(x->x_vec, n * sizeof(*x->x_vec));
	freebytes(x->x_outvec, n * sizeof(*x->x_outvec));
	freebytes(x->x_type, n * sizeof(*x->x_type));
	freebytes(x->x_ins, pn * sizeof(t_pak_pxy *));
	freebytes(x->x_ptr, x->x_nptr * sizeof(*x->x_ptr));
}
