#include "hot.h"

/* -------------------------- hot min -------------------------- */

static t_class *hmin_class;
static t_class *hmin_proxy_class;

static void hmin_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void *hmin_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hmin_class, hmin_proxy_class, hmin_bang, s, ac, av));
}

void setup_0x23min(void) {
	hmin_class = class_new(gensym("#min"),
		(t_newmethod)hmin_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hmin_class, hmin_bang);
	class_addfloat(hmin_class, hot_float);
	class_addmethod(hmin_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hmin_proxy_class = class_new(gensym("_#min_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hmin_proxy_class, hot_proxy_bang);
	class_addfloat(hmin_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hmin_class, gensym("hotbinops1"));
}
