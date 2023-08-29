#include "inlet.h"

typedef struct _tab2 {
	t_object obj;
	t_float *edge;
	t_word *vec;
	t_symbol *arrayname;
	t_float f;
} t_tab2;

static void tab2_edge(t_tab2 *x, t_float f) {
	*x->edge = f;
}

static inline t_sample tab2_sample(t_word *w, t_sample frac, t_sample edge) {
	if (frac <= edge) {
		return w[0].w_float;
	} else {
		t_float a = w[0].w_float;
		t_float b = w[1].w_float;
		return (a + (b - a) * (frac - edge) / (1.f - edge));
	}
}

static t_tab2 *tab2_new(t_class *cl, t_symbol *s, t_float edge) {
	t_tab2 *x = (t_tab2 *)pd_new(cl);
	x->arrayname = s;
	x->vec = 0;

	t_inlet *in2 = signalinlet_new(&x->obj, edge);
	x->edge = &in2->iu_floatsignalvalue;

	outlet_new(&x->obj, &s_signal);
	x->f = 0;
	return x;
}

static t_class *class_tab2(t_symbol *s, t_newmethod newm, size_t size) {
	t_class *cls = class_new(s, newm, 0, size, 0, A_DEFSYM, A_DEFFLOAT, 0);
	class_domainsignalin(cls, (intptr_t)(&((t_tab2 *)0)->f));
	class_addmethod(cls, (t_method)tab2_edge, gensym("edge"), A_FLOAT, 0);
	return cls;
}
