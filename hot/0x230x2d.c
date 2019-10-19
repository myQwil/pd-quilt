#include "hot.h"

/* -------------------------- hot subtraction -------------------------- */

static t_class *hminus_class;
static t_class *hminus_proxy_class;

static void hminus_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 - x->x_f2);
}

static void *hminus_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hminus_class, hminus_proxy_class, hminus_bang, s, ac, av));
}

void setup_0x230x2d(void) {
	hminus_class = class_new(gensym("#-"),
		(t_newmethod)hminus_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hminus_class, hminus_bang);
	class_addfloat(hminus_class, hot_float);
	class_addmethod(hminus_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hminus_proxy_class = class_new(gensym("_#-_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hminus_proxy_class, hot_proxy_bang);
	class_addfloat(hminus_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hminus_class, gensym("hotbinops1"));
}
