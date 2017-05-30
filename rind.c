#include "m_pd.h"
#include <time.h>

/* -------------------------- rind -------------------------- */

static t_class *rind_class;

typedef struct _rind {
	t_object x_obj;
	t_float x_min, x_max;
	unsigned x_state;
} t_rind;

static int rind_time(void) {
	int thym = time(0) % 31536000; // seconds in a year
	return (thym|1); // odd numbers only
}

static int rind_makeseed(void) {
	static unsigned rind_next = 1378742615;
	rind_next = rind_next * rind_time() + 938284287;
	return (rind_next & 0x7fffffff);
}

static void rind_seed(t_rind *x, t_symbol *s, int argc, t_atom *argv) {
	x->x_state = (argc ? atom_getfloat(argv) : rind_time());
}

static void rind_peek(t_rind *x, t_symbol *s) {
	post("%s%s%u", s->s_name, *s->s_name?": ":"", x->x_state);
}

static void rind_min(t_rind *x, t_floatarg f) {
	x->x_min = f;
}

static void rind_max(t_rind *x, t_floatarg f) {
	x->x_max = f;
}

static void rind_bang(t_rind *x) {
	double min=x->x_min, range=x->x_max-min, nval;
	unsigned state = x->x_state;
	x->x_state = state = state * 472940017 + 832416023;
	nval = (1./4294967296) * range * state + min;
	outlet_float(x->x_obj.ob_outlet, nval);
}

static void *rind_new(t_symbol *s, int argc, t_atom *argv) {
	t_rind *x = (t_rind *)pd_new(rind_class);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_max);
	floatinlet_new(&x->x_obj, &x->x_min);
	t_float max=1, min=0;
	switch (argc)
	{ case 2: min=atom_getfloat(argv+1);
	  case 1: max=atom_getfloat(argv); }
	x->x_max=max, x->x_min=min;
	x->x_state = rind_makeseed();
	return (x);
}

void rind_setup(void) {
	rind_class = class_new(gensym("rind"),
		(t_newmethod)rind_new, 0,
		sizeof(t_rind), 0,
		A_GIMME, 0);
	class_addbang(rind_class, rind_bang);
	class_addmethod(rind_class, (t_method)rind_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(rind_class, (t_method)rind_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(rind_class, (t_method)rind_min,
		gensym("min"), A_FLOAT, 0);
	class_addmethod(rind_class, (t_method)rind_max,
		gensym("max"), A_FLOAT, 0);
}
