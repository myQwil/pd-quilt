#include "m_pd.h"
#include "hotbinop.h"
#include <math.h>

/* -------------------------- hot log -------------------------- */

static t_class *hlog_class;
static t_class *hlog_proxy_class;

static void *hlog_new(t_floatarg f) {
	return (hotbinop_new(hlog_class, hlog_proxy_class, f));
}

static void hlog_bang(t_hotbinop *x) {
	t_float r;
	if (x->x_f1 <= 0)
		r = -1000;
	else if (x->x_f2 <= 0)
		r = log(x->x_f1);
	else r = log(x->x_f1)/log(x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void hlog_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hlog_bang(x);
}

static void hlog_proxy_bang(t_hotbinop_proxy *p) {
	hlog_bang(p->p_x);
}

static void hlog_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	hlog_bang(p->p_x);
}

void setup_0x23log(void) {
	hlog_class = class_new(gensym("#log"),
		(t_newmethod)hlog_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hlog_class, hlog_bang);
	class_addfloat(hlog_class, hlog_float);
	
	hlog_proxy_class = class_new(gensym("_#log_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hlog_proxy_class, hlog_proxy_bang);
	class_addfloat(hlog_proxy_class, hlog_proxy_float);
	
	class_sethelpsymbol(hlog_class, gensym("log"));
}
