#include "../m_pd.h"
#include <time.h>

static t_class *divrt_class;

typedef struct _divrt {
	t_object x_obj;
	t_float x_f, x_max, x_prev;
	int x_thym, x_i;
	unsigned int x_state; // roll-over odometer
	t_outlet *f_out, *o_out;
} t_divrt;

static int add_thym(void) {
	int thym = time(0) % 31536000; // seconds in a year
	return thym + !(thym%2); // odd numbers only
}

static int timeseed(int thym) {
	static unsigned int divrt_nextseed = 1267631501;
	divrt_nextseed = divrt_nextseed * thym + 938284287;
	return (divrt_nextseed & 0x7fffffff);
}

static int nextr(t_divrt *x, int n) {
	int nval;
	int range = (n < 1 ? 1 : n);
	x->x_state = x->x_state * 472940017 + 832416023;
	nval = ((double)range) * ((double)x->x_state) / 4294967296;
	return nval;
}

static void divrt_seed(t_divrt *x, t_symbol *s, int argc, t_atom *argv) {
	x->x_state = x->x_thym =
		(!argc ? add_thym() : atom_getfloat(argv));
}

static void divrt_peek(t_divrt *x, t_symbol *s) {
	post("%s%s%u (%d)", s->s_name, (*s->s_name ? ": " : ""),
		x->x_state, x->x_thym);
}

static void divrt_float(t_divrt *x, t_float f) {
	int m=x->x_max;
	int max = (m < 1 ? 1 : m);
	if (f == x->x_prev) {
		if (x->x_i >= max) {
			x->x_i = 1;
			outlet_float(x->o_out, f);
			
			int n=x->x_f;
			f = (nextr(x, n-1) + (int)f + 1) % n;
			outlet_float(x->f_out, f);
		} else {
			x->x_i++;
			outlet_float(x->f_out, f);
		}
	} else {
		x->x_i = 1;
		outlet_float(x->f_out, f);
	}
	x->x_prev = f;
}

static void *divrt_new(t_floatarg f, t_floatarg max) {
	t_divrt *x = (t_divrt *)pd_new(divrt_class);
	x->x_f = (f < 1 ? 3 : f);
	x->x_max = (max < 1 ? 2 : max);
	x->x_thym = add_thym();
	x->x_state = timeseed(x->x_thym);
	
	floatinlet_new(&x->x_obj, &x->x_f);
	floatinlet_new(&x->x_obj, &x->x_max);
	x->f_out = outlet_new(&x->x_obj, &s_float);
	x->o_out = outlet_new(&x->x_obj, &s_float); // old value
	return (x);
}

void divrt_setup(void) {
	divrt_class = class_new(gensym("divrt"),
		(t_newmethod)divrt_new, 0,
		sizeof(t_divrt), 0,
		A_DEFFLOAT, A_DEFFLOAT, 0);
	
	class_addfloat(divrt_class, divrt_float);
	class_addmethod(divrt_class, (t_method)divrt_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(divrt_class, (t_method)divrt_peek,
		gensym("peek"), A_DEFSYM, 0);
}
