#include "m_pd.h"
#include "hotbinop.h"

/* -------------------------- hot multiplication -------------------------- */

static t_class *htimes_class;
static t_class *htimes_proxy_class;

static void *htimes_new(t_floatarg f) {
	return (hotbinop_new(htimes_class, htimes_proxy_class, f));
}

static void htimes_bang(t_hotbinop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 * x->x_f2);
}

static void htimes_float(t_hotbinop *x, t_float f) {
	x->x_f1 = f;
	htimes_bang(x);
}

static void htimes_proxy_bang(t_hotbinop_proxy *p) {
	htimes_bang(p->p_x);
}

static void htimes_proxy_float(t_hotbinop_proxy *p, t_float f) {
	p->p_x->x_f2 = f;
	htimes_bang(p->p_x);
}

void setup_0x230x2a(void) {
	htimes_class = class_new(gensym("#*"),
		(t_newmethod)htimes_new, (t_method)hotbinop_free,
		sizeof(t_hotbinop), 0,
		A_DEFFLOAT, 0);
	class_addbang(htimes_class, htimes_bang);
	class_addfloat(htimes_class, htimes_float);
	
	htimes_proxy_class = class_new(gensym("_#*_proxy"), 0, 0,
		sizeof(t_hotbinop_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addbang(htimes_proxy_class, htimes_proxy_bang);
	class_addfloat(htimes_proxy_class, htimes_proxy_float);
	
	class_sethelpsymbol(htimes_class, gensym("hotbinops1"));
}
