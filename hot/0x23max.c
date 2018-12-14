#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot max -------------------------- */

static t_class *hmax_class;
static t_class *hmax_proxy_class;

static void *hmax_new(t_floatarg f) {
	return (hotbinop_new(hmax_class, hmax_proxy_class, f));
}

static void hmax_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > x->x_f2 ? x->x_f1 : x->x_f2));
}

static void hmax_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > x->x_f2 ? x->x_f1 : x->x_f2));
}

static void hmax_proxy_bang(t_hotbinop_proxy *x) {
	t_hotbinop *m = x->p_master;
	outlet_float(m->x_obj.ob_outlet,
		(m->x_f1 > m->x_f2 ? m->x_f1 : m->x_f2));
}

static void hmax_proxy_float(t_hotbinop_proxy *x, t_float f) {
	t_hotbinop *m = x->p_master;
	m->x_f2 = f;
	outlet_float(m->x_obj.ob_outlet,
		(m->x_f1 > m->x_f2 ? m->x_f1 : m->x_f2));
}

void setup_0x23max(void) {
	hmax_class = class_new(gensym("#max"),
		(t_newmethod)hmax_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(hmax_class, hmax_bang);
	class_addfloat(hmax_class, hmax_float);
	
	hmax_proxy_class = class_new(gensym("_#max_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(hmax_proxy_class, hmax_proxy_bang);
	class_addfloat(hmax_proxy_class, hmax_proxy_float);
	
	class_sethelpsymbol(hmax_class, gensym("hotbinops1"));
}
