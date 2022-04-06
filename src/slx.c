#include "slope.h"

/* -------------------------- slx -------------------------- */
static t_class *slx_class;

static void slope_k(t_slope *x) {
	if (x->log)
	{    slope_minmax(x);
	     x->k = x->run / log(x->max / x->min);  }
	else x->k = x->run /    (x->max - x->min);
}

static void slx_float(t_slope *x ,t_float f) {
	t_float res = (x->log)
		? log(f / x->min) * x->k
		:    (f - x->min) * x->k;
	outlet_float(x->obj.ob_outlet ,res);
}

static void *slx_new(t_symbol *s ,int argc ,t_atom *argv) {
	return slope_new(slx_class ,s ,argc ,argv);
}

void slx_setup(void) {
	slx_class = slope_setup(gensym("slx") ,(t_newmethod)slx_new);
	class_addfloat(slx_class ,slx_float);
	class_sethelpsymbol(slx_class ,gensym("slope"));
}
