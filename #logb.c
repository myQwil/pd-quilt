#include "m_pd.h"
#include "hotbinop.h"
#include <math.h>

/* -------------------------- hot logb -------------------------- */

static t_class *hlogb_class;
static t_class *hlogb_proxy_class;

static void *hlogb_new(t_floatarg f) {
	return (hotbinop_new(hlogb_class, hlogb_proxy_class, f));
}

static void hlogb_bang(t_hotbinop *x) {
	float f2 = (x->x_f2 > 0 ? logf(x->x_f2) : 0);
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > 0 && f2 ? logf(x->x_f1) / f2 : -1000));
}

static void hlogb_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hlogb_bang(x);
}

static void hlogb_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	hlogb_bang(m);
}

static void hlogb_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	hlogb_bang(m);
}

void setup_0x23logb(void) {
	hlogb_class = class_new(gensym("#logb"),
		(t_newmethod)hlogb_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hlogb_class, hlogb_bang);
	class_addfloat(hlogb_class, hlogb_float);
	
	hlogb_proxy_class = class_new(gensym("_#logb_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hlogb_proxy_class, hlogb_proxy_bang);
	class_addfloat(hlogb_proxy_class, hlogb_proxy_float);
	
	class_sethelpsymbol(hlogb_class, gensym("logb"));
}
