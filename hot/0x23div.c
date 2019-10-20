#include "hot.h"

/* -------------------------- hot div -------------------------- */

static t_class *hdivm_class;
static t_class *hdivm_proxy_class;

static void hdivm_bang(t_hot *x) {
	int n1 = x->x_f1, n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void *hdivm_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hdivm_class, hdivm_proxy_class, hdivm_bang, s, ac, av));
}

void setup_0x23div(void) {
	hdivm_class = class_new(gensym("#div"),
		(t_newmethod)hdivm_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hdivm_class, hdivm_bang);
	class_addfloat(hdivm_class, hot_float);
	class_addmethod(hdivm_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hdivm_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hdivm_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hdivm_proxy_class = class_new(gensym("_#div_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hdivm_proxy_class, hot_proxy_bang);
	class_addfloat(hdivm_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hdivm_class, gensym("hotbinops3"));
}
