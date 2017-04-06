#include "m_pd.h"
#include "hotbinop.h"
#include <math.h>

/* -------------------------- hot pow -------------------------- */

static t_class *hot_pow_class;
static t_class *hot_pow_proxy_class;

static void *hot_pow_new(t_floatarg f) {
	return (hotbinop_new(hot_pow_class, hot_pow_proxy_class, f));
}

static void hot_pow_bang(t_hotbinop *x) {
	if (x->x_f1 >= 0)
		outlet_float(x->x_obj.ob_outlet, powf(x->x_f1, x->x_f2));
	else if (x->x_f2 <= -1 || x->x_f2 >= 1 || x->x_f2 == 0)
		outlet_float(x->x_obj.ob_outlet, powf(x->x_f1, x->x_f2));
	else
	{	pd_error(x, "pow: calculation resulted in a NaN");
		outlet_float(x->x_obj.ob_outlet, 0);   }
}

static void hot_pow_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	hot_pow_bang(x);
}

static void hot_pow_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	hot_pow_bang(m);
}

static void hot_pow_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	hot_pow_bang(m);
}

void setup_0x23pow(void) {
	hot_pow_class = class_new(gensym("#pow"),
		(t_newmethod)hot_pow_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addfloat(hot_pow_class, hot_pow_float);
	class_addbang(hot_pow_class, hot_pow_bang);
	
	hot_pow_proxy_class = class_new(gensym("_#pow_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(hot_pow_proxy_class, hot_pow_proxy_float);
	class_addbang(hot_pow_proxy_class, hot_pow_proxy_bang);
	
	class_sethelpsymbol(hot_pow_class, gensym("hotbinops1"));
}
