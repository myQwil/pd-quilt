#include "hot.h"

/* -------------------------- hot != -------------------------- */

static t_class *hne_class;
static t_class *hne_proxy_class;

static void hne_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void *hne_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hne_class, hne_proxy_class, hne_bang, s, ac, av));
}

void setup_0x230x210x3d(void) {
	hne_class = class_new(gensym("#!="),
		(t_newmethod)hne_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hne_class, hne_bang);
	class_addfloat(hne_class, hot_float);
	class_addmethod(hne_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hne_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hne_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hne_proxy_class = class_new(gensym("_#!=_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hne_proxy_class, hot_proxy_bang);
	class_addfloat(hne_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hne_class, gensym("hotbinops2"));
}
