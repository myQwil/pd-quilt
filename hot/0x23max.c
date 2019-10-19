#include "hot.h"

/* -------------------------- hot max -------------------------- */

static t_class *hmax_class;
static t_class *hmax_proxy_class;

static void hmax_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > x->x_f2 ? x->x_f1 : x->x_f2));
}

static void *hmax_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hmax_class, hmax_proxy_class, hmax_bang, s, ac, av));
}

void setup_0x23max(void) {
	hmax_class = class_new(gensym("#max"),
		(t_newmethod)hmax_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hmax_class, hmax_bang);
	class_addfloat(hmax_class, hot_float);
	class_addmethod(hmax_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hmax_proxy_class = class_new(gensym("_#max_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hmax_proxy_class, hot_proxy_bang);
	class_addfloat(hmax_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hmax_class, gensym("hotbinops1"));
}
