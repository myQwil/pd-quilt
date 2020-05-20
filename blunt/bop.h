#include "m_pd.h"
#include <string.h> // strlen
#include <stdlib.h> // strtof

/* -------------------------- blunt binops -------------------------- */

typedef struct _bop t_bop;
typedef void (*t_bopmethod)(t_bop *x);

struct _bop {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
	t_bopmethod x_bang;
	int x_lb;
};

static void bop_float(t_bop *x, t_float f) {
	x->x_f1 = f;
	x->x_bang(x);
}

static void bop_f2(t_bop *x, t_float f) {
	x->x_f2 = f;
}

static void bop_skip(t_bop *x, t_symbol *s, int ac, t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
		x->x_f2 = av->a_w.w_float;
	x->x_bang(x);
}

static void bop_loadbang(t_bop *x, t_floatarg action) {
	if (!action && x->x_lb) x->x_bang(x);
}

static void *bop_new
(t_class *fltclass, t_bopmethod fn, t_symbol *s, int ac, t_atom *av) {
	t_bop *x = (t_bop *)pd_new(fltclass);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f2);
	x->x_bang = fn;

	if (ac>1 && av->a_type == A_FLOAT)
	{	x->x_f1 = av->a_w.w_float;
		av++;   }
	else x->x_f1 = 0;

	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->x_f2 = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] == '!')
			{	x->x_f2 = strtof(c, NULL);
				x->x_lb = 1;   }
			else x->x_f2 = 0;   }   }
	return (x);
}
