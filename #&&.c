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
	outlet_float(x->x_obj.ob_outlet, (int)(x->x_f1=f) && (int)x->x_f2);
}

static void hla_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, (int)m->x_f2 && (int)m->x_f1);
}

static void hla_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, (int)(m->x_f2=f) && (int)m->x_f1);
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
