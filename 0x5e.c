#include "rev/rev.h"

/* -------------------------- XOR -------------------------- */

static t_class *xor_class;

static void xor_bang(t_rev *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f1 ^ (int)x->x_f2);
}

static void *xor_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(xor_class, xor_bang, s, ac, av));
}

void setup_0x5e(void) {
	xor_class = class_new(gensym("^"),
		(t_newmethod)xor_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(xor_class, xor_bang);
	class_addfloat(xor_class, rev_float);
	class_addmethod(xor_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(xor_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(xor_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(xor_class, gensym("0x5e"));
}
