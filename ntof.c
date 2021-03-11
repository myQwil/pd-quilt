#include "ntof.h"

/* -------------------------- ntof -------------------------- */
static t_class *ntof_class;

static void ntof_float(t_ntof *x ,t_float f) {
	outlet_float(x->obj.ob_outlet ,ntof(&x->note ,f));
}

static void *ntof_new(t_symbol *s ,int argc ,t_atom *argv) {
	return (new_ntof(ntof_class ,argc ,argv));
}

void ntof_setup(void) {
	ntof_class = setup_ntof(gensym("ntof") ,(t_newmethod)ntof_new);
	class_addfloat(ntof_class ,ntof_float);
}
