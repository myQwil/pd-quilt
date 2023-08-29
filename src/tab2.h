#include "inlet.h"

typedef struct _tab2 {
	t_object obj;
	t_float *hold;
	t_word *vec;
	t_symbol *arrayname;
	t_float f;
} t_tab2;

static void tab2_hold(t_tab2 *x, t_float f) {
	*x->hold = f;
}

static inline t_sample tab2_sample(t_word *w, t_sample x, t_sample hold) {
	t_float y1, y2;
	t_sample run = 1.f - hold;
	// if (x < run) {
	// 	y2 = w[0].w_float;
	// 	y1 = (w[-1].w_float + y2) * 0.5;
	// 	return ((y2 - y1) / run * x + y1);
	// }
	if (x > hold) {
		y1 = w[0].w_float;
		y2 = w[1].w_float;
		// y2 = (w[1].w_float + y1) * 0.5;
		return ((y2 - y1) / run * (x - hold) + y1);
	}
	return w[0].w_float;
}

static t_tab2 *tab2_new(t_class *cl, t_symbol *s, t_float hold) {
	t_tab2 *x = (t_tab2 *)pd_new(cl);
	x->arrayname = s;
	x->vec = 0;

	t_inlet *in2 = signalinlet_new(&x->obj, hold);
	x->hold = &in2->iu_floatsignalvalue;

	outlet_new(&x->obj, &s_signal);
	x->f = 0;
	return x;
}

static t_class *class_tab2(t_symbol *s, t_newmethod newm, size_t size) {
	t_class *cls = class_new(s, newm, 0, size, 0, A_DEFSYM, A_DEFFLOAT, 0);
	class_domainsignalin(cls, (intptr_t)(&((t_tab2 *)0)->f));
	class_addmethod(cls, (t_method)tab2_hold, gensym("hold"), A_FLOAT, 0);
	return cls;
}
