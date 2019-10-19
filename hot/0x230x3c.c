#include "hot.h"

/* -------------------------- hot < -------------------------- */

static t_class *hlt_class;
static t_class *hlt_proxy_class;

static void hlt_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 < x->x_f2);
}

static void *hlt_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hlt_class, hlt_proxy_class, hlt_bang, s, ac, av));
}

void setup_0x230x3c(void) {
	hlt_class = class_new(gensym("#<"),
		(t_newmethod)hlt_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hlt_class, hlt_bang);
	class_addfloat(hlt_class, hot_float);
	class_addmethod(hlt_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hlt_proxy_class = class_new(gensym("_#<_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hlt_proxy_class, hot_proxy_bang);
	class_addfloat(hlt_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hlt_class, gensym("hotbinops2"));
}
