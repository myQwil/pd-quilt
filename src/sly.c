#include "slope.h"

/* -------------------------- sly -------------------------- */
static t_class *sly_class;

static void slope_k(t_slope *x) {
	if (x->log) {
		slope_minmax(x);
		x->k = log(x->max / x->min) / x->run;
	} else {
		x->k = (x->max - x->min) / x->run;
	}
}

static void sly_float(t_slope *x, t_float f) {
	t_float res = (x->log)
		? exp(x->k * f) * x->min
		: x->k * f + x->min;
	outlet_float(x->obj.ob_outlet, res);
}

static void *sly_new(t_symbol *s, int argc, t_atom *argv) {
	return slope_new(sly_class, s, argc, argv);
}

void sly_setup(void) {
	sly_class = slope_setup(gensym("sly")
	, (t_newmethod)sly_new, (t_method)sly_float);
}
