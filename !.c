#include "m_pd.h"

/* -------------------------- logical negation -------------------------- */

static t_class *not_class;

typedef struct _not {
	t_object x_obj;
	t_float x_f1;
} t_not;

static void not_bang(t_not *x) {
	outlet_float(x->x_obj.ob_outlet, !x->x_f1);
}

static void not_float(t_not *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, !(x->x_f1=f));
}

static void *not_new(t_floatarg f) {
	t_not *x = (t_not *)pd_new(not_class);
	outlet_new(&x->x_obj, &s_float);
	x->x_f1 = f;
	return (x);
}

void setup_0x21(void) {
	not_class = class_new(gensym("!"),
		(t_newmethod)not_new, 0,
		sizeof(t_not), 0,
		A_DEFFLOAT, 0);
	class_addbang(not_class, not_bang);
	class_addfloat(not_class, (t_method)not_float);
}
