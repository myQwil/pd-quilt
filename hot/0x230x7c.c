#include "hot.h"

/* -------------------------- hot | -------------------------- */

static t_class *hbo_class;
static t_class *hbo_proxy_class;

static void hbo_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 | (int)x->x_f2);
}

static void *hbo_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hbo_class, hbo_proxy_class, hbo_bang, s, ac, av));
}

void setup_0x230x7c(void) {
	hbo_class = class_new(gensym("#|"),
		(t_newmethod)hbo_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hbo_class, hbo_bang);
	class_addfloat(hbo_class, hot_float);
	class_addmethod(hbo_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hbo_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hbo_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hbo_proxy_class = class_new(gensym("_#|_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hbo_proxy_class, hot_proxy_bang);
	class_addfloat(hbo_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hbo_class, gensym("hotbinops3"));
}
