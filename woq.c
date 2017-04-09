#include "m_pd.h"
#include "binop.h"
#include <math.h>

/* -------------------------- woq -------------------------- */

static t_class *woq_class;

static void *woq_new(t_floatarg f) {
	return (binop_new(woq_class, f));
}

static void woq_bang(t_binop *x) {
	if (x->x_f2 >= 0)
		outlet_float(x->x_obj.ob_outlet, powf(x->x_f2, x->x_f1));
	else if (x->x_f1 <= -1 || x->x_f1 >= 1 || x->x_f1 == 0)
		outlet_float(x->x_obj.ob_outlet, powf(x->x_f2, x->x_f1));
	else
	{	pd_error(x, "pow: calculation resulted in a NaN");
		outlet_float(x->x_obj.ob_outlet, 0);   }
}

static void woq_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	woq_bang(x);
}

void woq_setup(void) {
	woq_class = class_new(gensym("woq"),
		(t_newmethod)woq_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	
	class_addbang(woq_class, woq_bang);
	class_addfloat(woq_class, (t_method)woq_float);
}
