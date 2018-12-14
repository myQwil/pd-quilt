#include "m_pd.h"
#include "binop.h"

/* -------------------------- reverse subtraction -------------------------- */

static t_class *rminus_class;

static void *rminus_new(t_floatarg f) {
	return (binop_new(rminus_class, f));
}

static void rminus_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f2 - x->x_f1);
}

static void rminus_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, x->x_f2 - (x->x_f1=f));
}

void setup_0x400x2d(void) {
	rminus_class = class_new(gensym("@-"),
		(t_newmethod)rminus_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rminus_class, rminus_bang);
	class_addfloat(rminus_class, rminus_float);
	class_sethelpsymbol(rminus_class, gensym("revbinops"));
}
