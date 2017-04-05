#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot div -------------------------- */

static t_class *hot_mdv_class;
static t_class *hot_mdv_proxy_class;

static void *hot_mdv_new(t_floatarg f) {
	return (hotbinop_new(hot_mdv_class, hot_mdv_proxy_class, f));
}

static void hot_mdv_bang(t_hotbinop *x) {
	int n1 = x->x_f1, n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void hot_mdv_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hot_mdv_bang(x);
}

static void hot_mdv_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	hot_mdv_bang(m);
}

static void hot_mdv_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	hot_mdv_bang(m);
}

void setup_0x23div(void) {
	hot_mdv_class = class_new(gensym("#div"),
		(t_newmethod)hot_mdv_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addfloat(hot_mdv_class, hot_mdv_float);
	class_addbang(hot_mdv_class, hot_mdv_bang);
	
	hot_mdv_proxy_class = class_new(gensym("_#div_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(hot_mdv_proxy_class, hot_mdv_proxy_float);
	class_addbang(hot_mdv_proxy_class, hot_mdv_proxy_bang);
	
	class_sethelpsymbol(hot_mdv_class, gensym("hotbinops3"));
}

void setup(void) {
	setup_0x23div();
}
