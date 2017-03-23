#include "m_pd.h"
#include <math.h>

typedef struct _binop {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
} t_binop;

static void *binop_new(t_class *floatclass, t_floatarg f) {
	t_binop *x = (t_binop *)pd_new(floatclass);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f2);
	x->x_f1 = 0;
	x->x_f2 = f;
	return (x);
}

/* ------------------------ woq -------------------------------- */

static t_class *woq_class;

static void *woq_new(t_floatarg f) {
	return (binop_new(woq_class, f));
}

static void woq_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, powf(x->x_f2, x->x_f1));
}

static void woq_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet, powf(x->x_f2, x->x_f1));
}

void woq_setup(void) {
	woq_class = class_new(gensym("woq"),
		(t_newmethod)woq_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	
	class_addbang(woq_class, woq_bang);
	class_addfloat(woq_class, (t_method)woq_float);
}