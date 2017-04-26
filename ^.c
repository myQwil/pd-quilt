#include "m_pd.h"
#include "binop.h"

/* -------------------------- XOR -------------------------- */

static t_class *xor_class;

static void *xor_new(t_floatarg f) {
	return (binop_new(xor_class, f));
}

static void xor_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 ^ (int)x->x_f2);
}

static void xor_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (int)(x->x_f1=f) ^ (int)x->x_f2);
}

void setup_0x5e(void) {
	xor_class = class_new(gensym("^"),
		(t_newmethod)xor_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(xor_class, xor_bang);
	class_addfloat(xor_class, xor_float);
}
