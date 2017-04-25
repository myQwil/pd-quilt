#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot >< -------------------------- */

static t_class *hgtlt_class;
static t_class *hgtlt_proxy_class;

static void *hgtlt_new(t_floatarg f) {
	return (hotbinop_new(hgtlt_class, hgtlt_proxy_class, f));
}

static void hgtlt_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void hgtlt_float(t_hotbinop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1=f) != x->x_f2);
}

static void hgtlt_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 != m->x_f2);
}

static void hgtlt_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 != (m->x_f2=f));
}

void setup_0x230x3e0x3c(void) {
	hgtlt_class = class_new(gensym("#><"),
		(t_newmethod)hgtlt_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hgtlt_class, hgtlt_bang);
	class_addfloat(hgtlt_class, hgtlt_float);
	
	hgtlt_proxy_class = class_new(gensym("_#><_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hgtlt_proxy_class, hgtlt_proxy_bang);
	class_addfloat(hgtlt_proxy_class, hgtlt_proxy_float);
	
	class_sethelpsymbol(hgtlt_class, gensym("ne-aliases"));
}
