#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot >> -------------------------- */

static t_class *hrs_class;
static t_class *hrs_proxy_class;

static void *hrs_new(t_floatarg f) {
	return (hotbinop_new(hrs_class, hrs_proxy_class, f));
}

static void hrs_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 >> (int)x->x_f2);
}

static void hrs_float(t_hotbinop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (int)(x->x_f1=f) >> (int)x->x_f2);
}

static void hrs_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, (int)m->x_f1 >> (int)m->x_f2);
}

static void hrs_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, (int)m->x_f1 >> (int)(m->x_f2=f));
}

void setup_0x230x3e0x3e(void) {
	hrs_class = class_new(gensym("#>>"),
		(t_newmethod)hrs_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hrs_class, hrs_bang);
	class_addfloat(hrs_class, hrs_float);
	
	hrs_proxy_class = class_new(gensym("_#>>_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hrs_proxy_class, hrs_proxy_bang);
	class_addfloat(hrs_proxy_class, hrs_proxy_float);
	
	class_sethelpsymbol(hrs_class, gensym("hotbinops3"));
}
