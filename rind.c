#include "m_pd.h"
#include <time.h>

/* -------------------------- rind -------------------------- */
static t_class *rind_class;

typedef struct _rind {
	t_object x_obj;
	t_float x_min;
	t_float x_max;
	unsigned x_state;
} t_rind;

static unsigned rind_time(void) {
	unsigned thym = time(0) * 2;
	return (thym|1); // odd numbers only
}

static unsigned rind_makeseed(void) {
	static unsigned rind_next = 1378742615;
	rind_next = rind_next * rind_time() + 938284287;
	return rind_next;
}

static void rind_seed(t_rind *x, t_symbol *s, int ac, t_atom *av) {
	x->x_state = (ac ? atom_getfloat(av) : rind_time());
}

static void rind_state(t_rind *x, t_symbol *s) {
	post("%s%s%u", s->s_name, *s->s_name?": ":"", x->x_state);
}

static void rind_peek(t_rind *x, t_symbol *s) {
	post("%s%s%g <=> %g", s->s_name, *s->s_name?": ":"", x->x_max, x->x_min);
}

static void rind_bang(t_rind *x) {
	double min=x->x_min, range=x->x_max-min, nval;
	unsigned *sp = &x->x_state;
	*sp = *sp * 472940017 + 832416023;
	nval = *sp * range / 4294967296 + min;
	outlet_float(x->x_obj.ob_outlet, nval);
}

static void rind_list(t_rind *x, t_symbol *s, int ac, t_atom *av) {
	switch (ac)
	{	case 2: if (av[1].a_type == A_FLOAT) x->x_min = av[1].a_w.w_float;
		case 1: if (av[0].a_type == A_FLOAT) x->x_max = av[0].a_w.w_float;   }
}

static void *rind_new(t_symbol *s, int ac, t_atom *av) {
	t_rind *x = (t_rind *)pd_new(rind_class);
	outlet_new(&x->x_obj, &s_float);
	
	floatinlet_new(&x->x_obj, &x->x_max);
	if (ac != 1) floatinlet_new(&x->x_obj, &x->x_min);
	
	switch (ac)
	{	case 2: x->x_min = atom_getfloat(av+1);
		case 1: x->x_max = atom_getfloat(av);   }
	x->x_state = rind_makeseed();
	
	return (x);
}

void rind_setup(void) {
	rind_class = class_new(gensym("rind"),
		(t_newmethod)rind_new, 0,
		sizeof(t_rind), 0,
		A_GIMME, 0);
	class_addbang(rind_class, rind_bang);
	class_addlist(rind_class, rind_list);
	class_addmethod(rind_class, (t_method)rind_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(rind_class, (t_method)rind_state,
		gensym("state"), A_DEFSYM, 0);
	class_addmethod(rind_class, (t_method)rind_peek,
		gensym("peek"), A_DEFSYM, 0);
}
