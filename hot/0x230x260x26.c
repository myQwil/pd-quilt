#include "hot.h"

/* -------------------------- hot && -------------------------- */

static t_class *hla_class;
static t_class *hla_proxy_class;

static void hla_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 && (int)x->x_f2);
}

static void *hla_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hla_class, hla_proxy_class, hla_bang, s, ac, av));
}

void setup_0x230x260x26(void) {
	hla_class = class_new(gensym("#&&"),
		(t_newmethod)hla_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hla_class, hla_bang);
	class_addfloat(hla_class, hot_float);
	class_addmethod(hla_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hla_proxy_class = class_new(gensym("_#&&_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hla_proxy_class, hot_proxy_bang);
	class_addfloat(hla_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hla_class, gensym("hotbinops3"));
}
