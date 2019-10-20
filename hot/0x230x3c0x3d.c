#include "hot.h"

/* -------------------------- hot <= -------------------------- */

static t_class *hle_class;
static t_class *hle_proxy_class;

static void hle_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 <= x->x_f2);
}

static void *hle_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hle_class, hle_proxy_class, hle_bang, s, ac, av));
}

void setup_0x230x3c0x3d(void) {
	hle_class = class_new(gensym("#<="),
		(t_newmethod)hle_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hle_class, hle_bang);
	class_addfloat(hle_class, hot_float);
	class_addmethod(hle_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hle_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hle_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hle_proxy_class = class_new(gensym("_#<=_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hle_proxy_class, hot_proxy_bang);
	class_addfloat(hle_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hle_class, gensym("hotbinops2"));
}
