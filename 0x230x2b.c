#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot addition -------------------------- */

static t_class *hplus_class;
static t_class *hplus_proxy_class;

static void *hplus_new(t_floatarg f) {
	return (hotbinop_new(hplus_class, hplus_proxy_class, f));
}

static void hplus_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 + x->x_f2);
}

static void hplus_float(t_hotbinop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1=f) + x->x_f2);
}

static void hplus_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 + m->x_f2);
}

static void hplus_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 + (m->x_f2=f));
}

void setup_0x230x2b(void) {
	hplus_class = class_new(gensym("#+"),
		(t_newmethod)hplus_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hplus_class, hplus_bang);
	class_addfloat(hplus_class, hplus_float);
	
	hplus_proxy_class = class_new(gensym("_#+_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hplus_proxy_class, hplus_proxy_bang);
	class_addfloat(hplus_proxy_class, hplus_proxy_float);
	
	class_sethelpsymbol(hplus_class, gensym("hotbinops1"));
}
