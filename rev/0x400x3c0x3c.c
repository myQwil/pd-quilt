#include "m_pd.h"
#include "binop.h"

/* -------------------------- reverse << -------------------------- */

static t_class *rls_class;

static void *rls_new(t_floatarg f) {
	return (binop_new(rls_class, f));
}

static void rls_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 << (int)x->x_f1);
}

static void rls_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 << (int)(x->x_f1=f));
}

void setup_0x400x3c0x3c(void) {
	rls_class = class_new(gensym("@<<"),
		(t_newmethod)rls_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rls_class, rls_bang);
	class_addfloat(rls_class, rls_float);
	class_sethelpsymbol(rls_class, gensym("revbinops"));
}
