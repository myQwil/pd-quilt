#include "m_pd.h"
#include "binop.h"

/* -------------------------- reverse % -------------------------- */

static t_class *rpc_class;

static void *rpc_new(t_floatarg f) {
	return (binop_new(rpc_class, f));
}

static void rpc_bang(t_binop *x) {
	int n1 = x->x_f1;
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 % (n1?n1:1));
}

static void rpc_float(t_binop *x, t_float f) {
	int n1 = x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 % (n1?n1:1));
}

void setup_0x400x25(void) {
	rpc_class = class_new(gensym("@%"),
		(t_newmethod)rpc_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rpc_class, rpc_bang);
	class_addfloat(rpc_class, rpc_float);
	class_sethelpsymbol(rpc_class, gensym("revbinops"));
}
