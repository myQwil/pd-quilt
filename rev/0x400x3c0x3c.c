#include "rev.h"

/* -------------------------- reverse << -------------------------- */

static t_class *rls_class;

static void rls_bang(t_rev *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 << (int)x->x_f1);
}

static void *rls_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rls_class, rls_bang, s, ac, av));
}

void setup_0x400x3c0x3c(void) {
	rls_class = class_new(gensym("@<<"),
		(t_newmethod)rls_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rls_class, rls_bang);
	class_addfloat(rls_class, rev_float);
	class_addmethod(rls_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rls_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rls_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rls_class, gensym("revbinops"));
}
