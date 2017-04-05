#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot div -------------------------- */

static t_class *hot_divm_class;
static t_class *hot_divm_proxy_class;

static void *hot_divm_new(t_floatarg f) {
	return (hotbinop_new(hot_divm_class, hot_divm_proxy_class, f));
}

static void hot_divm_bang(t_hotbinop *x) {
	int n1 = x->x_f1, n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void hot_divm_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hot_divm_bang(x);
}

static void hot_divm_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	hot_divm_bang(m);
}

static void hot_divm_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	hot_divm_bang(m);
}

void setup_0x23div(void) {
	hot_divm_class = class_new(gensym("#div"),
		(t_newmethod)hot_divm_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addfloat(hot_divm_class, hot_divm_float);
	class_addbang(hot_divm_class, hot_divm_bang);
	
	hot_divm_proxy_class = class_new(gensym("_#div_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(hot_divm_proxy_class, hot_divm_proxy_float);
	class_addbang(hot_divm_proxy_class, hot_divm_proxy_bang);
	
	class_sethelpsymbol(hot_divm_class, gensym("hotbinops3"));
}

void setup(void) {
	setup_0x23div();
}
