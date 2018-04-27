#include "m_pd.h"
#include "binop.h"

/* -------------------------- reverse mod -------------------------- */

static t_class *rmod_class;

static void *rmod_new(t_floatarg f) {
	return (binop_new(rmod_class, f));
}

static void rmod_bang(t_binop *x) {
	int n1 = x->x_f1, result;
	if (n1 < 0) n1 = -n1;
	else if (!n1) n1 = 1;
	result = (int)x->x_f2 % n1;
	if (result < 0) result += n1;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void rmod_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	rmod_bang(x);
}

void setup_0x40mod(void) {
	rmod_class = class_new(gensym("@mod"),
		(t_newmethod)rmod_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rmod_class, rmod_bang);
	class_addfloat(rmod_class, rmod_float);
	class_sethelpsymbol(rmod_class, gensym("revbinops"));
}
