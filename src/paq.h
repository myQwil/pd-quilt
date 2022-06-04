#include "m_pd.h"
#include <string.h>

#ifndef PAQ_FIRST
#define PAQ_FIRST(x) 0
#endif

#ifndef PAQ_INDEX
#define PAQ_INDEX(p) ((p)->idx)
#endif

typedef struct _paq t_paq;

typedef struct {
	t_object obj;
	t_paq *x;
	t_gpointer *ptr;   /* inlet's associated pointer */
	int idx;           /* inlet index */
} t_paq_pxy;

struct _paq {
	t_object obj;
	t_paq_pxy **ins;   /* proxy inlets */
	t_atomtype *type;  /* value types */
	t_gpointer *ptr;   /* gobj pointers */
	t_atom *vec;       /* input values */
	t_atom *outvec;    /* reserved space for output values */
	t_int mute;        /* muting mask for printing errors */
	int n;             /* number of args */
	int nptr;          /* number of pointers */
};

static t_paq *new_paq(t_class *cl ,t_class *pxy ,t_symbol *s ,int ac ,t_atom *av ,int r) {
	(void)s;
	t_paq *x = (t_paq*)pd_new(cl);
	t_atom defarg[2] ,*vp ,*ap;
	t_gpointer *gp;
	int nptr=0 ,i;

	if (!ac)
	{	av = defarg;
		ac = 2;
		SETFLOAT(&defarg[0] ,0);
		SETFLOAT(&defarg[1] ,0);  }

	x->n = ac;
	x->vec = (t_atom*)getbytes(ac * sizeof(t_atom));
	x->outvec = (t_atom*)getbytes(ac * sizeof(t_atom));
	x->type = (t_atomtype*)getbytes(ac * sizeof(t_atomtype));
	x->ins = (t_paq_pxy**)getbytes((ac-1) * sizeof(t_paq_pxy*));

	for (i=ac ,ap=av; i--; ap++)
	{	if (ap->a_type == A_FLOAT) nptr++;
		else if (ap->a_type == A_SYMBOL)
		{	const char *name = ap->a_w.w_symbol->s_name;
			if (strcmp(name ,"f") && strcmp(name ,s_float.s_name)
			 && strcmp(name ,"s") && strcmp(name ,s_symbol.s_name))
				nptr++;  }  }
	gp = x->ptr = (t_gpointer*)t_getbytes(nptr * sizeof(t_gpointer));
	x->nptr = nptr;

	ap = av + (r ? ac-1 : 0);
	r = r ? -1 : 1;
	vp = x->vec;
	t_atomtype *tp = x->type;
	t_paq_pxy **pp = x->ins;
	for (i=0; i < ac; i++ ,vp++ ,tp++ ,ap+=r)
	{	if (ap->a_type == A_FLOAT)
		{	*tp = A_GIMME;
			*vp = *ap;  }
		else if (ap->a_type == A_SYMBOL)
		{	const char *nm = ap->a_w.w_symbol->s_name;
			if (!strcmp(nm ,"b"))
			{	*tp = A_GIMME;
				SETSYMBOL(vp ,&s_bang);  }
			else if (!strcmp(nm ,"f") || !strcmp(nm ,s_float.s_name))
			{	*tp = vp->a_type = A_FLOAT;
				vp->a_w.w_float = 0;  }
			else if (!strcmp(nm ,"s") || !strcmp(nm ,s_symbol.s_name))
			{	*tp = vp->a_type = A_SYMBOL;
				vp->a_w.w_symbol = &s_symbol;  }
			else if (!strcmp(nm ,"p") || !strcmp(nm ,s_pointer.s_name))
			{	*tp = vp->a_type = A_POINTER;
				vp->a_w.w_gpointer = gp;  }
			else
			{	*tp = A_GIMME;
				if (strcmp(nm ,"a") && strcmp(nm ,"any"))
					SETSYMBOL(vp ,ap->a_w.w_symbol);
				else SETFLOAT(vp ,0);  }  }

		int hasptr = (*tp == A_POINTER || *tp == A_GIMME);
		if (i)
		{	*pp = (t_paq_pxy*)pd_new(pxy);
			(*pp)->x = x;
			(*pp)->idx = i;
			if (hasptr) (*pp)->ptr = gp;
			inlet_new(&x->obj ,(t_pd*)*pp ,0 ,0);
			pp++;  }
		if (hasptr)
		{	gpointer_init(gp);
			gp++;  }  }
	outlet_new(&x->obj ,&s_list);
	return x;
}

static const char *paq_check(t_atomtype type) {
	if      (type == A_FLOAT)   return s_float.s_name;
	else if (type == A_SYMBOL)  return s_symbol.s_name;
	else if (type == A_POINTER) return s_pointer.s_name;
	else return "null";
}

static void paq_error(t_paq *x ,int i ,const char *t) {
	if (i) pd_error(x ,"inlet: expected '%s' but got '%s'"
		,paq_check(x->type[i]) ,t);
	else pd_error(x ,"paq_%s: wrong type" ,t);
}

static void paq_bang(t_paq *x) {
	t_atom *vp = x->vec;
	t_atomtype *tp = x->type;
	t_gpointer *gp = x->ptr;
	for (int i=x->n; i--; vp++ ,tp++)
		if (*tp == A_GIMME && vp->a_type != A_POINTER) gp++;
		else if (vp->a_type == A_POINTER)
		{	if (!gpointer_check(gp ,1))
			{	pd_error(x ,"%s: stale pointer %d"
					,class_getname(*(t_pd*)x) ,i);
				return;  }
			else gp++;  }

	/* reentrancy protection.  The first time through use the pre-allocated
	outvec; if we're reentered we have to allocate new memory. */
	t_atom *outvec;
	int reentered = 0 ,size = (int)(x->n * sizeof(t_atom));
	if (!x->outvec)
	{	/* LATER figure out how to deal with reentrancy and pointers... */
		if (x->nptr)
			post("%s_bang: warning: reentry with pointers unprotected"
				,class_getname(*(t_pd*)x));
		outvec = (t_atom*)t_getbytes(size);
		reentered = 1;  }
	else
	{	outvec = x->outvec;
		x->outvec = 0;  }
	memcpy(outvec ,x->vec ,size);
	outlet_list(x->obj.ob_outlet ,&s_list ,x->n ,outvec);
	if (reentered) t_freebytes(outvec ,size);
	else x->outvec = outvec;
}

static void paq_pxy_bang(t_paq_pxy *p) {
	t_paq *x = p->x;
	int i = PAQ_INDEX(p);
	t_atomtype type = x->type[i];
	if (type == A_SYMBOL || type == A_GIMME)
		SETSYMBOL(x->vec+i ,&s_bang);
	else if ((x->mute >> i) & 1) paq_error(x ,i ,s_bang.s_name);
}

static inline void paq_p(t_paq *x ,t_gpointer *ptr ,t_gpointer *gp ,int i) {
	t_atomtype type = x->type[i];
	if (type == A_POINTER || type == A_GIMME)
	{	gpointer_unset(ptr);
		*ptr = *gp;
		if (gp->gp_stub) gp->gp_stub->gs_refcount++;
		SETPOINTER(x->vec+i ,ptr);
		if (i == PAQ_FIRST(x)) paq_bang(x);  }
	else if ((x->mute >> i) & 1) paq_error(x ,i ,s_pointer.s_name);
}


static inline void paq_f(t_paq *x ,t_float f ,int i) {
	t_atomtype type = x->type[i];
	if (type == A_FLOAT || type == A_GIMME)
	{	SETFLOAT(x->vec+i ,f);
		if (i == PAQ_FIRST(x)) paq_bang(x);  }
	else if ((x->mute >> i) & 1) paq_error(x ,i ,s_float.s_name);
}
static void paq_float(t_paq *x ,t_float f) {
	paq_f(x ,f ,PAQ_FIRST(x));
}
static void paq_pxy_float(t_paq_pxy *p ,t_float f) {
	paq_f(p->x ,f ,PAQ_INDEX(p));
}


static inline void paq_s(t_paq *x ,t_symbol *s ,int i) {
	t_atomtype type = x->type[i];
	if (type == A_SYMBOL || type == A_GIMME)
	{	SETSYMBOL(x->vec+i ,s);
		if (i == PAQ_FIRST(x)) paq_bang(x);  }
	else if ((x->mute >> i) & 1) paq_error(x ,i ,s_symbol.s_name);
}
static void paq_symbol(t_paq *x ,t_symbol *s) {
	paq_s(x ,s ,PAQ_FIRST(x));
}
static void paq_pxy_symbol(t_paq_pxy *p ,t_symbol *s) {
	paq_s(p->x ,s ,PAQ_INDEX(p));
}


static int paq_set(t_atom *v ,t_gpointer *p ,t_atom a ,t_atomtype t) {
	if (t == a.a_type || t == A_GIMME)
	{	if (a.a_type == A_POINTER)
		{	t_gpointer *gp = a.a_w.w_gpointer;
			gpointer_unset(p);
			*p = *gp;
			if (gp->gp_stub) gp->gp_stub->gs_refcount++;
			SETPOINTER(v ,p);  }
		else *v = a;
		return 1;  }
	else return 0;
}

static inline int paq_l(t_paq *x ,int ac ,t_atom *av ,int i);
static void paq_list(t_paq *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	if (paq_l(x ,ac ,av ,PAQ_FIRST(x))) paq_bang(x);
}
static void paq_pxy_list(t_paq_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	paq_l(p->x ,ac ,av ,PAQ_INDEX(p));
}


static inline int paq_a(t_paq *x ,t_symbol *s ,int ac ,t_atom *av ,int j) {
	t_atom atoms[ac+1];
	atoms[0] = (t_atom){.a_type=A_SYMBOL ,.a_w={.w_symbol = s}};
	memcpy(atoms+1 ,av ,ac * sizeof(t_atom));
	int result = paq_l(x ,ac+1 ,atoms ,j);
	return result;
}
static void paq_anything(t_paq *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (paq_a(x ,s ,ac ,av ,PAQ_FIRST(x))) paq_bang(x);
}
static void paq_pxy_anything(t_paq_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	paq_a(p->x ,s ,ac ,av ,PAQ_INDEX(p));
}


static void paq_mute(t_paq *x ,t_float f) {
	x->mute = ~(int)f;
}

static void paq_free(t_paq *x) {
	int i ,n=x->n ,pn=n-1;

	t_gpointer *gp;
	for (gp = x->ptr ,i = (int)x->nptr; i--; gp++)
		gpointer_unset(gp);

	t_paq_pxy **pp;
	for (pp=x->ins ,i=pn; i--; pp++)
		if (*pp) pd_free((t_pd*)*pp);

	freebytes(x->vec    ,n  * sizeof(t_atom));
	freebytes(x->outvec ,n  * sizeof(t_atom));
	freebytes(x->type   ,n  * sizeof(t_atomtype));
	freebytes(x->ins    ,pn * sizeof(t_paq_pxy*));
	freebytes(x->ptr    ,x->nptr * sizeof(t_gpointer));
}

static void class_addpaq(t_class *cpaq ,t_class *cpxy) {
	class_addbang     (cpaq ,paq_bang);
	class_addfloat    (cpaq ,paq_float);
	class_addsymbol   (cpaq ,paq_symbol);
	class_addlist     (cpaq ,paq_list);
	class_addanything (cpaq ,paq_anything);
	class_addmethod   (cpaq ,(t_method)paq_mute ,gensym("mute") ,A_FLOAT ,0);

	class_addbang     (cpxy ,paq_pxy_bang);
	class_addfloat    (cpxy ,paq_pxy_float);
	class_addsymbol   (cpxy ,paq_pxy_symbol);
	class_addlist     (cpxy ,paq_pxy_list);
	class_addanything (cpxy ,paq_pxy_anything);
}
