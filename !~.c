#include "m_pd.h"

/* -------------------------- bitwise negation -------------------------- */

static t_class *bitnot_class;

typedef struct _bitnot {
	t_object x_obj;
	t_float x_f1;
} t_bitnot;

static void bitnot_bang(t_bitnot *x) {
	outlet_float(x->x_obj.ob_outlet, ~(int)x->x_f1);
}

static void bitnot_float(t_bitnot *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ~(int)(x->x_f1=f));
}

static void *bitnot_new(t_floatarg f) {
	t_bitnot *x = (t_bitnot *)pd_new(bitnot_class);
	outlet_new(&x->x_obj, &s_float);
	x->x_f1 = f;
	return (x);
}

void setup_0x21_tilde(void) {
	bitnot_class = class_new(gensym("!~"),
		(t_newmethod)bitnot_new, 0,
		sizeof(t_bitnot), 0,
		A_DEFFLOAT, 0);
	class_addbang(bitnot_class, bitnot_bang);
	class_addfloat(bitnot_class, (t_method)bitnot_float);
}
