#include "rev.h"
#include <math.h>

/* -------------------------- reverse pow -------------------------- */

static t_class *rpow_class;

static void rpow_bang(t_rev *x) {
	t_float r = (x->x_f2 == 0 && x->x_f1 < 0) ||
		(x->x_f2 < 0 && (x->x_f1 - (int)x->x_f1) != 0) ?
			0 : pow(x->x_f2, x->x_f1);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *rpow_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rpow_class, rpow_bang, s, ac, av));
}

void setup_0x40pow(void) {
	rpow_class = class_new(gensym("@pow"),
		(t_newmethod)rpow_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rpow_class, rpow_bang);
	class_addfloat(rpow_class, rev_float);
	class_addmethod(rpow_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rpow_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rpow_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rpow_class, gensym("revbinops"));
}
