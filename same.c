#include "m_pd.h"

/* -------------------------- same -------------------------- */
static t_class *same_class;

typedef struct _same {
	t_object x_obj;
	t_outlet *x_out2;
	t_float x_f;
} t_same;

static void *same_new(t_floatarg f) {
	t_same *x = (t_same *)pd_new(same_class);
	x->x_f=f;
	outlet_new(&x->x_obj, &s_float);
	x->x_out2 = outlet_new(&x->x_obj, &s_float);
	return (x);
}

static void same_bang(t_same *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f);
}

static void same_float(t_same *x, t_float f) {
	if (f!=x->x_f)
	{	x->x_f=f;
		outlet_float(x->x_obj.ob_outlet, x->x_f);   }
	else outlet_float(x->x_out2, f);
}

static void same_set(t_same *x, t_float f) {
	x->x_f=f;
}

void same_setup(void) {
	same_class = class_new(gensym("same"),
		(t_newmethod)same_new, 0,
		sizeof(t_same), 0,
		A_DEFFLOAT, 0);
	class_addbang(same_class, same_bang);
	class_addfloat(same_class, same_float);
	class_addmethod(same_class, (t_method)same_set, gensym("set"),
		A_DEFFLOAT, 0);
}
