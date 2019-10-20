#include "rev.h"

/* -------------------------- reverse division -------------------------- */

static t_class *rdiv_class;

static void rdiv_bang(t_rev *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 != 0 ? x->x_f2 / x->x_f1 : 0));
}

static void *rdiv_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rdiv_class, rdiv_bang, s, ac, av));
}

void setup_0x400x2f(void) {
	rdiv_class = class_new(gensym("@/"),
		(t_newmethod)rdiv_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rdiv_class, rdiv_bang);
	class_addfloat(rdiv_class, rev_float);
	class_addmethod(rdiv_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rdiv_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rdiv_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rdiv_class, gensym("revbinops"));
}
