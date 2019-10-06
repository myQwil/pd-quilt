#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot || -------------------------- */

static t_class *hlo_class;
static t_class *hlo_proxy_class;

static void *hlo_new(t_floatarg f) {
	return (hotbinop_new(hlo_class, hlo_proxy_class, f));
}

static void hlo_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 || (int)x->x_f2);
}

static void hlo_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hlo_bang(x);
}

static void hlo_proxy_bang(t_hotbinop_proxy *p) {
	hlo_bang(p->p_x);
}

static void hlo_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hlo_bang(p->p_x);
}

void setup_0x230x7c0x7c(void) {
	hlo_class = class_new(gensym("#||"),
		(t_newmethod)hlo_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hlo_class, hlo_bang);
	class_addfloat(hlo_class, hlo_float);
	
	hlo_proxy_class = class_new(gensym("_#||_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hlo_proxy_class, hlo_proxy_bang);
	class_addfloat(hlo_proxy_class, hlo_proxy_float);
	
	class_sethelpsymbol(hlo_class, gensym("hotbinops3"));
}
