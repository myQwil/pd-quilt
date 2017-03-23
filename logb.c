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

/* ------------------------ logb -------------------------------- */

static t_class *logb_class;

static void *logb_new(t_floatarg f) {
	return (binop_new(logb_class, f));
}

static void logb_bang(t_binop *x) {
	float f2 = (x->x_f2 > 0 ? logf(x->x_f2) : 0);
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > 0 && f2 ? logf(x->x_f1) / f2 : -1000));
}

static void logb_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	float f2 = (x->x_f2 > 0 ? logf(x->x_f2) : 0);
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > 0 && f2 ? logf(x->x_f1) / f2 : -1000));
}

void logb_setup(void) {
	logb_class = class_new(gensym("logb"),
		(t_newmethod)logb_new, 0,
		sizeof(t_binop), 0,
		A_DEFFLOAT, 0);
	
	class_addbang(logb_class, logb_bang);
	class_addfloat(logb_class, (t_method)logb_float);
}