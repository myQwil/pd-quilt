#include "blunt.h"

/* -------------------------- blunt binops -------------------------- */

typedef struct _bop {
	t_blunt bl;
	t_float f1;
	t_float f2;
} t_bop;

typedef void (*t_bopmethod)(t_bop *x);

static void bop_f1(t_bop *x ,t_float f) {
	x->f1 = f;
}

static void bop_f2(t_bop *x ,t_float f) {
	x->f2 = f;
}

static void bop_float(t_bop *x ,t_float f) {
	x->f1 = f;
	pd_bang((t_pd *)x);
}

static void bop_skip(t_bop *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
		x->f2 = av->a_w.w_float;
	pd_bang((t_pd *)x);
}

static t_bop *bop_new(t_class *cl ,t_symbol *s ,int ac ,t_atom *av) {
	t_bop *x = (t_bop *)pd_new(cl);
	outlet_new     (&x->bl.obj ,&s_float);
	floatinlet_new (&x->bl.obj ,&x->f2);

	if (ac>1 && av->a_type == A_FLOAT)
	{	x->f1 = av->a_w.w_float;
		av++;   }
	else x->f1 = 0;

	x->f2 = x->bl.loadbang = 0;
	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->f2 = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] == '!')
			{	x->f2 = strtof(c ,NULL);
				x->bl.loadbang = 1;   }   }   }
	return (x);
}
