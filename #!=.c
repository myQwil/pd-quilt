#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot != -------------------------- */

static t_class *hne_class;
static t_class *hne_proxy_class;

static void *hne_new(t_floatarg f) {
	return (hotbinop_new(hne_class, hne_proxy_class, f));
}

static void hne_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void hne_float(t_hotbinop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1=f) != x->x_f2);
}

static void hne_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 != m->x_f2);
}

static void hne_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 != (m->x_f2=f));
}

void setup_0x230x210x3d(void) {
	hne_class = class_new(gensym("#!="),
		(t_newmethod)hne_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hne_class, hne_bang);
	class_addfloat(hne_class, hne_float);
	
	hne_proxy_class = class_new(gensym("_#!=_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hne_proxy_class, hne_proxy_bang);
	class_addfloat(hne_proxy_class, hne_proxy_float);
	
	class_sethelpsymbol(hne_class, gensym("hotbinops2"));
}
