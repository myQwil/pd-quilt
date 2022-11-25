#include "inlet.h"

typedef struct {
	t_object obj;
	t_float *edge;
	t_float  edge_;
	t_float k;
	t_word *vec;
	t_symbol *arrayname;
	t_float f;
} t_tab2;

static inline void tab2_edge_(t_tab2 *x, t_float f) {
	x->edge_ = f;
	x->k = 1. / (1. - f);
}

static void tab2_edge(t_tab2 *x, t_float f) {
	*x->edge = f;
}

#define TAB2_INTERPOLATE(m, n) \
	edge = *in2; \
	if (frac <= edge) { \
		*out++ = m.w_float; \
	} else { \
		if (x->edge_ != edge) { \
			tab2_edge_(x, edge); \
		} \
		a = m.w_float; \
		b = n.w_float; \
		*out++ = a + (b - a) * (frac - edge) * x->k; \
	}

static t_tab2 *tab2_new(t_class *cl, t_symbol *s, t_float edge) {
	t_tab2 *x = (t_tab2 *)pd_new(cl);
	x->arrayname = s;
	x->vec = 0;

	t_inlet *in2 = signalinlet_new(&x->obj, edge);
	x->edge = &in2->iu_floatsignalvalue;
	tab2_edge_(x, edge);

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
