#include "hot.h"

/* -------------------------- hot >= -------------------------- */

static t_class *hge_class;
static t_class *hge_proxy_class;

static void hge_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 >= x->x_f2);
}

static void *hge_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hge_class, hge_proxy_class, hge_bang, s, ac, av));
}

void setup_0x230x3e0x3d(void) {
	hge_class = class_new(gensym("#>="),
		(t_newmethod)hge_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hge_class, hge_bang);
	class_addfloat(hge_class, hot_float);
	class_addmethod(hge_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hge_proxy_class = class_new(gensym("_#>=_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hge_proxy_class, hot_proxy_bang);
	class_addfloat(hge_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hge_class, gensym("hotbinops2"));
}
