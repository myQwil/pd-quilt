#include "../m_pd.h"
#include <time.h>

static t_class *grand_class;

typedef struct _grand {
	t_object x_obj;
	t_float x_f, x_min, x_max;
	int x_thym;
	unsigned int x_state; // roll-over odometer
	t_outlet *g_out, *r_out;
} t_grand;

int add_thym(void) {
	return time(0) % 31536000; // seconds in a year
}

int timeseed(int thym) {
	static unsigned int grand_nextseed = 1590964834;
	grand_nextseed = grand_nextseed * thym + 938284287;
	return (grand_nextseed & 0x7fffffff);
}

void grand_seed(t_grand *x, t_symbol *s, int argc, t_atom *argv) {
	x->x_state = x->x_thym =
		(!argc ? add_thym() : atom_getfloat(argv));
}

void grand_peek(t_grand *x, t_symbol *s) {
	post("%s%s%u (%d)", s->s_name, (*s->s_name ? ": " : ""),
		x->x_state, x->x_thym);
}

void grand_bang(t_grand *x) {
	int n=x->x_f, nval;
	int range = (n < 1 ? 1 : n);
	double min=x->x_min, scale=x->x_max-min;
	x->x_state = x->x_state * 472940017 + 832416023;
	nval = ((double)range+1) * ((double)x->x_state) / 4294967296;
	
	outlet_float(x->r_out, nval);
	outlet_float(x->g_out, nval / (range / scale) + min);
}

void *grand_new(t_symbol *s, int argc, t_atom *argv) {
	t_grand *x = (t_grand *)pd_new(grand_class);
	t_float range=100, min=0, max=1;
	
	switch (argc) {
	  case 3:
		max = atom_getfloat(argv+2);
		min = atom_getfloat(argv+1);
	  case 1:
		range = atom_getfloat(argv);
	  break;
	  case 2:
		max = atom_getfloat(argv+1);
		min = atom_getfloat(argv);
	}
	x->x_f=range; x->x_min=min; x->x_max=max;
	x->x_thym = add_thym();
	x->x_state = timeseed(x->x_thym);
	
	floatinlet_new(&x->x_obj, &x->x_f);
	floatinlet_new(&x->x_obj, &x->x_min);
	floatinlet_new(&x->x_obj, &x->x_max);
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