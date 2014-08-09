#include "../m_pd.h"

static t_class *graid_class;

typedef struct _graid {
	t_object x_obj;
	t_float x_f, x_min, x_max;
} t_graid;

void graid_float(t_graid *x, t_float f) {
	double range=x->x_f, min=x->x_min, scale=x->x_max-min;
	outlet_float(x->x_obj.ob_outlet, f / (range / scale) + min);
}

void *graid_new(t_symbol *s, int argc, t_atom *argv) {
	t_graid *x = (t_graid *)pd_new(graid_class);
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
	
	floatinlet_new(&x->x_obj, &x->x_f);
	floatinlet_new(&x->x_obj, &x->x_min);
	floatinlet_new(&x->x_obj, &x->x_max);
	outlet_new(&x->x_obj, &s_float);
	return (x);
}

void graid_setup(void) {
	graid_class = class_new(gensym("graid"),
		(t_newmethod)graid_new, 0,
		sizeof(t_graid), 0,
		A_GIMME, 0);
	
	class_addfloat(graid_class, graid_float);
}
