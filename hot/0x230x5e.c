#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot XOR -------------------------- */

static t_class *hxor_class;
static t_class *hxor_proxy_class;

static void *hxor_new(t_floatarg f) {
	return (hotbinop_new(hxor_class, hxor_proxy_class, f));
}

static void hxor_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 ^ (int)x->x_f2);
}

static void hxor_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hxor_bang(x);
}

static void hxor_proxy_bang(t_hotbinop_proxy *p) {
	hxor_bang(p->p_x);
}

static void hxor_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hxor_bang(p->p_x);
}

void setup_0x230x5e(void) {
	hxor_class = class_new(gensym("#^"),
		(t_newmethod)hxor_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hxor_class, hxor_bang);
	class_addfloat(hxor_class, hxor_float);
	
	hxor_proxy_class = class_new(gensym("_#^_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hxor_proxy_class, hxor_proxy_bang);
	class_addfloat(hxor_proxy_class, hxor_proxy_float);
	
	class_sethelpsymbol(hxor_class, gensym("0x5e"));
}
