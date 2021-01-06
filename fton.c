#define BASE(x) 1. / ((x)->ref * pow(2, -69 / (x)->tet))
#define SEMI(x) 1. / (log(2) / (x)->tet)

#include "ntof.h"

/* -------------------------- fton -------------------------- */
static t_class *fton_class;

static void fton_float(t_ntof *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, fton(&x->note, f));
}

static void *fton_new(t_symbol *s, int argc, t_atom *argv) {
	return (new_ntof(fton_class, argc, argv));
}

void fton_setup(void) {
	fton_class = setup_ntof(gensym("fton"), (t_newmethod)fton_new);
	class_addfloat(fton_class, fton_float);
	class_sethelpsymbol(fton_class, gensym("ntof"));
}
