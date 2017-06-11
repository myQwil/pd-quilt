#include "m_pd.h"

/* -------------------------- bitwise negation -------------------------- */

static t_class *bnot_class;

typedef struct _bnot {
	t_object x_obj;
	t_float x_f;
} t_bnot;

static void bnot_bang(t_bnot *x) {
	outlet_float(x->x_obj.ob_outlet, ~(int)x->x_f);
}

static void bnot_float(t_bnot *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ~(int)(x->x_f=f));
}

static void *bnot_new(t_floatarg f) {
	t_bnot *x = (t_bnot *)pd_new(bnot_class);
	outlet_new(&x->x_obj, &s_float);
	x->x_f = f;
	return (x);
}

void setup_0x21_tilde(void) {
	bnot_class = class_new(gensym("!~"),
		(t_newmethod)bnot_new, 0,
		sizeof(t_bnot), 0,
		A_DEFFLOAT, 0);
	class_addbang(bnot_class, bnot_bang);
	class_addfloat(bnot_class, bnot_float);
	class_addcreator((t_newmethod)bnot_new,
		gensym("~"), A_DEFFLOAT, 0);
}
