#include "hot.h"

/* -------------------------- hot XOR -------------------------- */

static t_class *hxor_class;
static t_class *hxor_proxy_class;

static void hxor_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 ^ (int)x->x_f2);
}

static void *hxor_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hxor_class, hxor_proxy_class, hxor_bang, s, ac, av));
}

void setup_0x230x5e(void) {
	hxor_class = class_new(gensym("#^"),
		(t_newmethod)hxor_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hxor_class, hxor_bang);
	class_addfloat(hxor_class, hot_float);
	class_addmethod(hxor_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hxor_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hxor_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hxor_proxy_class = class_new(gensym("_#^_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hxor_proxy_class, hot_proxy_bang);
	class_addfloat(hxor_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hxor_class, gensym("0x5e"));
}
