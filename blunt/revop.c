#include "bop.h"
#include "blunt.h"

/* --------------------------------------------------------------- */
/*                   reverse arithmetics                           */
/* --------------------------------------------------------------- */

/* --------------------- subtraction ----------------------------- */
static t_class *rminus_class;

static void rminus_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_minus(x->x_f2, x->x_f1));
}

static void *rminus_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rminus_class, s, ac, av));
}

/* --------------------- division -------------------------------- */
static t_class *rdiv_class;

static void rdiv_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_div(x->x_f2, x->x_f1));
}

static void *rdiv_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rdiv_class, s, ac, av));
}

/* --------------------- log ------------------------------------- */
static t_class *rlog_class;

static void rlog_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_log(x->x_f2, x->x_f1));
}

static void *rlog_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rlog_class, s, ac, av));
}

/* --------------------- pow ------------------------------------- */
static t_class *rpow_class;

static void rpow_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_pow(x->x_f2, x->x_f1));
}

static void *rpow_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rpow_class, s, ac, av));
}

/* --------------------- << -------------------------------------- */
static t_class *rls_class;

static void rls_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_ls(x->x_f2, x->x_f1));
}

static void *rls_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rls_class, s, ac, av));
}

/* --------------------- >> -------------------------------------- */
static t_class *rrs_class;

static void rrs_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_rs(x->x_f2, x->x_f1));
}

static void *rrs_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rrs_class, s, ac, av));
}

/* --------------------- % --------------------------------------- */
static t_class *rpc_class;

static void rpc_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_pc(x->x_f2, x->x_f1));
}

static void *rpc_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rpc_class, s, ac, av));
}

/* --------------------- mod ------------------------------------- */
static t_class *rmod_class;

static void rmod_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_mod(x->x_f2, x->x_f1));
}

static void *rmod_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rmod_class, s, ac, av));
}

/* --------------------- div ------------------------------------- */
static t_class *rdivm_class;

static void rdivm_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, blunt_divm(x->x_f2, x->x_f1));
}

static void *rdivm_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rdivm_class, s, ac, av));
}

void revop_setup(void) {
	rminus_class = class_new(gensym("@-"), (t_newmethod)rminus_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rdiv_class = class_new(gensym("@/"), (t_newmethod)rdiv_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rlog_class = class_new(gensym("@log"), (t_newmethod)rlog_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rpow_class = class_new(gensym("@pow"), (t_newmethod)rpow_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rls_class = class_new(gensym("@<<"), (t_newmethod)rls_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rrs_class = class_new(gensym("@>>"), (t_newmethod)rrs_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rpc_class = class_new(gensym("@%"), (t_newmethod)rpc_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rmod_class = class_new(gensym("@mod"), (t_newmethod)rmod_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	rdivm_class = class_new(gensym("@div"), (t_newmethod)rdivm_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);

	t_class *revs[] =
	{	rminus_class, rdiv_class, rlog_class, rpow_class,
		rls_class, rrs_class, rpc_class, rmod_class, rdivm_class   };

	t_bopmethod rbangs[] =
	{	rminus_bang, rdiv_bang, rlog_bang, rpow_bang,
		rls_bang, rrs_bang, rpc_bang, rmod_bang, rdivm_bang   };

	int i = sizeof(revs) / sizeof*(revs);
	t_symbol *rev_sym = gensym("revbinops");
	while (i--)
	{	class_addbang(revs[i], rbangs[i]);
		class_addfloat(revs[i], bop_float);
		class_addmethod(revs[i], (t_method)bop_f2,
			gensym("f2"), A_FLOAT, 0);
		class_addmethod(revs[i], (t_method)bop_skip,
			gensym("."), A_GIMME, 0);
		class_addmethod(revs[i], (t_method)bop_loadbang,
			gensym("loadbang"), A_DEFFLOAT, 0);
		class_sethelpsymbol(revs[i], rev_sym);   }
}