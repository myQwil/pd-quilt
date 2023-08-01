#include "rng.h"

/* -------------------------- rind -------------------------- */
static t_class *rind_class;

typedef struct _rind {
	t_rng z;
	t_float min;
	t_float max;
} t_rind;

static void rind_print(t_rind *x, t_symbol *s) {
	post("%s%s%g <=> %g", s->s_name, *s->s_name ? ": " : "", x->max, x->min);
}

static void rind_bang(t_rind *x) {
	double min = x->min, range = x->max - min;
	outlet_float(x->z.obj.ob_outlet, rng_next(&x->z) * range + min);
}

static void rind_list(t_rind *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	switch (ac) {
	case 2:
		if (av[1].a_type == A_FLOAT) {
			x->min = av[1].a_w.w_float;
		}
		// fall through
	case 1:
		if (av[0].a_type == A_FLOAT) {
			x->max = av[0].a_w.w_float;
		}
	}
}

static void *rind_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_rind *y = (t_rind *)pd_new(rind_class);
	t_rng *x = &y->z;
	outlet_new(&x->obj, &s_float);

	floatinlet_new(&x->obj, &y->max);
	if (ac != 1) {
		floatinlet_new(&x->obj, &y->min);
	}

	switch (ac) {
	case 2:
		y->min = atom_getfloat(av + 1);
		// fall through
	case 1:
		y->max = atom_getfloat(av);
	}
	if (!ac) {
		y->max = 1;
	}

	rng_makeseed(x);
	return y;
}

void rind_setup(void) {
	seed = 1378742615;
	rind_class = class_new(gensym("rind")
	, (t_newmethod)rind_new, 0
	, sizeof(t_rind), 0
	, A_GIMME, 0);
	class_addbang(rind_class, rind_bang);
	class_addlist(rind_class, rind_list);
	class_addrng(rind_class);
	class_addmethod(rind_class, (t_method)rind_print, gensym("print"), A_DEFSYM, 0);
}
