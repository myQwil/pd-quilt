#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot mod -------------------------- */

static t_class *hmod_class;
static t_class *hmod_proxy_class;

static void *hmod_new(t_floatarg f) {
	return (hotbinop_new(hmod_class, hmod_proxy_class, f));
}

static void hmod_bang(t_hotbinop *x) {
	int n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	result = (int)x->x_f1 % n2;
	if (result < 0) result += n2;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void hmod_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hmod_bang(x);
}

static void hmod_proxy_bang(t_hotbinop_proxy *p) {
	hmod_bang(p->p_x);
}

static void hmod_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hmod_bang(p->p_x);
}

void setup_0x23mod(void) {
	hmod_class = class_new(gensym("#mod"),
		(t_newmethod)hmod_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hmod_class, hmod_bang);
	class_addfloat(hmod_class, hmod_float);
	
	hmod_proxy_class = class_new(gensym("_#mod_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hmod_proxy_class, hmod_proxy_bang);
	class_addfloat(hmod_proxy_class, hmod_proxy_float);
	
	class_sethelpsymbol(hmod_class, gensym("hotbinops3"));
}
