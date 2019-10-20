#include "hot.h"
#include <math.h>

/* -------------------------- hot pow -------------------------- */

static t_class *hpow_class;
static t_class *hpow_proxy_class;

static void hpow_bang(t_hot *x) {
	t_float r = (x->x_f1 == 0 && x->x_f2 < 0) ||
		(x->x_f1 < 0 && (x->x_f2 - (int)x->x_f2) != 0) ?
			0 : pow(x->x_f1, x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *hpow_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hpow_class, hpow_proxy_class, hpow_bang, s, ac, av));
}

void setup_0x23pow(void) {
	hpow_class = class_new(gensym("#pow"),
		(t_newmethod)hpow_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hpow_class, hpow_bang);
	class_addfloat(hpow_class, hot_float);
	class_addmethod(hpow_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hpow_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hpow_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hpow_proxy_class = class_new(gensym("_#pow_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hpow_proxy_class, hot_proxy_bang);
	class_addfloat(hpow_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hpow_class, gensym("hotbinops1"));
}
