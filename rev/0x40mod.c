#include "rev.h"

/* -------------------------- reverse mod -------------------------- */

static t_class *rmod_class;

static void rmod_bang(t_rev *x) {
	int n1 = x->x_f1, result;
	if (n1 < 0) n1 = -n1;
	else if (!n1) n1 = 1;
	result = (int)x->x_f2 % n1;
	if (result < 0) result += n1;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void *rmod_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rmod_class, rmod_bang, s, ac, av));
}

void setup_0x40mod(void) {
	rmod_class = class_new(gensym("@mod"),
		(t_newmethod)rmod_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rmod_class, rmod_bang);
	class_addfloat(rmod_class, rev_float);
	class_addmethod(rmod_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rmod_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rmod_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rmod_class, gensym("revbinops"));
}
