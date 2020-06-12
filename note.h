#include "m_pd.h"
#include <math.h>

typedef struct _note {
	t_object x_obj;
	t_float x_ref;   /* reference pitch */
	t_float x_tet;   /* number of tones */
	double x_rt;     /* root tone */
	double x_st;     /* semi-tone */
} t_note;

static double note_root(t_note *x) {
	return (x->x_ref * pow(2, -69 / x->x_tet));
}

static double note_semi(t_note *x) {
	return (log(2) / x->x_tet);
}

static t_note *note_new(t_class *cl, t_symbol *s, int argc, t_atom *argv) {
	t_note *x = (t_note *)pd_new(cl);
	outlet_new(&x->x_obj, &s_float);
	inlet_new(&x->x_obj, &x->x_obj.ob_pd, &s_float, gensym("ref"));
	inlet_new(&x->x_obj, &x->x_obj.ob_pd, &s_float, gensym("tet"));

	t_float ref=440, tet=12;
	switch (argc)
	{	case 2: tet = atom_getfloat(argv+1);
		case 1: ref = atom_getfloat(argv);   }
	x->x_ref=ref, x->x_tet=tet;

	return x;
}
