#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot division -------------------------- */

static t_class *hdiv_class;
static t_class *hdiv_proxy_class;

static void *hdiv_new(t_floatarg f) {
	return (hotbinop_new(hdiv_class, hdiv_proxy_class, f));
}

static void hdiv_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f2 != 0 ? x->x_f1 / x->x_f2 : 0));
}

static void hdiv_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hdiv_bang(x);
}

static void hdiv_proxy_bang(t_hotbinop_proxy *p) {
	hdiv_bang(p->p_x);
}

static void hdiv_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hdiv_bang(p->p_x);
}

void setup_0x230x2f(void) {
	hdiv_class = class_new(gensym("#/"),
		(t_newmethod)hdiv_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hdiv_class, hdiv_bang);
	class_addfloat(hdiv_class, hdiv_float);
	
	hdiv_proxy_class = class_new(gensym("_#/_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hdiv_proxy_class, hdiv_proxy_bang);
	class_addfloat(hdiv_proxy_class, hdiv_proxy_float);
	
	class_sethelpsymbol(hdiv_class, gensym("hotbinops1"));
}
