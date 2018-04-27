#include "m_pd.h"
#include "binop.h"

/* -------------------------- reverse division -------------------------- */

static t_class *rdiv_class;

static void *rdiv_new(t_floatarg f) {
	return (binop_new(rdiv_class, f));
}

static void rdiv_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 != 0 ? x->x_f2 / x->x_f1 : 0));
}

static void rdiv_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 != 0 ? x->x_f2 / x->x_f1 : 0));
}

void setup_0x400x2f(void) {
	rdiv_class = class_new(gensym("@/"),
		(t_newmethod)rdiv_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rdiv_class, rdiv_bang);
	class_addfloat(rdiv_class, rdiv_float);
	class_sethelpsymbol(rdiv_class, gensym("revbinops"));
}
