#include "tone.h"

/* -------------------------- ntof -------------------------- */
static t_class *ntof_class;

static void ntof_float(t_tone *x, t_float f) {
	outlet_float(x->obj.ob_outlet, ntof(&x->note, f));
}

static void *ntof_new(t_symbol *s, int argc, t_atom *argv) {
	return tone_new(ntof_class, s, argc, argv);
}

void ntof_setup(void) {
	ntof_class = class_tone(gensym("ntof"), (t_newmethod)ntof_new);
	class_addfloat(ntof_class, ntof_float);
	class_sethelpsymbol(ntof_class, gensym("tone"));
}
