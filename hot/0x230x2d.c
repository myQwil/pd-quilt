#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot subtraction -------------------------- */

static t_class *hminus_class;
static t_class *hminus_proxy_class;

static void *hminus_new(t_floatarg f) {
	return (hotbinop_new(hminus_class, hminus_proxy_class, f));
}

static void hminus_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 - x->x_f2);
}

static void hminus_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hminus_bang(x);
}

static void hminus_proxy_bang(t_hotbinop_proxy *p) {
	hminus_bang(p->p_x);
}

static void hminus_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hminus_bang(p->p_x);
}

void setup_0x230x2d(void) {
	hminus_class = class_new(gensym("#-"),
		(t_newmethod)hminus_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hminus_class, hminus_bang);
	class_addfloat(hminus_class, hminus_float);
	
	hminus_proxy_class = class_new(gensym("_#-_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hminus_proxy_class, hminus_proxy_bang);
	class_addfloat(hminus_proxy_class, hminus_proxy_float);
	
	class_sethelpsymbol(hminus_class, gensym("hotbinops1"));
}
