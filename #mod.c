#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot mod -------------------------- */

static t_class *hot_mod_class;
static t_class *hot_mod_proxy_class;

static void *hot_mod_new(t_floatarg f) {
	return (hotbinop_new(hot_mod_class, hot_mod_proxy_class, f));
}

static void hot_mod_bang(t_hotbinop *x) {
	int n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	result = (int)x->x_f1 % n2;
	if (result < 0) result += n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void hot_mod_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hot_mod_bang(x);
}

static void hot_mod_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	hot_mod_bang(m);
}

static void hot_mod_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	hot_mod_bang(m);
}

void setup_0x23mod(void) {
	hot_mod_class = class_new(gensym("#mod"),
		(t_newmethod)hot_mod_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addfloat(hot_mod_class, hot_mod_float);
	class_addbang(hot_mod_class, hot_mod_bang);
	
	hot_mod_proxy_class = class_new(gensym("_#mod_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(hot_mod_proxy_class, hot_mod_proxy_float);
	class_addbang(hot_mod_proxy_class, hot_mod_proxy_bang);
	
	class_sethelpsymbol(hot_mod_class, gensym("hotbinops3"));
}
