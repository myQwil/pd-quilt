#include "m_pd.h"
#include "binop.h"

/* -------------------------- >< -------------------------- */

static t_class *gtlt_class;

static void *gtlt_new(t_floatarg f) {
	return (binop_new(gtlt_class, f));
}

static void gtlt_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void gtlt_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1=f) != x->x_f2);
}

void setup_0x3e0x3c(void) {
	gtlt_class = class_new(gensym("><"),
		(t_newmethod)gtlt_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(gtlt_class, gtlt_bang);
	class_addfloat(gtlt_class, gtlt_float);
	class_sethelpsymbol(gtlt_class, gensym("ne-aliases"));
}

void setup(void) {
	setup_0x3e0x3c();
}
