#include "note.h"

/* -------------------------- ntof -------------------------- */
static t_class *ntof_class;

static t_float ntof(t_float f, double root, double semi) {
	return (root * exp(semi*f));
}

static void ntof_ref(t_note *x, t_floatarg f) {
	x->x_ref = f;
	x->x_rt = note_root(x);
}

static void ntof_tet(t_note *x, t_floatarg f) {
	x->x_tet = f;
	x->x_rt = note_root(x);
	x->x_st = note_semi(x);
}

static void ntof_float(t_note *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ntof(f, x->x_rt, x->x_st));
}

static void *ntof_new(t_symbol *s, int argc, t_atom *argv) {
	t_note *x = note_new(ntof_class, s, argc, argv);
	x->x_rt = note_root(x);
	x->x_st = note_semi(x);
	return (x);
}

void ntof_setup(void) {
	ntof_class = class_new(gensym("ntof"),
		(t_newmethod)ntof_new, 0,
		sizeof(t_note), 0,
		A_GIMME, 0);
	class_addfloat(ntof_class, ntof_float);
	class_addmethod(ntof_class, (t_method)ntof_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(ntof_class, (t_method)ntof_tet,
		gensym("tet"), A_FLOAT, 0);
}
