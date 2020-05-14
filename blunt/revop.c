#include "bop.h"
#include <math.h>

/* --------------------------------------------------------------- */
/*                   reverse arithmetics                           */
/* --------------------------------------------------------------- */

/* --------------------- subtraction ----------------------------- */
static t_class *rminus_class;

static void rminus_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f2 - x->x_f1);
}

static void *rminus_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rminus_class, rminus_bang, s, ac, av));
}

/* --------------------- log ------------------------------------- */
static t_class *rlog_class;

static void rlog_bang(t_bop *x) {
	t_float r;
	if (x->x_f2 <= 0)
		r = -1000;
	else if (x->x_f1 <= 0)
		r = log(x->x_f2);
	else r = log(x->x_f2) / log(x->x_f1);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *rlog_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rlog_class, rlog_bang, s, ac, av));
}

/* --------------------- pow ------------------------------------- */
static t_class *rpow_class;

static void rpow_bang(t_bop *x) {
	t_float r = (x->x_f2 == 0 && x->x_f1 < 0) ||
		(x->x_f2 < 0 && (x->x_f1 - (int)x->x_f1) != 0) ?
			0 : pow(x->x_f2, x->x_f1);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *rpow_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rpow_class, rpow_bang, s, ac, av));
}

/* --------------------- << -------------------------------------- */
static t_class *rls_class;

static void rls_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f2)) << (int)(x->x_f1));
}

static void *rls_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rls_class, rls_bang, s, ac, av));
}

/* --------------------- >> -------------------------------------- */
static t_class *rrs_class;

static void rrs_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f2)) >> (int)(x->x_f1));
}

static void *rrs_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rrs_class, rrs_bang, s, ac, av));
}

/* --------------------- % --------------------------------------- */
static t_class *rpc_class;

static void rpc_bang(t_bop *x) {
	int n1 = x->x_f1;
		/* apparently "%" raises an exception for INT_MIN and -1 */
	if (n1 == -1)
		outlet_float(x->x_obj.ob_outlet, 0);
	else outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f2)) % (n1 ? n1 : 1));
}

static void *rpc_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rpc_class, rpc_bang, s, ac, av));
}

/* --------------------- division -------------------------------- */
static t_class *rdiv_class;

static void rdiv_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 != 0 ? x->x_f2 / x->x_f1 : 0));
}

static void *rdiv_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rdiv_class, rdiv_bang, s, ac, av));
}

/* --------------------- mod ------------------------------------- */
static t_class *rmod_class;

static void rmod_bang(t_bop *x) {
	int n1 = x->x_f1, result;
	if (n1 < 0) n1 = -n1;
	else if (!n1) n1 = 1;
	result = (int)x->x_f2 % n1;
	if (result < 0) result += n1;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void *rmod_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rmod_class, rmod_bang, s, ac, av));
}

/* --------------------- div ------------------------------------- */
static t_class *rdivm_class;

static void rdivm_bang(t_bop *x) {
	int n2 = x->x_f2, n1 = x->x_f1, result;
	if (n1 < 0) n1 = -n1;
	else if (!n1) n1 = 1;
	if (n2 < 0) n2 -= (n1-1);
	result = n2 / n1;
	outlet_float(x->x_obj.ob_outlet, result);
}

static void *rdivm_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(rdivm_class, rdivm_bang, s, ac, av));
}

void revop_setup(void) {
	rminus_class = class_new(gensym("@-"), (t_newmethod)rminus_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rminus_class, rminus_bang);

	rlog_class = class_new(gensym("@log"), (t_newmethod)rlog_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rlog_class, rlog_bang);

	rpow_class = class_new(gensym("@pow"), (t_newmethod)rpow_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rpow_class, rpow_bang);

	rls_class = class_new(gensym("@<<"), (t_newmethod)rls_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rls_class, rls_bang);

	rrs_class = class_new(gensym("@>>"), (t_newmethod)rrs_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rrs_class, rrs_bang);

	rpc_class = class_new(gensym("@%"), (t_newmethod)rpc_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rpc_class, rpc_bang);

	rdiv_class = class_new(gensym("@/"), (t_newmethod)rdiv_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rdiv_class, rdiv_bang);

	rmod_class = class_new(gensym("@mod"), (t_newmethod)rmod_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rmod_class, rmod_bang);

	rdivm_class = class_new(gensym("@div"), (t_newmethod)rdivm_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(rdivm_class, rdivm_bang);

	t_class *revs[] =
	{	rminus_class, rlog_class, rpow_class, rls_class, rrs_class,
		rpc_class, rdiv_class, rmod_class, rdivm_class   };

	int i = sizeof(revs) / sizeof*(revs);
	t_symbol *rev_sym = gensym("revbinops");
	while (i--)
	{	class_addfloat(revs[i], bop_float);
		class_addmethod(revs[i], (t_method)bop_f2,
			gensym("f2"), A_FLOAT, 0);
		class_addmethod(revs[i], (t_method)bop_skip,
			gensym("."), A_GIMME, 0);
		class_addmethod(revs[i], (t_method)bop_loadbang,
			gensym("loadbang"), A_DEFFLOAT, 0);
		class_sethelpsymbol(revs[i], rev_sym);   }
}