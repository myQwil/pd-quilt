#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot div -------------------------- */

static t_class *hdivm_class;
static t_class *hdivm_proxy_class;

static void *hdivm_new(t_floatarg f) {
	return (hotbinop_new(hdivm_class, hdivm_proxy_class, f));
}

static void hdivm_bang(t_hotbinop *x) {
	int n1 = x->x_f1, n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void hdivm_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hdivm_bang(x);
}

static void hdivm_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	hdivm_bang(m);
}

static void hdivm_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	hdivm_bang(m);
}

void setup_0x23div(void) {
	hdivm_class = class_new(gensym("#div"),
		(t_newmethod)hdivm_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hdivm_class, hdivm_bang);
	class_addfloat(hdivm_class, hdivm_float);
	
	hdivm_proxy_class = class_new(gensym("_#div_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hdivm_proxy_class, hdivm_proxy_bang);
	class_addfloat(hdivm_proxy_class, hdivm_proxy_float);
	
	class_sethelpsymbol(hdivm_class, gensym("hotbinops3"));
}
