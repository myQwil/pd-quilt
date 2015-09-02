#include "../m_pd.h"
#include <time.h>

static t_class *randv_class;

typedef struct _randv {
	t_object x_obj;
	int x_f, x_max,		// random value, max repeats
		x_prev, x_i;	// previous value, counter
	unsigned int x_state;
	t_outlet *f_out, *o_out;
} t_randv;

static int randv_time(void) {
	int thym = time(0) % 31536000; // seconds in a year
	return thym + !(thym%2); // odd numbers only
}

static int randv_makeseed(void) {
	static unsigned int randv_next = 1601075945;
	randv_next = randv_next * randv_time() + 938284287;
	return (randv_next & 0x7fffffff);
}

static void randv_seed(t_randv *x, t_symbol *s, int argc, t_atom *argv)
{ x->x_state = (argc ? atom_getfloat(argv) : randv_time()); }

static void randv_peek(t_randv *x, t_symbol *s)
{ post("%s%s%u", s->s_name, *s->s_name?": ":"", x->x_state); }

static int nextr(t_randv *x, int n) {
	int nval;
	int range = n<1?1:n;
	unsigned int state = x->x_state;
	x->x_state = state = state * 472940017 + 832416023;
	nval = (1./4294967296) * range * state;
	return nval;
}

static void randv_bang(t_randv *x) {
	int n=x->x_f, max=x->x_max, f=nextr(x,n), i=x->x_i;
	max = max<1?1:max;
	if (f==x->x_prev) {
		if (i>=max) {
			i=1, n=n<1?1:n;
			f = (nextr(x, n-1) + f+1) % n; }
		else i++; }
	else i=1;
	x->x_prev=f, x->x_i=i;
	outlet_float(x->x_obj.ob_outlet, f);
}

static void *randv_new(t_floatarg f, t_floatarg max) {
	t_randv *x = (t_randv *)pd_new(randv_class);
	x->x_f = f<1?3:f;
	x->x_max = max<1?2:max;
	x->x_state = randv_makeseed();
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f);
	floatinlet_new(&x->x_obj, &x->x_max);
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
