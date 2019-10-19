#include "hot.h"

/* -------------------------- hot mod -------------------------- */

static t_class *hmod_class;
static t_class *hmod_proxy_class;

static void hmod_bang(t_hot *x) {
	int n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	result = (int)x->x_f1 % n2;
	if (result < 0) result += n2;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void *hmod_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hmod_class, hmod_proxy_class, hmod_bang, s, ac, av));
}

void setup_0x23mod(void) {
	hmod_class = class_new(gensym("#mod"),
		(t_newmethod)hmod_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hmod_class, hmod_bang);
	class_addfloat(hmod_class, hot_float);
	class_addmethod(hmod_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hmod_proxy_class = class_new(gensym("_#mod_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hmod_proxy_class, hot_proxy_bang);
	class_addfloat(hmod_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hmod_class, gensym("hotbinops3"));
}
