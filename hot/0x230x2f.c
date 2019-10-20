#include "hot.h"

/* -------------------------- hot division -------------------------- */

static t_class *hdiv_class;
static t_class *hdiv_proxy_class;

static void hdiv_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f2 != 0 ? x->x_f1 / x->x_f2 : 0));
}

static void *hdiv_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hdiv_class, hdiv_proxy_class, hdiv_bang, s, ac, av));
}

void setup_0x230x2f(void) {
	hdiv_class = class_new(gensym("#/"),
		(t_newmethod)hdiv_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hdiv_class, hdiv_bang);
	class_addfloat(hdiv_class, hot_float);
	class_addmethod(hdiv_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hdiv_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hdiv_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hdiv_proxy_class = class_new(gensym("_#/_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hdiv_proxy_class, hot_proxy_bang);
	class_addfloat(hdiv_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hdiv_class, gensym("hotbinops1"));
}
