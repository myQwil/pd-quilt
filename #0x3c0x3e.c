#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot <> -------------------------- */

static t_class *hot_ltgt_class;
static t_class *hot_ltgt_proxy_class;

static void *hot_ltgt_new(t_floatarg f) {
	return (hotbinop_new(hot_ltgt_class, hot_ltgt_proxy_class, f));
}

static void hot_ltgt_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void hot_ltgt_float(t_hotbinop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1=f) != x->x_f2);
}

static void hot_ltgt_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 != m->x_f2);
}

static void hot_ltgt_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet, m->x_f1 != (m->x_f2=f));
}

void setup_0x230x3c0x3e(void) {
	hot_ltgt_class = class_new(gensym("#<>"),
		(t_newmethod)hot_ltgt_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addfloat(hot_ltgt_class, hot_ltgt_float);
	class_addbang(hot_ltgt_class, hot_ltgt_bang);
	
	hot_ltgt_proxy_class = class_new(gensym("_#<>_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(hot_ltgt_proxy_class, hot_ltgt_proxy_float);
	class_addbang(hot_ltgt_proxy_class, hot_ltgt_proxy_bang);
	
	class_sethelpsymbol(hot_ltgt_class, gensym("ne-aliases"));
}
