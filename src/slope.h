#include "m_pd.h"
#include <math.h>
#include <string.h>

typedef struct {
	t_object obj;
	double min;
	double max;
	double run;
	double k;
	unsigned char log;
} t_slope;

static void slope_minmax(t_slope *x) {
	double min = x->min, max = x->max;
	if ((min == 0.) && (max == 0.)) {
		max = 1.;
	}
	if (max > 0.) {
		if (min <= 0.) {
			min = 0.01 * max;
		}
	} else {
		if (min > 0.) {
			max = 0.01 * min;
		}
	}
	x->min = min;
	x->max = max;
}

static void slope_k(t_slope *x);

static void slope_min(t_slope *x, t_float f) {
	x->min = f;
	slope_k(x);
}

static void slope_max(t_slope *x, t_float f) {
	x->max = f;
	slope_k(x);
}

static void slope_run(t_slope *x, t_float f) {
	x->run = f;
	slope_k(x);
}

static void slope_log(t_slope *x, t_float f) {
	x->log = f;
	slope_k(x);
}

static void slope_list(t_slope *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	switch (ac) {
	case 3:
		if (av[2].a_type == A_FLOAT) {
			x->run = atom_getfloat(av + 2);
		}
		// fall through
	case 2:
		if (av[1].a_type == A_FLOAT) {
			x->max = atom_getfloat(av + 1);
		}
		// fall through
	case 1:
		if (av[0].a_type == A_FLOAT) {
			x->min = atom_getfloat(av + 0);
		}
		slope_k(x);
	}
}

static void slope_anything(t_slope *x, t_symbol *s, int ac, t_atom *av) {
	t_atom atoms[ac + 1];
	atoms[0] = (t_atom){ .a_type = A_SYMBOL, .a_w = {.w_symbol = s} };
	memcpy(atoms + 1, av, ac * sizeof(t_atom));
	slope_list(x, 0, ac + 1, atoms);
}

static t_slope *slope_new(t_class *cl, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_slope *x = (t_slope *)pd_new(cl);
	outlet_new(&x->obj, &s_float);
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("min"));
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("max"));
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("run"));
	t_float min = 0, max = 1, run = 128;

	if (ac && av->a_type == A_SYMBOL) {
		x->log = !strcmp(av->a_w.w_symbol->s_name, "log");
		ac--, av++;
	} else {
		x->log = 0;
	}

	switch (ac) {
	case 3:
		run = atom_getfloat(av + 2);
		// fall through
	case 2:
		max = atom_getfloat(av + 1);
		min = atom_getfloat(av);
		break;
	case 1:
		max = atom_getfloat(av);
	}
	x->min = min, x->max = max, x->run = run;
	slope_k(x);
	return x;
}

static t_class *slope_setup(t_symbol *s, t_newmethod nmet, t_method fmet) {
	t_class *cls = class_new(s, nmet, 0, sizeof(t_slope), 0, A_GIMME, 0);
	class_addfloat(cls, fmet);
	class_addlist(cls, slope_list);
	class_addanything(cls, slope_anything);

	class_addmethod(cls, (t_method)slope_min, gensym("min"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)slope_max, gensym("max"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)slope_run, gensym("run"), A_FLOAT, 0);
	class_addmethod(cls, (t_method)slope_log, gensym("log"), A_FLOAT, 0);
	class_sethelpsymbol(cls, gensym("slope"));

	return cls;
}
