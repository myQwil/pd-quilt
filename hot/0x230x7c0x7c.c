#include "hot.h"

/* -------------------------- hot || -------------------------- */

static t_class *hlo_class;
static t_class *hlo_proxy_class;

static void hlo_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 || (int)x->x_f2);
}

static void *hlo_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hlo_class, hlo_proxy_class, hlo_bang, s, ac, av));
}

void setup_0x230x7c0x7c(void) {
	hlo_class = class_new(gensym("#||"),
		(t_newmethod)hlo_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hlo_class, hlo_bang);
	class_addfloat(hlo_class, hot_float);
	class_addmethod(hlo_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hlo_proxy_class = class_new(gensym("_#||_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hlo_proxy_class, hot_proxy_bang);
	class_addfloat(hlo_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hlo_class, gensym("hotbinops3"));
}
