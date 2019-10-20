#include "m_pd.h"
#include <string.h>
#include <stdlib.h>

#ifdef _MSC_VER
#define strtof(a,b) _atoldbl(a,*b)
#endif

/* -------------------------- reverse binops -------------------------- */

typedef struct _rev t_rev;
typedef void (*t_revmethod)(t_rev *x);

struct _rev {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
	t_revmethod x_bang;
	int x_lb;
};

static void rev_float(t_rev *x, t_float f) {
	x->x_f1 = f;
	x->x_bang(x);
}

static void rev_f2(t_rev *x, t_float f) {
	x->x_f2 = f;
}

static void rev_skip(t_rev *x, t_symbol *s, int ac, t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
		x->x_f2 = av->a_w.w_float;
	x->x_bang(x);
}

static void rev_loadbang(t_rev *x, t_floatarg action) {
	if (!action && x->x_lb) x->x_bang(x);
}

static void *rev_new
(t_class *fltclass, t_revmethod fn, t_symbol *s, int ac, t_atom *av) {
	t_rev *x = (t_rev *)pd_new(fltclass);
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
			if (c[strlen(c)-1] != '!') return 0;
			x->x_f2 = strtof(c, NULL);
			x->x_lb = 1;   }   }

	return (x);
}
