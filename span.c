#include "m_pd.h"

/* -------------------------- span -------------------------- */
static t_class *span_class;

typedef struct _span {
	t_object x_obj;
	t_float x_min;
	t_float x_max;
	t_float x_scale;
} t_span;

static void span_float(t_span *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet,
		f * (x->x_max - x->x_min) / x->x_scale + x->x_min);
}

static void *span_new(t_symbol *s, int argc, t_atom *argv) {
	t_span *x = (t_span *)pd_new(span_class);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_min);
	floatinlet_new(&x->x_obj, &x->x_max);
	floatinlet_new(&x->x_obj, &x->x_scale);
	t_float min=0, max=1, scale=100;
	switch (argc)
	{ case 3: scale=atom_getfloat(argv+2); // no break
	  case 2:
		max=atom_getfloat(argv+1);
		min=atom_getfloat(argv); break;
	  case 1: max=atom_getfloat(argv);   }
	x->x_min=min, x->x_max=max, x->x_scale=scale;
	return (x);
}

void span_setup(void) {
	span_class = class_new(gensym("span"),
		(t_newmethod)span_new, 0,
		sizeof(t_span), 0,
		A_GIMME, 0);
	class_addfloat(span_class, span_float);
}
