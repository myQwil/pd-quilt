#include "m_pd.h"
#include "binop.h"
#include <math.h>

/* -------------------------- reverse pow -------------------------- */

static t_class *rpow_class;

static void *rpow_new(t_floatarg f) {
	return (binop_new(rpow_class, f));
}

static void rpow_bang(t_binop *x) {
	if (x->x_f2 >= 0)
		outlet_float(x->x_obj.ob_outlet, powf(x->x_f2, x->x_f1));
	else if (x->x_f1 <= -1 || x->x_f1 >= 1 || x->x_f1 == 0)
		outlet_float(x->x_obj.ob_outlet, powf(x->x_f2, x->x_f1));
	else
	{	pd_error(x, "pow: calculation resulted in a NaN");
		outlet_float(x->x_obj.ob_outlet, 0);   }
}

static void rpow_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	rpow_bang(x);
}

void setup_0x40pow(void) {
	rpow_class = class_new(gensym("@pow"),
		(t_newmethod)rpow_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	class_addbang(rpow_class, rpow_bang);
	class_addfloat(rpow_class, rpow_float);
	class_sethelpsymbol(rpow_class, gensym("revbinops"));
}
