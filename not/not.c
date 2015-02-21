#include "../m_pd.h"

/* ------------------------ ! ------------------------ */

static t_class *negate_class;

typedef struct _negate {
	t_object x_obj;
	t_float x_f;
} t_negate;

static void *negate_new(void) {
	t_negate *x = (t_negate *)pd_new(negate_class);
	outlet_new(&x->x_obj, &s_float);
	x->x_f = 0;
	return (x);
}

static void negate_bang(t_negate *x) {
	outlet_float(x->x_obj.ob_outlet, !x->x_f);
}

static void negate_float(t_negate *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, !(x->x_f = f));
}

void negate_setup(void) {
	negate_class = class_new(gensym("not"), (t_newmethod)negate_new, 0,
        sizeof(t_negate), 0, 0);
	class_addcreator((t_newmethod)negate_new, gensym("!"), 0);
	class_addbang(negate_class, negate_bang);
	class_addfloat(negate_class, (t_method)negate_float);
}

void not_setup(void) {
	negate_setup();
}
