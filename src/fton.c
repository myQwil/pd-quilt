#define SEMI(x) (x)->tet / M_LN2
#define BASE(x) exp(M_LN2 * 69. / (x)->tet) / (x)->ref

#include "tone.h"

/* -------------------------- fton -------------------------- */
static t_class *fton_class;

static void fton_float(t_tone *x, t_float f) {
	outlet_float(x->obj.ob_outlet, fton(&x->note, f));
}

static void *fton_new(t_symbol *s, int argc, t_atom *argv) {
	return tone_new(fton_class, s, argc, argv);
}

void fton_setup(void) {
	fton_class = class_tone(gensym("fton"), (t_newmethod)fton_new);
	class_addfloat(fton_class, fton_float);
	class_sethelpsymbol(fton_class, gensym("tone"));
}
