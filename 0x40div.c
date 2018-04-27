#include "m_pd.h"
#include "binop.h"

/* -------------------------- reverse div -------------------------- */

static t_class *rdivm_class;

static void *rdivm_new(t_floatarg f) {
	return (binop_new(rdivm_class, f));
}

static void rdivm_bang(t_binop *x) {
	int n2 = x->x_f2, n1 = x->x_f1, result;
	if (n1 < 0) n1 = -n1;
	else if (!n1) n1 = 1;
	if (n2 < 0) n2 -= (n1-1);
	result = n2 / n1;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void rdivm_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	rdivm_bang(x);
}

void setup_0x40div(void) {
	rdivm_class = class_new(gensym("@div"),
		(t_newmethod)rdivm_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rdivm_class, rdivm_bang);
	class_addfloat(rdivm_class, rdivm_float);
	class_sethelpsymbol(rdivm_class, gensym("revbinops"));
}
