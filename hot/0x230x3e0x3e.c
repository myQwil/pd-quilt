#include "hot.h"

/* -------------------------- hot >> -------------------------- */

static t_class *hrs_class;
static t_class *hrs_proxy_class;

static void hrs_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 >> (int)x->x_f2);
}

static void *hrs_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hrs_class, hrs_proxy_class, hrs_bang, s, ac, av));
}

void setup_0x230x3e0x3e(void) {
	hrs_class = class_new(gensym("#>>"),
		(t_newmethod)hrs_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hrs_class, hrs_bang);
	class_addfloat(hrs_class, hot_float);
	class_addmethod(hrs_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hrs_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hrs_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hrs_proxy_class = class_new(gensym("_#>>_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hrs_proxy_class, hot_proxy_bang);
	class_addfloat(hrs_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hrs_class, gensym("hotbinops3"));
}
