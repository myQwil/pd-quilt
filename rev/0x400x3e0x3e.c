#include "rev.h"

/* -------------------------- reverse >> -------------------------- */

static t_class *rrs_class;

static void rrs_bang(t_rev *x) {
	outlet_float(x->x_obj.ob_outlet, (int)x->x_f2 >> (int)x->x_f1);
}

static void *rrs_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rrs_class, rrs_bang, s, ac, av));
}

void setup_0x400x3e0x3e(void) {
	rrs_class = class_new(gensym("@>>"),
		(t_newmethod)rrs_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rrs_class, rrs_bang);
	class_addfloat(rrs_class, rev_float);
	class_addmethod(rrs_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rrs_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rrs_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rrs_class, gensym("revbinops"));
}
