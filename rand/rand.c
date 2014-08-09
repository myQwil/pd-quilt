#include "../m_pd.h"
#include <time.h>

static t_class *rand_class;

typedef struct _rand {
	t_object x_obj;
	t_float x_f;
	int x_thym;
	unsigned int x_state; // roll-over odometer
} t_rand;

int add_thym(void) {
	return time(0) % 31536000; // seconds in a year
}

int timeseed(int thym) {
	static unsigned int rand_nextseed = 1489853723;
	rand_nextseed = rand_nextseed * thym + 938284287;
	return (rand_nextseed & 0x7fffffff);
}

void rand_seed(t_rand *x, t_symbol *s, int argc, t_atom *argv) {
	x->x_state = x->x_thym =
		(!argc ? add_thym() : atom_getfloat(argv));
}

void rand_peek(t_rand *x, t_symbol *s) {
	post("%s%s%u (%d)", s->s_name, (*s->s_name ? ": " : ""),
		x->x_state, x->x_thym);
}

void rand_bang(t_rand *x) {
	int n=x->x_f, nval;
	int range = (n < 1 ? 1 : n);
	x->x_state = x->x_state * 472940017 + 832416023;
	nval = ((double)range) * ((double)x->x_state) / 4294967296;
	outlet_float(x->x_obj.ob_outlet, nval);
}

void *rand_new(t_floatarg f) {
	t_rand *x = (t_rand *)pd_new(rand_class);
	x->x_f = f;
	x->x_thym = add_thym();
	x->x_state = timeseed(x->x_thym);
	floatinlet_new(&x->x_obj, &x->x_f);
	outlet_new(&x->x_obj, &s_float);
	return (x);
}

void rand_setup(void) {
	rand_class = class_new(gensym("rand"),
		(t_newmethod)rand_new, 0,
		sizeof(t_rand), 0,
		A_DEFFLOAT, 0);
		
	class_addbang(rand_class, rand_bang);
	class_addmethod(rand_class, (t_method)rand_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(rand_class, (t_method)rand_peek,
		gensym("peek"), A_DEFSYM, 0);
}
