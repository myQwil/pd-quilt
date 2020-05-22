#include "m_pd.h"
#include <string.h>

/* -------------------------- pak ------------------------------ */

static t_class *pak_class;
static t_class *pak_proxy;

typedef struct _pak t_pak;

typedef struct _pak_pxy {
	t_object p_obj;
	t_int p_i;                  /* inlet index */
	t_gpointer *p_ptr;          /* reference to a pointer */
	t_pak *p_x;
} t_pak_pxy;

struct _pak {
	t_object x_obj;
	t_int x_n, x_nptr, x_mute;  /* number of args, number of pointers, mute */
	t_atom *x_vec, *x_outvec;   /* input values, space for output values */
	t_atomtype *x_type;         /* value types */
	t_gpointer *x_ptr;          /* the pointers */
	t_pak_pxy **x_ins;          /* proxy inlets */
};

static void *pak_new(t_symbol *s, int argc, t_atom *argv) {
	t_pak *x = (t_pak *)pd_new(pak_class);
	t_atom defarg[2], *vp, *ap;
	t_gpointer *gp;

	int nptr = 0;
	int i;
	if (!argc)
	{	argv = defarg;
		argc = 2;
		SETFLOAT(&defarg[0], 0);
		SETFLOAT(&defarg[1], 0);   }

	x->x_n = argc;
	x->x_vec = (t_atom *)getbytes(argc * sizeof(*x->x_vec));
	x->x_outvec = (t_atom *)getbytes(argc * sizeof(*x->x_outvec));
	x->x_type = (t_atomtype *)getbytes(argc * sizeof(*x->x_type));
	x->x_ins = (t_pak_pxy **)getbytes((argc-1) * sizeof(t_pak_pxy *));

	for (i=argc, ap=argv; i--; ap++)
	{	if (ap->a_type == A_FLOAT) nptr++;
		else if (ap->a_type == A_SYMBOL)
		{	const char *name = ap->a_w.w_symbol->s_name;
			if (strcmp(name, "f") && strcmp(name, "float")
			 && strcmp(name, "s") && strcmp(name, "symbol")) nptr++;   }   }
	gp = x->x_ptr = (t_gpointer *)t_getbytes(nptr * sizeof (*gp));
	x->x_nptr = nptr;

	t_atomtype *tp = x->x_type;
	t_pak_pxy **pp = x->x_ins;
	for (i=0, ap=argv, vp=x->x_vec; i<argc; i++, ap++, vp++, tp++)
	{	if (ap->a_type == A_FLOAT)
		{	*tp = A_GIMME;
			*vp = *ap;   }
		else if (ap->a_type == A_SYMBOL)
		{	const char *nm = ap->a_w.w_symbol->s_name;
			if (!strcmp(nm, "b"))
			{	*tp = A_GIMME;
				SETSYMBOL(vp, &s_bang);   }
			else if (!strcmp(nm, "f") || !strcmp(nm, "float"))
			{	*tp = vp->a_type = A_FLOAT;
				vp->a_w.w_float = 0;   }
			else if (!strcmp(nm, "s") || !strcmp(nm, "symbol"))
			{	*tp = vp->a_type = A_SYMBOL;
				vp->a_w.w_symbol = &s_symbol;   }
			else if (!strcmp(nm, "p") || !strcmp(nm, "pointer"))
			{	*tp = vp->a_type = A_POINTER;
				vp->a_w.w_gpointer = gp;   }
			else
			{	*tp = A_GIMME;
				if (strcmp(nm, "a") && strcmp(nm, "any"))
					SETSYMBOL(vp, ap->a_w.w_symbol);
				else SETFLOAT(vp, 0);   }   }

		int hasptr = (*tp==A_POINTER || *tp==A_GIMME);
		if (i)
		{	*pp = (t_pak_pxy *)pd_new(pak_proxy);
			(*pp)->p_x = x;
			(*pp)->p_i = i;
			if (hasptr) (*pp)->p_ptr = gp;
			inlet_new(&x->x_obj, (t_pd *)*pp, 0, 0);
			pp++;   }
		if (hasptr)
		{	gpointer_init(gp);
			gp++;   }   }
	outlet_new(&x->x_obj, &s_list);
	return (x);
}

static const char *pak_check(t_atomtype type) {
	if (type==A_FLOAT) return "float";
	else if (type==A_SYMBOL) return "symbol";
	else if (type==A_POINTER) return "pointer";
	else return "null";
}

static void pak_error(t_pak *x, int i, const char *t) {
	if (i) pd_error(x, "inlet: expected '%s' but got '%s'",
		pak_check(x->x_type[i]), t);
	else pd_error(x, "pak_%s: wrong type", t);
}

static void pak_bang(t_pak *x) {
	int i;
	t_atom *vp = x->x_vec;
	t_atomtype *tp = x->x_type;
	t_gpointer *gp = x->x_ptr;
	for (i = (int)x->x_n; i--; vp++, tp++)
		if (*tp == A_GIMME && vp->a_type != A_POINTER) gp++;
		else if (vp->a_type == A_POINTER)
		{	if (!gpointer_check(gp, 1))
			{	pd_error(x, "pak: stale pointer %d", i);
				return;   }
			else gp++;   }

	/* reentrancy protection.  The first time through use the pre-allocated
	x_outvec; if we're reentered we have to allocate new memory. */
	t_atom *outvec;
	int reentered = 0, size = (int)(x->x_n * sizeof(t_atom));
	if (!x->x_outvec)
	{	/* LATER figure out how to deal with reentrancy and pointers... */
		if (x->x_nptr)
			post("pak_bang: warning: reentry with pointers unprotected");
		outvec = t_getbytes(size);
		reentered = 1;   }
	else
	{	outvec = x->x_outvec;
		x->x_outvec = 0;   }
	memcpy(outvec, x->x_vec, size);
	outlet_list(x->x_obj.ob_outlet, &s_list, (int)x->x_n, outvec);
	if (reentered) t_freebytes(outvec, size);
	else x->x_outvec = outvec;
}

static void pak_pxy_bang(t_pak_pxy *p) {
	int i = p->p_i;
	t_pak *x = p->p_x;
	t_atomtype type = x->x_type[i];
	if (type == A_SYMBOL || type == A_GIMME)
		SETSYMBOL(x->x_vec+i, gensym("bang"));
	else if ((x->x_mute>>i)&1) pd_error(x, "inlet: expected '%s' but got '%s'",
		pak_check(type), "bang");
}


static void pak_p(t_pak *x, t_gpointer *ptr, t_gpointer *gp, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_POINTER || type == A_GIMME)
	{	gpointer_unset(ptr);
		*ptr = *gp;
		if (gp->gp_stub) gp->gp_stub->gs_refcount++;
		SETPOINTER(x->x_vec+i, ptr);
		if (!i) pak_bang(x);   }
	else if ((x->x_mute>>i) & 1) pak_error(x, i, "pointer");
}
static void pak_pointer(t_pak *x, t_gpointer *gp) {
	pak_p(x, x->x_ptr, gp, 0);
}
static void pak_pxy_pointer(t_pak_pxy *p, t_gpointer *gp) {
	pak_p(p->p_x, p->p_ptr, gp, p->p_i);
}


static void pak_f(t_pak *x, t_float f, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_FLOAT || type == A_GIMME)
	{	SETFLOAT(x->x_vec+i, f);
		if (!i) pak_bang(x);   }
	else if ((x->x_mute>>i) & 1) pak_error(x, i, "float");
}
static void pak_float(t_pak *x, t_float f) {
	pak_f(x, f, 0);
}
static void pak_pxy_float(t_pak_pxy *p, t_float f) {
	pak_f(p->p_x, f, p->p_i);
}


static void pak_s(t_pak *x, t_symbol *s, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_SYMBOL || type == A_GIMME)
	{	SETSYMBOL(x->x_vec+i, s);
		if (!i) pak_bang(x);   }
	else if ((x->x_mute>>i) & 1) pak_error(x, i, "symbol");
}
static void pak_symbol(t_pak *x, t_symbol *s) {
	pak_s(x, s, 0);
}
static void pak_pxy_symbol(t_pak_pxy *p, t_symbol *s) {
	pak_s(p->p_x, s, p->p_i);
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

static int pak_l(t_pak *x, t_symbol *s, int ac, t_atom *av, int i) {
	int ins = x->x_n - i, result = 1;
	t_atom *vp = x->x_vec + i;
	t_atomtype *tp = x->x_type + i;
	t_pak_pxy **pp = x->x_ins + (i-1);
	for (; ac-- && ins--; i++, vp++, tp++, pp++, av++)
	{	if (av->a_type==A_SYMBOL && !strcmp(av->a_w.w_symbol->s_name, "."))
			continue;
		t_gpointer *ptr = i ? (*pp)->p_ptr : x->x_ptr;
		if (!pak_set(x, vp, ptr, *av, *tp) && ((x->x_mute>>i) & 1))
		{	if (i) pd_error(x, "inlet: expected '%s' but got '%s'",
				pak_check(*tp), pak_check(av->a_type));
			else
			{	pd_error(x, "pak_%s: wrong type", pak_check(av->a_type));
				result = 0;   }   }   }
	return result;
}
static void pak_list(t_pak *x, t_symbol *s, int ac, t_atom *av) {
	if (pak_l(x, 0, ac, av, 0)) pak_bang(x);
}
static void pak_pxy_list(t_pak_pxy *p, t_symbol *s, int ac, t_atom *av) {
	pak_l(p->p_x, s, ac, av, p->p_i);
}


static int pak_a(t_pak *x, t_symbol *s, int ac, t_atom *av, int j) {
	t_atom *av2 = (t_atom *)getbytes((ac+1) * sizeof(t_atom));
	int i;
	for (i = 0; i < ac; i++) av2[i+1] = av[i];
	SETSYMBOL(av2, s);
	int result = pak_l(x, 0, ac+1, av2, j);
	freebytes(av2, (ac+1) * sizeof(t_atom));
	return result;
}
static void pak_anything(t_pak *x, t_symbol *s, int ac, t_atom *av) {
	if (pak_a(x, s, ac, av, 0)) pak_bang(x);
}
static void pak_pxy_anything(t_pak_pxy *p, t_symbol *s, int ac, t_atom *av) {
	pak_a(p->p_x, s, ac, av, p->p_i);
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

void pak_setup(void) {
	pak_class = class_new(gensym("pak"),
		(t_newmethod)pak_new, (t_method)pak_free,
		sizeof(t_pak), 0,
		A_GIMME, 0);
	class_addbang(pak_class, pak_bang);
	class_addpointer(pak_class, pak_pointer);
	class_addfloat(pak_class, pak_float);
	class_addsymbol(pak_class, pak_symbol);
	class_addlist(pak_class, pak_list);
	class_addanything(pak_class, pak_anything);
	class_addmethod(pak_class, (t_method)pak_mute,
		gensym("mute"), A_FLOAT, 0);

	pak_proxy = class_new(gensym("_pak_pxy"), 0, 0,
		sizeof(t_pak_pxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(pak_proxy, pak_pxy_bang);
	class_addpointer(pak_proxy, pak_pxy_pointer);
	class_addfloat(pak_proxy, pak_pxy_float);
	class_addsymbol(pak_proxy, pak_pxy_symbol);
	class_addlist(pak_proxy, pak_pxy_list);
	class_addanything(pak_proxy, pak_pxy_anything);
}
