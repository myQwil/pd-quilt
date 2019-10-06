#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot && -------------------------- */

static t_class *hla_class;
static t_class *hla_proxy_class;

static void *hla_new(t_floatarg f) {
	return (hotbinop_new(hla_class, hla_proxy_class, f));
}

static void hla_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 && (int)x->x_f2);
}

static void hla_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hla_bang(x);
}

static void hla_proxy_bang(t_hotbinop_proxy *p) {
	hla_bang(p->p_x);
}

static void hla_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hla_bang(p->p_x);
}

void setup_0x230x260x26(void) {
	hla_class = class_new(gensym("#&&"),
		(t_newmethod)hla_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hla_class, hla_bang);
	class_addfloat(hla_class, hla_float);
	
	hla_proxy_class = class_new(gensym("_#&&_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hla_proxy_class, hla_proxy_bang);
	class_addfloat(hla_proxy_class, hla_proxy_float);
	
	class_sethelpsymbol(hla_class, gensym("hotbinops3"));
}
