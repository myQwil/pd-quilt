#include "m_pd.h"
#include "binop.h"

/* -------------------------- <> -------------------------- */

static t_class *ltgt_class;

static void *ltgt_new(t_floatarg f) {
	return (binop_new(ltgt_class, f));
}

static void ltgt_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void ltgt_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1=f) != x->x_f2);
}

void setup_0x3c0x3e(void) {
	ltgt_class = class_new(gensym("<>"),
		(t_newmethod)ltgt_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	
	class_addbang(ltgt_class, ltgt_bang);
	class_addfloat(ltgt_class, ltgt_float);
	class_sethelpsymbol(ltgt_class, gensym("ne-aliases"));
}

void setup(void) {
	setup_0x3c0x3e();
}
