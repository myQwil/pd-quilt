#include "hot.h"

/* -------------------------- hot << -------------------------- */

static t_class *hls_class;
static t_class *hls_proxy_class;

static void hls_bang(t_hot *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 << (int)x->x_f2);
}

static void *hls_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hls_class, hls_proxy_class, hls_bang, s, ac, av));
}

void setup_0x230x3c0x3c(void) {
	hls_class = class_new(gensym("#<<"),
		(t_newmethod)hls_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hls_class, hls_bang);
	class_addfloat(hls_class, hot_float);
	class_addmethod(hls_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hls_proxy_class = class_new(gensym("_#<<_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hls_proxy_class, hot_proxy_bang);
	class_addfloat(hls_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hls_class, gensym("hotbinops3"));
}
