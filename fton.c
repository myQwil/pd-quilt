#include "note.h"

/* -------------------------- fton -------------------------- */
static t_class *fton_class;

static t_float fton(t_float f, double root, double semi) {
	return (semi * log(root*f));
}

static void fton_ref(t_note *x, t_floatarg f) {
	x->x_ref = f;
	x->x_rt = 1. / note_root(x);
}

static void fton_tet(t_note *x, t_floatarg f) {
	x->x_tet = f;
	x->x_rt = 1. / note_root(x);
	x->x_st = 1. / note_semi(x);
}

static void fton_float(t_note *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, fton(f, x->x_rt, x->x_st));
}

static void *fton_new(t_symbol *s, int argc, t_atom *argv) {
	t_note *x = note_new(fton_class, s, argc, argv);
	x->x_rt = 1. / note_root(x);
	x->x_st = 1. / note_semi(x);
	return (x);
}

void fton_setup(void) {	
	fton_class = class_new(gensym("fton"),
		(t_newmethod)fton_new, 0,
		sizeof(t_note), 0,
		A_GIMME, 0);
	class_addfloat(fton_class, fton_float);
	class_sethelpsymbol(fton_class, gensym("ntof"));
	class_addmethod(fton_class, (t_method)fton_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(fton_class, (t_method)fton_tet,
		gensym("tet"), A_FLOAT, 0);
}
