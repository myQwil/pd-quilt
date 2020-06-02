#include "m_pd.h"
#include <string.h>

/* -------------------------- reverse pak ------------------------------ */

static t_class *rpak_class;
static t_class *rpak_proxy;

typedef struct _rpak t_rpak;

typedef struct _rpak_pxy {
	t_object p_obj;
	t_int p_i;                  /* inlet index */
	t_gpointer *p_ptr;          /* reference to a pointer */
	t_rpak *p_x;
} t_rpak_pxy;

struct _rpak {
	t_object x_obj;
	t_int x_n, x_nptr, x_mute;  /* number of args, number of pointers, mute */
	t_atom *x_vec, *x_outvec;   /* input values, space for output values */
	t_atomtype *x_type;         /* value types */
	t_gpointer *x_ptr;          /* the pointers */
	t_rpak_pxy **x_ins;         /* proxy inlets */
};

static void *rpak_new(t_symbol *s, int argc, t_atom *argv) {
	t_rpak *x = (t_rpak *)pd_new(rpak_class);
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
	x->x_ins = (t_rpak_pxy **)getbytes((argc-1) * sizeof(t_rpak_pxy *));

	for (i=argc, ap=argv; i--; ap++)
	{	if (ap->a_type == A_FLOAT) nptr++;
		else if (ap->a_type == A_SYMBOL)
		{	const char *name = ap->a_w.w_symbol->s_name;
			if (strcmp(name, "f") && strcmp(name, "float")
			 && strcmp(name, "s") && strcmp(name, "symbol")) nptr++;   }   }
	gp = x->x_ptr = (t_gpointer *)t_getbytes(nptr * sizeof (*gp));
	x->x_nptr = nptr;

	t_atomtype *tp = x->x_type;
	t_rpak_pxy **pp = x->x_ins;
	for (i=0, ap=argv+argc, vp=x->x_vec; ap--, i<argc; i++, vp++, tp++)
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
		{	*pp = (t_rpak_pxy *)pd_new(rpak_proxy);
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

static const char *rpak_check(t_atomtype type) {
	if (type==A_FLOAT) return "float";
	else if (type==A_SYMBOL) return "symbol";
	else if (type==A_POINTER) return "pointer";
	else return "null";
}

static void rpak_error(t_rpak *x, int i, const char *t) {
	if (i) pd_error(x, "inlet: expected '%s' but got '%s'",
		rpak_check(x->x_type[i]), t);
	else pd_error(x, "@pak_%s: wrong type", t);
}

static void rpak_bang(t_rpak *x) {
	int i;
	t_atom *vp = x->x_vec;
	t_atomtype *tp = x->x_type;
	t_gpointer *gp = x->x_ptr;
	for (i = (int)x->x_n; i--; vp++, tp++)
		if (*tp == A_GIMME && vp->a_type != A_POINTER) gp++;
		else if (vp->a_type == A_POINTER)
		{	if (!gpointer_check(gp, 1))
			{	pd_error(x, "@pak: stale pointer %d", i);
				return;   }
			else gp++;   }

	/* reentrancy protection.  The first time through use the pre-allocated
	x_outvec; if we're reentered we have to allocate new memory. */
	t_atom *outvec;
	int reentered = 0, size = (int)(x->x_n * sizeof(t_atom));
	if (!x->x_outvec)
	{	/* LATER figure out how to deal with reentrancy and pointers... */
		if (x->x_nptr)
			post("@pak_bang: warning: reentry with pointers unprotected");
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

static void rpak_pxy_bang(t_rpak_pxy *p) {
	t_rpak *x = p->p_x;
	int i = x->x_n - p->p_i - 1;
	t_atomtype type = x->x_type[i];
	if (type == A_SYMBOL || type == A_GIMME)
		SETSYMBOL(x->x_vec+i, gensym("bang"));
	else if ((x->x_mute>>i)&1) pd_error(x, "inlet: expected '%s' but got '%s'",
		rpak_check(type), "bang");
}


static void rpak_p(t_rpak *x, t_gpointer *ptr, t_gpointer *gp, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_POINTER || type == A_GIMME)
	{	gpointer_unset(ptr);
		*ptr = *gp;
		if (gp->gp_stub) gp->gp_stub->gs_refcount++;
		SETPOINTER(x->x_vec+i, ptr);
		if (i >= x->x_n-1) rpak_bang(x);   }
	else if ((x->x_mute>>i) & 1) rpak_error(x, i, "pointer");
}
static void rpak_pointer(t_rpak *x, t_gpointer *gp) {
	int i = x->x_n-1;
	t_gpointer *ptr = (i) ? x->x_ins[i-1]->p_ptr : x->x_ptr;
	rpak_p(x, ptr, gp, i);
}
static void rpak_pxy_pointer(t_rpak_pxy *p, t_gpointer *gp) {
	t_rpak *x = p->p_x;
	int i = x->x_n-1 - p->p_i;
	t_gpointer *ptr = (i) ? x->x_ins[i-1]->p_ptr : x->x_ptr;
	rpak_p(x, ptr, gp, i);
}


static void rpak_f(t_rpak *x, t_float f, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_FLOAT || type == A_GIMME)
	{	SETFLOAT(x->x_vec+i, f);
		if (i >= x->x_n-1) rpak_bang(x);   }
	else if ((x->x_mute>>i) & 1) rpak_error(x, i, "float");
}
static void rpak_float(t_rpak *x, t_float f) {
	rpak_f(x, f, x->x_n-1);
}
static void rpak_pxy_float(t_rpak_pxy *p, t_float f) {
	rpak_f(p->p_x, f, p->p_x->x_n-1 - p->p_i);
}


static void rpak_s(t_rpak *x, t_symbol *s, int i) {
	t_atomtype type = x->x_type[i];
	if (type == A_SYMBOL || type == A_GIMME)
	{	SETSYMBOL(x->x_vec+i, s);
		if (i >= x->x_n-1) rpak_bang(x);   }
	else if ((x->x_mute>>i) & 1) rpak_error(x, i, "symbol");
}
static void rpak_symbol(t_rpak *x, t_symbol *s) {
	rpak_s(x, s, x->x_n-1);
}
static void rpak_pxy_symbol(t_rpak_pxy *p, t_symbol *s) {
	rpak_s(p->p_x, s, p->p_x->x_n-1 - p->p_i);
}


static int rpak_set(t_rpak *x, t_atom *v, t_gpointer *p, t_atom a, t_atomtype t) {
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

static int rpak_l(t_rpak *x, t_symbol *s, int ac, t_atom *av, int i) {
	int result = 1;
	t_atom *vp = x->x_vec + i;
	t_atomtype *tp = x->x_type + i;
	t_rpak_pxy **pp = x->x_ins + (i-1);
	for (i++; ac-- && i--; vp--, tp--, pp--, av++)
	{	if (av->a_type==A_SYMBOL && !strcmp(av->a_w.w_symbol->s_name, "."))
			continue;
		t_gpointer *ptr = i ? (*pp)->p_ptr : x->x_ptr;
		if (!rpak_set(x, vp, ptr, *av, *tp) && ((x->x_mute>>i) & 1))
		{	if (i >= x->x_n-1)
			{	pd_error(x, "@pak_%s: wrong type", rpak_check(av->a_type));
				result = 0;   }
			else pd_error(x, "inlet: expected '%s' but got '%s'",
				rpak_check(*tp), rpak_check(av->a_type));   }   }
	return result;
}
static void rpak_list(t_rpak *x, t_symbol *s, int ac, t_atom *av) {
	if (rpak_l(x, 0, ac, av, x->x_n-1)) rpak_bang(x);
}
static void rpak_pxy_list(t_rpak_pxy *p, t_symbol *s, int ac, t_atom *av) {
	rpak_l(p->p_x, s, ac, av, p->p_x->x_n-1 - p->p_i);
}


static int rpak_a(t_rpak *x, t_symbol *s, int ac, t_atom *av, int j) {
	t_atom *av2 = (t_atom *)getbytes((ac+1) * sizeof(t_atom));
	int i;
	for (i = 0; i < ac; i++) av2[i+1] = av[i];
	SETSYMBOL(av2, s);
	int result = rpak_l(x, 0, ac+1, av2, j);
	freebytes(av2, (ac+1) * sizeof(t_atom));
	return result;
}
static void rpak_anything(t_rpak *x, t_symbol *s, int ac, t_atom *av) {
	if (rpak_a(x, s, ac, av, x->x_n-1)) rpak_bang(x);
}
static void rpak_pxy_anything(t_rpak_pxy *p, t_symbol *s, int ac, t_atom *av) {
	rpak_a(p->p_x, s, ac, av, p->p_x->x_n-1 - p->p_i);
}


static void rpak_mute(t_rpak *x, t_floatarg f) {
	x->x_mute = ~(int)f;
}

static void rpak_free(t_rpak *x) {
	int i, n=x->x_n, pn=n-1;

	t_gpointer *gp;
	for (gp = x->x_ptr, i = (int)x->x_nptr; i--; gp++)
		gpointer_unset(gp);

	t_rpak_pxy **pp;
	for (pp=x->x_ins, i=pn; i--; pp++)
		if (*pp) pd_free((t_pd *)*pp);

	freebytes(x->x_vec, n * sizeof(*x->x_vec));
	freebytes(x->x_outvec, n * sizeof(*x->x_outvec));
	freebytes(x->x_type, n * sizeof(*x->x_type));
	freebytes(x->x_ins, pn * sizeof(t_rpak_pxy *));
	freebytes(x->x_ptr, x->x_nptr * sizeof(*x->x_ptr));
}

void setup_0x40pak(void) {
	rpak_class = class_new(gensym("@pak"),
		(t_newmethod)rpak_new, (t_method)rpak_free,
		sizeof(t_rpak), 0,
		A_GIMME, 0);
	class_addbang(rpak_class, rpak_bang);
	class_addpointer(rpak_class, rpak_pointer);
	class_addfloat(rpak_class, rpak_float);
	class_addsymbol(rpak_class, rpak_symbol);
	class_addlist(rpak_class, rpak_list);
	class_addanything(rpak_class, rpak_anything);
	class_addmethod(rpak_class, (t_method)rpak_mute,
		gensym("mute"), A_FLOAT, 0);
	class_sethelpsymbol(rpak_class, gensym("rpak"));

	rpak_proxy = class_new(gensym("_@pak_proxy"), 0, 0,
		sizeof(t_rpak_pxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(rpak_proxy, rpak_pxy_bang);
	class_addpointer(rpak_proxy, rpak_pxy_pointer);
	class_addfloat(rpak_proxy, rpak_pxy_float);
	class_addsymbol(rpak_proxy, rpak_pxy_symbol);
	class_addlist(rpak_proxy, rpak_pxy_list);
	class_addanything(rpak_proxy, rpak_pxy_anything);
}
