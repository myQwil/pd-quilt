#include "m_pd.h"
#include "hotbinop.h"
#include <math.h>

/* -------------------------- hot pow -------------------------- */

static t_class *hpow_class;
static t_class *hpow_proxy_class;

static void *hpow_new(t_floatarg f) {
	return (hotbinop_new(hpow_class, hpow_proxy_class, f));
}

static void hpow_bang(t_hotbinop *x) {
	t_float r = (x->x_f1 == 0 && x->x_f2 < 0) ||
		(x->x_f1 < 0 && (x->x_f2 - (int)x->x_f2) != 0) ?
			0 : pow(x->x_f1, x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void hpow_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hpow_bang(x);
}

static void hpow_proxy_bang(t_hotbinop_proxy *p) {
	hpow_bang(p->p_x);
}

static void hpow_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hpow_bang(p->p_x);
}

void setup_0x23pow(void) {
	hpow_class = class_new(gensym("#pow"),
		(t_newmethod)hpow_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hpow_class, hpow_bang);
	class_addfloat(hpow_class, hpow_float);
	
	hpow_proxy_class = class_new(gensym("_#pow_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hpow_proxy_class, hpow_proxy_bang);
	class_addfloat(hpow_proxy_class, hpow_proxy_float);
	
	class_sethelpsymbol(hpow_class, gensym("hotbinops1"));
}
