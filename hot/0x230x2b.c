#include "hot.h"

/* -------------------------- hot addition -------------------------- */

static t_class *hplus_class;
static t_class *hplus_proxy_class;

static void hplus_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 + x->x_f2);
}

static void *hplus_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hplus_class, hplus_proxy_class, hplus_bang, s, ac, av));
}

void setup_0x230x2b(void) {
	hplus_class = class_new(gensym("#+"),
		(t_newmethod)hplus_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hplus_class, hplus_bang);
	class_addfloat(hplus_class, hot_float);
	class_addmethod(hplus_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hplus_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hplus_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hplus_proxy_class = class_new(gensym("_#+_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hplus_proxy_class, hot_proxy_bang);
	class_addfloat(hplus_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hplus_class, gensym("hotbinops1"));
}
