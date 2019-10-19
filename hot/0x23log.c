#include "hot.h"
#include <math.h>

/* -------------------------- hot log -------------------------- */

static t_class *hlog_class;
static t_class *hlog_proxy_class;

static void hlog_bang(t_hot *x) {
	t_float r;
	if (x->x_f1 <= 0)
		r = -1000;
	else if (x->x_f2 <= 0)
		r = log(x->x_f1);
	else r = log(x->x_f1)/log(x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *hlog_new(t_symbol *s, int ac, t_atom *av) {
	return (hot_new(hlog_class, hlog_proxy_class, hlog_bang, s, ac, av));
}

void setup_0x23log(void) {
	hlog_class = class_new(gensym("#log"),
		(t_newmethod)hlog_new, (t_method)hot_free,
		sizeof(t_hot), 0,
		A_GIMME, 0);
	class_addbang(hlog_class, hlog_bang);
	class_addfloat(hlog_class, hot_float);
	class_addmethod(hlog_class, (t_method)hot_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	hlog_proxy_class = class_new(gensym("_#log_proxy"), 0, 0,
		sizeof(t_hot_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hlog_proxy_class, hot_proxy_bang);
	class_addfloat(hlog_proxy_class, hot_proxy_float);

	class_sethelpsymbol(hlog_class, gensym("log"));
}
