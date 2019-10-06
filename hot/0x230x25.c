#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot % -------------------------- */

static t_class *hpc_class;
static t_class *hpc_proxy_class;

static void *hpc_new(t_floatarg f) {
	return (hotbinop_new(hpc_class, hpc_proxy_class, f));
}

static void hpc_bang(t_hotbinop *x) {
	int n2 = x->x_f2;
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 % (n2?n2:1));
}

static void hpc_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hpc_bang(x);
}

static void hpc_proxy_bang(t_hotbinop_proxy *p) {
	hpc_bang(p->p_x);
}

static void hpc_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hpc_bang(p->p_x);
}

void setup_0x230x25(void) {
	hpc_class = class_new(gensym("#%"),
		(t_newmethod)hpc_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hpc_class, hpc_bang);
	class_addfloat(hpc_class, hpc_float);
	
	hpc_proxy_class = class_new(gensym("_#%_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hpc_proxy_class, hpc_proxy_bang);
	class_addfloat(hpc_proxy_class, hpc_proxy_float);
	
	class_sethelpsymbol(hpc_class, gensym("hotbinops3"));
}
