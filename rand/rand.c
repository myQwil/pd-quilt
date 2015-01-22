#include "../m_pd.h"
#include <time.h>

/* -------------------------- rand -------------------------- */

static t_class *rand_class;

typedef struct _rand {
	t_object x_obj;
	t_float x_min, x_max, *x_vec;
	unsigned int x_state;
	int x_c;
} t_rand;

static int rand_time(void) {
	int thym = time(0) % 31536000; // seconds in a year
	return thym + !(thym%2); // odd numbers only
}

static int rand_makeseed(void) {
	static unsigned int rand_next = 1489853723;
	rand_next = rand_next * rand_time() + 938284287;
	return (rand_next & 0x7fffffff);
}

static void rand_seed(t_rand *x, t_symbol *s, int argc, t_atom *argv) {
	x->x_state = (argc ? atom_getfloat(argv) : rand_time());
}

static void rand_peek(t_rand *x, t_symbol *s) {
	post("%s%s%u", s->s_name, (*s->s_name ? ": " : ""), x->x_state);
}

static void rand_bang(t_rand *x) {
	int c=x->x_c, nval;
	unsigned int state = x->x_state;
	x->x_state = state = state * 472940017 + 832416023;

	if (c>2) {
		nval = (double)c * state * (1./4294967296.);
		outlet_float(x->x_obj.ob_outlet, x->x_vec[nval]);
	} else {
		int min=x->x_min, n=x->x_max-min, b=(n<0);
		int range = (c>1? n+(b? -1:1) : (!n? 1:n));
		double val = (double)range * state * (1./4294967296.) + min+b;
		nval = val-(val<0);
		outlet_float(x->x_obj.ob_outlet, nval);
	}
}

static void *rand_new(t_symbol *s, int argc, t_atom *argv) {
	t_rand *x = (t_rand *)pd_new(rand_class);
	x->x_c = argc;
	if (argc>2) {
		x->x_vec = (t_float *)getbytes(argc * sizeof(*x->x_vec));
		int i; t_float *fp;
		for (i=argc, fp=x->x_vec; i--; argv++, fp++) {
			*fp = atom_getfloat(argv);
			floatinlet_new(&x->x_obj, fp);
		}
	} else {
		t_float min=0, max=0;
		switch (argc) {
		  case 2:
			max=atom_getfloat(argv+1);
			min=atom_getfloat(argv);
		  break;
		  case 1: max=atom_getfloat(argv);
		}
		x->x_min=min, x->x_max=max;
		x->x_state = rand_makeseed();
		if (argc>1) floatinlet_new(&x->x_obj, &x->x_min);
		floatinlet_new(&x->x_obj, &x->x_max);
	}
	outlet_new(&x->x_obj, &s_float);
	return (x);
}

static void rand_free(t_rand *x) {
	int c=x->x_c;
	if (c>2) freebytes(x->x_vec, c * sizeof(*x->x_vec));
}

void rand_setup(void) {
	rand_class = class_new(gensym("rand"),
		(t_newmethod)rand_new, (t_method)rand_free,
		sizeof(t_rand), 0,
		A_GIMME, 0);

	class_addbang(rand_class, rand_bang);
	class_addmethod(rand_class, (t_method)rand_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(rand_class, (t_method)rand_peek,
		gensym("peek"), A_DEFSYM, 0);
}
