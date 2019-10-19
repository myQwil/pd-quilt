#include "hot.h"

/* -------------------------- hot % -------------------------- */

static t_class *hpc_class;
static t_class *hpc_proxy_class;

static void hpc_bang(t_hot *x) {
	int n2 = x->x_f2;
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 % (n2?n2:1));
}

static void *hpc_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hpc_class, hpc_proxy_class, hpc_bang, s, ac, av));
}

void setup_0x230x25(void) {
	hpc_class = class_new(gensym("#%"),
		(t_newmethod)hpc_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hpc_class, hpc_bang);
	class_addfloat(hpc_class, hot_float);
	class_addmethod(hpc_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hpc_proxy_class = class_new(gensym("_#%_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hpc_proxy_class, hot_proxy_bang);
	class_addfloat(hpc_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hpc_class, gensym("hotbinops3"));
}
