#include "m_pd.h"
#include "binop.h"

/* -------------------------- reverse >> -------------------------- */

static t_class *rrs_class;

static void *rrs_new(t_floatarg f) {
	return (binop_new(rrs_class, f));
}

static void rrs_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 >> (int)x->x_f1);
}

static void rrs_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 >> (int)(x->x_f1=f));
}

void setup_0x400x3e0x3e(void) {
	rrs_class = class_new(gensym("@>>"),
		(t_newmethod)rrs_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rrs_class, rrs_bang);
	class_addfloat(rrs_class, rrs_float);
	class_sethelpsymbol(rrs_class, gensym("revbinops"));
}
