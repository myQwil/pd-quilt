#include "hot.h"

/* -------------------------- hot & -------------------------- */

static t_class *hba_class;
static t_class *hba_proxy_class;

static void hba_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 & (int)x->x_f2);
}

static void *hba_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hba_class, hba_proxy_class, hba_bang, s, ac, av));
}

void setup_0x230x26(void) {
	hba_class = class_new(gensym("#&"),
		(t_newmethod)hba_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hba_class, hba_bang);
	class_addfloat(hba_class, hot_float);
	class_addmethod(hba_class, (t_method)hot_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(hba_class, (t_method)hot_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(hba_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hba_proxy_class = class_new(gensym("_#&_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hba_proxy_class, hot_proxy_bang);
	class_addfloat(hba_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hba_class, gensym("hotbinops3"));
}
