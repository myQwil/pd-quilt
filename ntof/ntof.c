#include "../m_pd.h"
#include <math.h>

/* -------------------------- ntof -------------------------- */

t_float ntof(t_float f, t_float root, t_float semi)
{ return (root * exp(semi*f)); }

static t_class *ntof_class;

typedef struct _ntof {
    t_object x_obj;
	t_float x_rt, x_st;		/* root tone, semi-tone */
	t_float x_ref, x_tet;	/* ref-pitch, # of tones */
} t_ntof;

static void ntof_ref(t_ntof *x, t_floatarg f)
{ x->x_rt = (x->x_ref=f) * pow(2,-69/x->x_tet); }

static void ntof_tet(t_ntof *x, t_floatarg f) {
	x->x_rt = x->x_ref * pow(2,-69/f);
	x->x_st = log(2) / (x->x_tet=f);
}

static void ntof_float(t_ntof *x, t_float f)
{ outlet_float(x->x_obj.ob_outlet, ntof(f, x->x_rt, x->x_st)); }

static void *ntof_new(t_symbol *s, int argc, t_atom *argv) {
	t_ntof *x = (t_ntof *)pd_new(ntof_class);
	outlet_new(&x->x_obj, &s_float);
	t_float ref=440, tet=12;
	
	switch (argc)
	{	case 2: tet = atom_getfloat(argv+1);
		case 1: ref = atom_getfloat(argv);   }
	x->x_rt = (x->x_ref=ref) * pow(2,-69/tet);
	x->x_st = log(2) / (x->x_tet=tet);
	return (x);
}

void ntof_setup(void) {
	ntof_class = class_new(gensym("ntof"),
		(t_newmethod)ntof_new, 0,
		sizeof(t_ntof), 0,
		A_GIMME, 0);
	
	class_addfloat(ntof_class, ntof_float);
	class_addmethod(ntof_class, (t_method)ntof_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(ntof_class, (t_method)ntof_tet,
		gensym("tet"), A_FLOAT, 0);
}
