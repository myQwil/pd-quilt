#include "tab2.h"

/******************** tabread2~ ***********************/

static t_class *tabread2_class;

typedef struct _tabread2 {
	t_tab2 z;
	t_float onset;
	int npoints;
} t_tabread2;

static t_int *tabread2_perform(t_int *w) {
	t_tabread2 *y = (t_tabread2 *)(w[1]);
	t_tab2 *x = &y->z;

	int n = (int)(w[2]);
	t_sample *out = (t_sample *)(w[3]);
	int maxindex = y->npoints - 3;
	t_word *buf = x->vec;
	if (maxindex < 0 || !buf) {
		while (n--) {
			*out++ = 0;
		}
	} else {
		t_sample *in1 = (t_sample *)(w[4]);
		t_sample *in2 = (t_sample *)(w[5]);
		double onset = y->onset;
		for (; n--; in1++, in2++) {
			double findex = *in1 + onset;
			int index = findex;
			t_sample frac;
			if (index < 1) {
				index = 1, frac = 0;
			} else if (index > maxindex) {
				index = maxindex, frac = 1;
			} else {
				frac = findex - index;
			}
			*out++ = tab2_sample(buf + index, frac, *in2);
		}
	}

	return (w + 6);
}

static void tabread2_set(t_tabread2 *y, t_symbol *s) {
	t_garray *a;
	t_tab2 *x = &y->z;

	x->arrayname = s;
	if (!(a = (t_garray *)pd_findbyclass(x->arrayname, garray_class))) {
		if (*s->s_name) {
			pd_error(x, "tabread2~: %s: no such array", x->arrayname->s_name);
		}
		x->vec = 0;
	} else if (!garray_getfloatwords(a, &y->npoints, &x->vec)) {
		pd_error(x, "%s: bad template for tabread2~", x->arrayname->s_name);
		x->vec = 0;
	} else {
		garray_usedindsp(a);
	}
}

static void tabread2_dsp(t_tabread2 *x, t_signal **sp) {
	tabread2_set(x, x->z.arrayname);

	dsp_add(tabread2_perform, 5, x, sp[0]->s_n, sp[2]->s_vec
	, sp[0]->s_vec, sp[1]->s_vec);
}

static void *tabread2_new(t_symbol *s, t_float edge) {
	t_tabread2 *y = (t_tabread2 *)tab2_new(tabread2_class, s, edge);
	t_tab2 *x = &y->z;
	floatinlet_new(&x->obj, &y->onset);

	y->onset = 0;
	return x;
}

void tabread2_tilde_setup(void) {
	tabread2_class = class_tab2(gensym("tabread2~")
	, (t_newmethod)tabread2_new, sizeof(t_tabread2));
	class_addmethod(tabread2_class, (t_method)tabread2_dsp, gensym("dsp"), A_CANT, 0);
	class_addmethod(tabread2_class, (t_method)tabread2_set, gensym("set"), A_SYMBOL, 0);
}
