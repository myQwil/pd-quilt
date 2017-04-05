#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot min -------------------------- */

static t_class *hot_min_class;
static t_class *hot_min_proxy_class;

static void *hot_min_new(t_floatarg f) {
	return (hotbinop_new(hot_min_class, hot_min_proxy_class, f));
}

static void hot_min_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void hot_min_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void hot_min_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet,
		(m->x_f1 < m->x_f2 ? m->x_f1 : m->x_f2));
}

static void hot_min_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	outlet_float(m->x_obj.ob_outlet,
		(m->x_f1 < m->x_f2 ? m->x_f1 : m->x_f2));
}

void setup_0x23min(void) {
	hot_min_class = class_new(gensym("#min"),
		(t_newmethod)hot_min_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addfloat(hot_min_class, hot_min_float);
	class_addbang(hot_min_class, hot_min_bang);
	
	hot_min_proxy_class = class_new(gensym("_#min_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(hot_min_proxy_class, hot_min_proxy_float);
	class_addbang(hot_min_proxy_class, hot_min_proxy_bang);
	
	class_sethelpsymbol(hot_min_class, gensym("hotbinops1"));
}

void setup(void) {
	setup_0x23min();
}
