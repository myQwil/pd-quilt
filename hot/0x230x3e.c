#include "hot.h"

/* -------------------------- hot > -------------------------- */

static t_class *hgt_class;
static t_class *hgt_proxy_class;

static void hgt_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 > x->x_f2);
}

static void *hgt_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hgt_class, hgt_proxy_class, hgt_bang, s, ac, av));
}

void setup_0x230x3e(void) {
	hgt_class = class_new(gensym("#>"),
		(t_newmethod)hgt_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hgt_class, hgt_bang);
	class_addfloat(hgt_class, hot_float);
	class_addmethod(hgt_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hgt_proxy_class = class_new(gensym("_#>_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hgt_proxy_class, hot_proxy_bang);
	class_addfloat(hgt_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hgt_class, gensym("hotbinops2"));
}
