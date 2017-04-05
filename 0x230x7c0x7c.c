#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot || -------------------------- */

static t_class *hot_lo_class;
static t_class *hot_lo_proxy_class;

static void *hot_lo_new(t_floatarg f) {
	return (hotbinop_new(hot_lo_class, hot_lo_proxy_class, f));
}

static void hot_lo_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 || (int)x->x_f2);
}

static void hot_lo_float(t_hotbinop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (int)(x->x_f1=f) || (int)x->x_f2);
}

static void hot_lo_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, (int)m->x_f2 || (int)m->x_f1);
}

static void hot_lo_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, (int)(m->x_f2=f) || (int)m->x_f1);
}

void setup_0x230x7c0x7c(void) {
	hot_lo_class = class_new(gensym("#||"),
		(t_newmethod)hot_lo_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addfloat(hot_lo_class, hot_lo_float);
	class_addbang(hot_lo_class, hot_lo_bang);
	
	hot_lo_proxy_class = class_new(gensym("_#||_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(hot_lo_proxy_class, hot_lo_proxy_float);
	class_addbang(hot_lo_proxy_class, hot_lo_proxy_bang);
	
	class_sethelpsymbol(hot_lo_class, gensym("hotbinops3"));
}

void setup(void) {
	setup_0x230x7c0x7c();
}
