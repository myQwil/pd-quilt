#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot min -------------------------- */

static t_class *hmin_class;
static t_class *hmin_proxy_class;

static void *hmin_new(t_floatarg f) {
	return (hotbinop_new(hmin_class, hmin_proxy_class, f));
}

static void hmin_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void hmin_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hmin_bang(x);
}

static void hmin_proxy_bang(t_hotbinop_proxy *p) {
	hmin_bang(p->p_x);
}

static void hmin_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hmin_bang(p->p_x);
}

void setup_0x23min(void) {
	hmin_class = class_new(gensym("#min"),
		(t_newmethod)hmin_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hmin_class, hmin_bang);
	class_addfloat(hmin_class, hmin_float);
	
	hmin_proxy_class = class_new(gensym("_#min_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hmin_proxy_class, hmin_proxy_bang);
	class_addfloat(hmin_proxy_class, hmin_proxy_float);
	
	class_sethelpsymbol(hmin_class, gensym("hotbinops1"));
}
