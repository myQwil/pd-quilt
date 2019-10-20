#include "rev.h"

/* -------------------------- reverse subtraction -------------------------- */

static t_class *rminus_class;

static void rminus_bang(t_rev *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f2 - x->x_f1);
}

static void *rminus_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rminus_class, rminus_bang, s, ac, av));
}

void setup_0x400x2d(void) {
	rminus_class = class_new(gensym("@-"),
		(t_newmethod)rminus_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rminus_class, rminus_bang);
	class_addfloat(rminus_class, rev_float);
	class_addmethod(rminus_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rminus_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rminus_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rminus_class, gensym("revbinops"));
}
