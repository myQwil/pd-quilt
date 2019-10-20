#include "rev.h"

/* -------------------------- reverse div -------------------------- */

static t_class *rdivm_class;

static void rdivm_bang(t_rev *x) {
	int n2 = x->x_f2, n1 = x->x_f1, result;
	if (n1 < 0) n1 = -n1;
	else if (!n1) n1 = 1;
	if (n2 < 0) n2 -= (n1-1);
	result = n2 / n1;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void *rdivm_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rdivm_class, rdivm_bang, s, ac, av));
}

void setup_0x40div(void) {
	rdivm_class = class_new(gensym("@div"),
		(t_newmethod)rdivm_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rdivm_class, rdivm_bang);
	class_addfloat(rdivm_class, rev_float);
	class_addmethod(rdivm_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rdivm_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rdivm_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rdivm_class, gensym("revbinops"));
}
