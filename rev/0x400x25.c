#include "rev.h"

/* -------------------------- reverse % -------------------------- */

static t_class *rpc_class;

static void rpc_bang(t_rev *x) {
    int n1 = x->x_f1;
        /* apparently "%" raises an exception for INT_MIN and -1 */
    if (n1 == -1)
        outlet_float(x->x_obj.ob_outlet, 0);
    else outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f2)) % (n1 ? n1 : 1));
}

static void *rpc_new(t_symbol *s, int ac, t_atom *av) {
	return (rev_new(rpc_class, rpc_bang, s, ac, av));
}

void setup_0x400x25(void) {
	rpc_class = class_new(gensym("@%"),
		(t_newmethod)rpc_new, 0,
		sizeof(t_rev), 0,
		A_GIMME, 0);
	class_addbang(rpc_class, rpc_bang);
	class_addfloat(rpc_class, rev_float);
	class_addmethod(rpc_class, (t_method)rev_f2,
		gensym("f2"), A_FLOAT, 0);
	class_addmethod(rpc_class, (t_method)rev_skip,
		gensym("."), A_GIMME, 0);
	class_addmethod(rpc_class, (t_method)rev_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_sethelpsymbol(rpc_class, gensym("revbinops"));
}
