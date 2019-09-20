#include "m_pd.h"

/* -------------------------- grdnt -------------------------- */

static t_class *grdnt_class;

typedef struct _grdnt {
	t_object x_obj;
	t_float x_min, x_max, x_scl;
} t_grdnt;

static void grdnt_float(t_grdnt *x, t_float f) {
	double scale=x->x_scl, min=x->x_min, range=x->x_max-min;
	outlet_float(x->x_obj.ob_outlet, f / (scale / range) + min);
}

static void *grdnt_new(t_symbol *s, int argc, t_atom *argv) {
	t_grdnt *x = (t_grdnt *)pd_new(grdnt_class);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_min);
	floatinlet_new(&x->x_obj, &x->x_max);
	floatinlet_new(&x->x_obj, &x->x_scl);
	t_float min=0, max=1, scale=100;
	switch (argc)
	{ case 3: scale=atom_getfloat(argv+2); // no break
	  case 2:
		max=atom_getfloat(argv+1);
		min=atom_getfloat(argv); break;
	  case 1: max=atom_getfloat(argv);   }
	x->x_min=min, x->x_max=max, x->x_scl=scale;
	return (x);
}

void grdnt_setup(void) {
	grdnt_class = class_new(gensym("grdnt"),
		(t_newmethod)grdnt_new, 0,
		sizeof(t_grdnt), 0,
		A_GIMME, 0);
	class_addfloat(grdnt_class, grdnt_float);
}
