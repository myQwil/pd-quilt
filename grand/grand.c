#include "../m_pd.h"
#include <time.h>

/* -------------------------- grand -------------------------- */

static t_class *grand_class;

typedef struct _grand {
	t_object x_obj;
	t_float x_min, x_max, x_f;
	t_outlet *g_out, *r_out;
	unsigned int x_state;
	int x_c;
} t_grand;

static int grand_time(void) {
	int thym = time(0) % 31536000; // seconds in a year
	return thym + !(thym%2); // odd numbers only. even numbers cause duplicate seeds
}

static int grand_makeseed(void) {
	static unsigned int grand_next = 1590964831;
	grand_next = grand_next * grand_time() + 938284287;
	return (grand_next & 0x7fffffff);
}

static void grand_seed(t_grand *x, t_symbol *s, int argc, t_atom *argv) {
	x->x_state = (argc ? atom_getfloat(argv) : grand_time());
}

static void grand_peek(t_grand *x, t_symbol *s) {
	post("%s%s%u", s->s_name, (*s->s_name ? ": " : ""), x->x_state);
}

static void grand_bang(t_grand *x) {
	int n=x->x_f, nval;
	int scale = (!n ? 1 : n);
	int b = ((n<0? -1:1)*(x->x_c>1));
	double min=x->x_min, range=x->x_max-min;
	unsigned int state = x->x_state;
	x->x_state = state = state * 472940017 + 832416023;
	nval = ((double)scale+b) * state * (1./4294967296.);
	outlet_float(x->r_out, nval);
	outlet_float(x->g_out, nval / (scale / range) + min);
}

static void *grand_new(t_symbol *s, int argc, t_atom *argv) {
	t_grand *x = (t_grand *)pd_new(grand_class);
	t_float min=0, max=1, scale=2147483647;
	switch (argc) {
	  case 3: scale=atom_getfloat(argv+2);
	  /* no break */
	  case 2:
		max=atom_getfloat(argv+1);
		min=atom_getfloat(argv);
	  break;
	  case 1: max=atom_getfloat(argv);
	}
	x->x_min=min, x->x_max=max, x->x_f=scale;
	x->x_state = grand_makeseed();
	x->x_c=argc;

	floatinlet_new(&x->x_obj, &x->x_min);
	floatinlet_new(&x->x_obj, &x->x_max);
	floatinlet_new(&x->x_obj, &x->x_f);
	x->g_out = outlet_new(&x->x_obj, &s_float); // gradient value
	x->r_out = outlet_new(&x->x_obj, &s_float); // random value
	return (x);
}

void grand_setup(void) {
	grand_class = class_new(gensym("grand"),
		(t_newmethod)grand_new, 0,
		sizeof(t_grand), 0,
		A_GIMME, 0);

	class_addbang(grand_class, grand_bang);
	class_addmethod(grand_class, (t_method)grand_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(grand_class, (t_method)grand_peek,
		gensym("peek"), A_DEFSYM, 0);
}
