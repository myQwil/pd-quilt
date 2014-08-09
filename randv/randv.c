#include "../m_pd.h"
#include <time.h>

static t_class *randv_class;

typedef struct _randv {
	t_object x_obj;
	t_float x_f, x_max;
	int x_thym, x_prev, x_i;
	unsigned int x_state; // resets to 0 after passing 4,294,967,295
	t_outlet *f_out, *o_out;
} t_randv;

int add_thym(void) {
	return time(0) % 31536000; // seconds in a year
}

int timeseed(int thym) {
	static unsigned int randv_nextseed = 1601075945;
	randv_nextseed = randv_nextseed * thym + 938284287;
	return (randv_nextseed & 0x7fffffff);
}

int nextr(t_randv *x, int n) {
	int nval;
	int range = (n < 1 ? 1 : n);
	x->x_state = x->x_state * 472940017 + 832416023;
	nval = ((double)range) * ((double)x->x_state) / 4294967296;
	return nval;
}

void randv_seed(t_randv *x, t_symbol *s, int argc, t_atom *argv) {
	x->x_state = x->x_thym =
		(!argc ? add_thym() : atom_getfloat(argv));
}

void randv_peek(t_randv *x, t_symbol *s) {
	post("%s%s%u (%d)", s->s_name, (*s->s_name ? ": " : ""),
		x->x_state, x->x_thym);
}

void randv_bang(t_randv *x) {
	int m=x->x_max, f=nextr(x, x->x_f);
	int max = (m < 1 ? 1 : m);
	if (f == x->x_prev) {
		if (x->x_i >= max) {
			x->x_i = 1;
			int n = x->x_f;
			n = (n < 1 ? 1 : n);
			f = (nextr(x, n-1) + f+1) % n;
		} else x->x_i++;
	} else x->x_i = 1;
	x->x_prev = f;
	outlet_float(x->x_obj.ob_outlet, f);
}

void *randv_new(t_floatarg f, t_floatarg max) {
	t_randv *x = (t_randv *)pd_new(randv_class);
	x->x_f = (f < 1 ? 3 : f);
	x->x_max = (max < 1 ? 2 : max);
	x->x_thym = add_thym();
	x->x_state = timeseed(x->x_thym);
	
	floatinlet_new(&x->x_obj, &x->x_f);
	floatinlet_new(&x->x_obj, &x->x_max);
	outlet_new(&x->x_obj, &s_float);
	return (x);
}

void randv_setup(void) {
	randv_class = class_new(gensym("randv"),
		(t_newmethod)randv_new, 0,
		sizeof(t_randv), 0,
		A_DEFFLOAT, A_DEFFLOAT, 0);
	
	class_addbang(randv_class, randv_bang);
	class_addmethod(randv_class, (t_method)randv_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(randv_class, (t_method)randv_peek,
		gensym("peek"), A_DEFSYM, 0);
}
