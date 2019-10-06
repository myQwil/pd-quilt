#include "m_pd.h"
#include <string.h>
#include <stdlib.h>

#ifdef _MSC_VER
#define strtof(a,b) _atoldbl(a,*b)
#endif


/* --------------------------------------------------------------- */
/*                           connectives                           */
/* --------------------------------------------------------------- */

/* --------------------- int ------------------------------------- */
static t_class *pdint_class;

typedef struct _pdint {
	t_object x_obj;
	t_float x_f;
	int x_lb;
} t_pdint;

static void *pdint_new(t_symbol *s, int ac, t_atom *av) {
	t_pdint *x = (t_pdint *)pd_new(pdint_class);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f);
	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->x_f = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] != '!') return 0;
			x->x_f = strtof(c, NULL);
			x->x_lb = 1;   }   }
	return (x);
}

static void pdint_bang(t_pdint *x) {
	outlet_float(x->x_obj.ob_outlet, (t_float)(int64_t)(x->x_f));
}

static void pdint_loadbang(t_pdint *x, t_floatarg action) {
	if (!action && x->x_lb) pdint_bang(x);
}

static void pdint_float(t_pdint *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (t_float)(int64_t)(x->x_f = f));
}

static void pdint_send(t_pdint *x, t_symbol *s) {
	if (s->s_thing)
		pd_float(s->s_thing, (t_float)(int64_t)x->x_f);
	else pd_error(x, "%s: no such object", s->s_name);
}

/* --------------------- float ----------------------------------- */
static t_class *pdfloat_class;

typedef struct _pdfloat {
	t_object x_obj;
	t_float x_f;
	int x_lb
} t_pdfloat;

	/* "float," "symbol," and "bang" are special because
	they're created by short-circuited messages to the "new"
	object which are handled specially in pd_typedmess(). */

static void *pdfloat_new(t_pd *dummy, t_float f) {
	t_pdfloat *x = (t_pdfloat *)pd_new(pdfloat_class);
	x->x_f = f;
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f);
	pd_this->pd_newest = &x->x_obj.ob_pd;
	return (x);
}

static void *pdfloat_new2(t_symbol *s, int ac, t_atom *av) {
	t_pdfloat *x = (t_pdfloat *)pd_new(pdfloat_class);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f);
	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->x_f = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] != '!') return 0;
			x->x_f = strtof(c, NULL);
			x->x_lb = 1;   }   }
	pd_this->pd_newest = &x->x_obj.ob_pd;
	return (x);
}

static void pdfloat_bang(t_pdfloat *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f);
}

static void pdfloat_loadbang(t_pdfloat *x, t_floatarg action) {
	if (!action && x->x_lb) pdfloat_bang(x);
}

static void pdfloat_float(t_pdfloat *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, x->x_f = f);
}

static void pdfloat_symbol(t_pdfloat *x, t_symbol *s) {
	t_float f = 0.0f;
	char *str_end = NULL;
	f = strtof(s->s_name, &str_end);
	if (f == 0 && s->s_name == str_end)
		pd_error(x, "Couldn't convert %s to float.", s->s_name);
	else outlet_float(x->x_obj.ob_outlet, x->x_f = f);
}

static void pdfloat_send(t_pdfloat *x, t_symbol *s) {
	if (s->s_thing)
		pd_float(s->s_thing, x->x_f);
	else pd_error(x, "%s: no such object", s->s_name);
}


/* --------------------------------------------------------------- */
/*                           arithmetics                           */
/* --------------------------------------------------------------- */

typedef struct _binop {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
	int x_lb;
} t_binop;

static void *binop_new(t_class *binopclass, t_symbol *s, int ac, t_atom *av) {
	t_binop *x = (t_binop *)pd_new(binopclass);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f2);

	if (ac>1 && av->a_type == A_FLOAT)
	{	x->x_f1 = av->a_w.w_float;
		av++;   }
	else x->x_f1 = 0;

	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->x_f2 = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] != '!') return 0;
			x->x_f2 = strtof(c, NULL);
			x->x_lb = 1;   }   }

	return (x);
}

/* --------------------- binop1:  +, -, *, / --------------------- */

/* --------------------- addition -------------------------------- */

static t_class *binop1_plus_class;

static void *binop1_plus_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop1_plus_class, s, ac, av));
}

static void binop1_plus_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 + x->x_f2);
}

static void binop1_plus_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) + x->x_f2);
}

static void binop1_plus_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop1_plus_bang(x);
}

/* --------------------- subtraction ----------------------------- */

static t_class *binop1_minus_class;

static void *binop1_minus_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop1_minus_class, s, ac, av));
}

static void binop1_minus_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 - x->x_f2);
}

static void binop1_minus_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) - x->x_f2);
}

static void binop1_minus_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop1_minus_bang(x);
}

/* --------------------- multiplication -------------------------- */

static t_class *binop1_times_class;

static void *binop1_times_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop1_times_class, s, ac, av));
}

static void binop1_times_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 * x->x_f2);
}

static void binop1_times_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) * x->x_f2);
}

static void binop1_times_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop1_times_bang(x);
}

/* --------------------- division -------------------------------- */

static t_class *binop1_div_class;

static void *binop1_div_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop1_div_class, s, ac, av));
}

static void binop1_div_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f2 != 0 ? x->x_f1 / x->x_f2 : 0));
}

static void binop1_div_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f2 != 0 ? x->x_f1 / x->x_f2 : 0));
}

static void binop1_div_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop1_div_bang(x);
}

/* --------------------- pow ------------------------------------- */

static t_class *binop1_pow_class;

static void *binop1_pow_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop1_pow_class, s, ac, av));
}

static void binop1_pow_bang(t_binop *x) {
	t_float r = (x->x_f1 == 0 && x->x_f2 < 0) ||
		(x->x_f1 < 0 && (x->x_f2 - (int)x->x_f2) != 0) ?
			0 : pow(x->x_f1, x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void binop1_pow_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	binop1_pow_bang(x);
}

static void binop1_pow_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop1_pow_bang(x);
}

/* --------------------- max ------------------------------------- */

static t_class *binop1_max_class;

static void *binop1_max_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop1_max_class, s, ac, av));
}

static void binop1_max_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > x->x_f2 ? x->x_f1 : x->x_f2));
}

static void binop1_max_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > x->x_f2 ? x->x_f1 : x->x_f2));
}

static void binop1_max_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop1_max_bang(x);
}

/* --------------------- min ------------------------------------- */

static t_class *binop1_min_class;

static void *binop1_min_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop1_min_class, s, ac, av));
}

static void binop1_min_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void binop1_min_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void binop1_min_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop1_min_bang(x);
}

/* --------------- binop2: ==, !=, >, <, >=, <=. ----------------- */

/* --------------------- == -------------------------------------- */

static t_class *binop2_ee_class;

static void *binop2_ee_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop2_ee_class, s, ac, av));
}

static void binop2_ee_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 == x->x_f2);
}

static void binop2_ee_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) == x->x_f2);
}

static void binop2_ee_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop2_ee_bang(x);
}

/* --------------------- != -------------------------------------- */

static t_class *binop2_ne_class;

static void *binop2_ne_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop2_ne_class, s, ac, av));
}

static void binop2_ne_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void binop2_ne_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) != x->x_f2);
}

static void binop2_ne_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop2_ne_bang(x);
}

/* --------------------- > --------------------------------------- */

static t_class *binop2_gt_class;

static void *binop2_gt_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop2_gt_class, s, ac, av));
}

static void binop2_gt_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 > x->x_f2);
}

static void binop2_gt_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) > x->x_f2);
}

static void binop2_gt_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop2_gt_bang(x);
}

/* --------------------- < --------------------------------------- */

static t_class *binop2_lt_class;

static void *binop2_lt_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop2_lt_class, s, ac, av));
}

static void binop2_lt_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 < x->x_f2);
}

static void binop2_lt_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) < x->x_f2);
}

static void binop2_lt_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop2_lt_bang(x);
}

/* --------------------- >= -------------------------------------- */

static t_class *binop2_ge_class;

static void *binop2_ge_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop2_ge_class, s, ac, av));
}

static void binop2_ge_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 >= x->x_f2);
}

static void binop2_ge_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) >= x->x_f2);
}

static void binop2_ge_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop2_ge_bang(x);
}

/* --------------------- <= -------------------------------------- */

static t_class *binop2_le_class;

static void *binop2_le_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop2_le_class, s, ac, av));
}

static void binop2_le_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 <= x->x_f2);
}

static void binop2_le_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (x->x_f1 = f) <= x->x_f2);
}

static void binop2_le_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop2_le_bang(x);
}

/* ------- binop3: &, |, &&, ||, <<, >>, %, mod, div ------------- */

/* --------------------- & --------------------------------------- */

static t_class *binop3_ba_class;

static void *binop3_ba_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_ba_class, s, ac, av));
}

static void binop3_ba_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) & (int)(x->x_f2));
}

static void binop3_ba_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1 = f)) & (int)(x->x_f2));
}

static void binop3_ba_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_ba_bang(x);
}

/* --------------------- && -------------------------------------- */

static t_class *binop3_la_class;

static void *binop3_la_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_la_class, s, ac, av));
}

static void binop3_la_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) && (int)(x->x_f2));
}

static void binop3_la_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1 = f)) && (int)(x->x_f2));
}

static void binop3_la_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_la_bang(x);
}

/* --------------------- | --------------------------------------- */

static t_class *binop3_bo_class;

static void *binop3_bo_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_bo_class, s, ac, av));
}

static void binop3_bo_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) | (int)(x->x_f2));
}

static void binop3_bo_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1 = f)) | (int)(x->x_f2));
}

static void binop3_bo_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_bo_bang(x);
}

/* --------------------- || -------------------------------------- */

static t_class *binop3_lo_class;

static void *binop3_lo_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_lo_class, s, ac, av));
}

static void binop3_lo_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) || (int)(x->x_f2));
}

static void binop3_lo_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1 = f)) || (int)(x->x_f2));
}

static void binop3_lo_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_lo_bang(x);
}

/* --------------------- << -------------------------------------- */

static t_class *binop3_ls_class;

static void *binop3_ls_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_ls_class, s, ac, av));
}

static void binop3_ls_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) << (int)(x->x_f2));
}

static void binop3_ls_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1 = f)) << (int)(x->x_f2));
}

static void binop3_ls_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_ls_bang(x);
}

/* --------------------- >> -------------------------------------- */

static t_class *binop3_rs_class;

static void *binop3_rs_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_rs_class, s, ac, av));
}

static void binop3_rs_bang(t_binop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) >> (int)(x->x_f2));
}

static void binop3_rs_float(t_binop *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1 = f)) >> (int)(x->x_f2));
}

static void binop3_rs_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_rs_bang(x);
}

/* --------------------- % --------------------------------------- */

static t_class *binop3_pc_class;

static void *binop3_pc_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_pc_class, s, ac, av));
}

static void binop3_pc_bang(t_binop *x) {
	int n2 = x->x_f2;
		/* apparently "%" raises an exception for INT_MIN and -1 */
	if (n2 == -1)
		outlet_float(x->x_obj.ob_outlet, 0);
	else outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) % (n2 ? n2 : 1));
}

static void binop3_pc_float(t_binop *x, t_float f) {
	int n2 = x->x_f2;
	if (n2 == -1)
		outlet_float(x->x_obj.ob_outlet, 0);
	else outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1 = f)) % (n2 ? n2 : 1));
}

static void binop3_pc_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_pc_bang(x);
}

/* --------------------- mod ------------------------------------- */

static t_class *binop3_mod_class;

static void *binop3_mod_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_mod_class, s, ac, av));
}

static void binop3_mod_bang(t_binop *x) {
	int n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	result = ((int)(x->x_f1)) % n2;
	if (result < 0) result += n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void binop3_mod_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	binop3_mod_bang(x);
}

static void binop3_mod_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_mod_bang(x);
}

/* --------------------- div ------------------------------------- */

static t_class *binop3_div_class;

static void *binop3_div_new(t_symbol *s, int ac, t_atom *av) {
	return (binop_new(binop3_div_class, s, ac, av));
}

static void binop3_div_bang(t_binop *x) {
	int n1 = x->x_f1, n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void binop3_div_float(t_binop *x, t_float f) {
	x->x_f1 = f;
	binop3_div_bang(x);
}

static void binop3_div_loadbang(t_binop *x, t_floatarg action) {
	if (!action && x->x_lb) binop3_div_bang(x);
}


void blunt_setup(void) {

	post("Blunt! 0.1.0");

		/* ---------------- arithmetic --------------------- */

	pdint_class = class_new(gensym("int"), (t_newmethod)pdint_new, 0,
		sizeof(t_pdint), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)pdint_new, gensym("i"), A_GIMME, 0);
	class_addmethod(pdint_class, (t_method)pdint_send, gensym("send"),
		A_SYMBOL, 0);
	class_addbang(pdint_class, pdint_bang);
	class_addfloat(pdint_class, pdint_float);
	class_addmethod(pdint_class, (t_method)pdint_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	pdfloat_class = class_new(gensym("float"), (t_newmethod)pdfloat_new, 0,
		sizeof(t_pdfloat), 0, A_FLOAT, 0);
	class_addcreator((t_newmethod)pdfloat_new2, gensym("f"), A_GIMME, 0);
	class_addmethod(pdfloat_class, (t_method)pdfloat_send, gensym("send"),
		A_SYMBOL, 0);
	class_addbang(pdfloat_class, pdfloat_bang);
	class_addfloat(pdfloat_class, (t_method)pdfloat_float);
	class_addsymbol(pdfloat_class, (t_method)pdfloat_symbol);
	class_addmethod(pdfloat_class, (t_method)pdfloat_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

		/* ------------------ binop1 ----------------------- */

	t_symbol *binop1_sym = gensym("operators");
	t_symbol *binop23_sym = gensym("otherbinops");

	binop1_plus_class = class_new(gensym("+"), (t_newmethod)binop1_plus_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop1_plus_class, binop1_plus_bang);
	class_addfloat(binop1_plus_class, (t_method)binop1_plus_float);
	class_sethelpsymbol(binop1_plus_class, binop1_sym);
	class_addmethod(binop1_plus_class, (t_method)binop1_plus_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop1_minus_class = class_new(gensym("-"),
		(t_newmethod)binop1_minus_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop1_minus_class, binop1_minus_bang);
	class_addfloat(binop1_minus_class, (t_method)binop1_minus_float);
	class_sethelpsymbol(binop1_minus_class, binop1_sym);
	class_addmethod(binop1_minus_class, (t_method)binop1_minus_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop1_times_class = class_new(gensym("*"),
		(t_newmethod)binop1_times_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop1_times_class, binop1_times_bang);
	class_addfloat(binop1_times_class, (t_method)binop1_times_float);
	class_sethelpsymbol(binop1_times_class, binop1_sym);
	class_addmethod(binop1_times_class, (t_method)binop1_times_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop1_div_class = class_new(gensym("/"),
		(t_newmethod)binop1_div_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop1_div_class, binop1_div_bang);
	class_addfloat(binop1_div_class, (t_method)binop1_div_float);
	class_sethelpsymbol(binop1_div_class, binop1_sym);
	class_addmethod(binop1_div_class, (t_method)binop1_div_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop1_pow_class = class_new(gensym("pow"),
		(t_newmethod)binop1_pow_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop1_pow_class, binop1_pow_bang);
	class_addfloat(binop1_pow_class, (t_method)binop1_pow_float);
	class_sethelpsymbol(binop1_pow_class, binop1_sym);
	class_addmethod(binop1_pow_class, (t_method)binop1_pow_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop1_max_class = class_new(gensym("max"),
		(t_newmethod)binop1_max_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop1_max_class, binop1_max_bang);
	class_addfloat(binop1_max_class, (t_method)binop1_max_float);
	class_sethelpsymbol(binop1_max_class, binop1_sym);
	class_addmethod(binop1_max_class, (t_method)binop1_max_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop1_min_class = class_new(gensym("min"),
		(t_newmethod)binop1_min_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop1_min_class, binop1_min_bang);
	class_addfloat(binop1_min_class, (t_method)binop1_min_float);
	class_sethelpsymbol(binop1_min_class, binop1_sym);
	class_addmethod(binop1_min_class, (t_method)binop1_min_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

		/* ------------------ binop2 ----------------------- */

	binop2_ee_class = class_new(gensym("=="), (t_newmethod)binop2_ee_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop2_ee_class, binop2_ee_bang);
	class_addfloat(binop2_ee_class, (t_method)binop2_ee_float);
	class_sethelpsymbol(binop2_ee_class, binop23_sym);
	class_addmethod(binop2_ee_class, (t_method)binop2_ee_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop2_ne_class = class_new(gensym("!="), (t_newmethod)binop2_ne_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop2_ne_class, binop2_ne_bang);
	class_addfloat(binop2_ne_class, (t_method)binop2_ne_float);
	class_sethelpsymbol(binop2_ne_class, binop23_sym);
	class_addmethod(binop2_ne_class, (t_method)binop2_ne_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop2_gt_class = class_new(gensym(">"), (t_newmethod)binop2_gt_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop2_gt_class, binop2_gt_bang);
	class_addfloat(binop2_gt_class, (t_method)binop2_gt_float);
	class_sethelpsymbol(binop2_gt_class, binop23_sym);
	class_addmethod(binop2_gt_class, (t_method)binop2_gt_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop2_lt_class = class_new(gensym("<"), (t_newmethod)binop2_lt_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop2_lt_class, binop2_lt_bang);
	class_addfloat(binop2_lt_class, (t_method)binop2_lt_float);
	class_sethelpsymbol(binop2_lt_class, binop23_sym);
	class_addmethod(binop2_lt_class, (t_method)binop2_lt_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop2_ge_class = class_new(gensym(">="), (t_newmethod)binop2_ge_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop2_ge_class, binop2_ge_bang);
	class_addfloat(binop2_ge_class, (t_method)binop2_ge_float);
	class_sethelpsymbol(binop2_ge_class, binop23_sym);
	class_addmethod(binop2_ge_class, (t_method)binop2_ge_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop2_le_class = class_new(gensym("<="), (t_newmethod)binop2_le_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop2_le_class, binop2_le_bang);
	class_addfloat(binop2_le_class, (t_method)binop2_le_float);
	class_sethelpsymbol(binop2_le_class, binop23_sym);
	class_addmethod(binop2_le_class, (t_method)binop2_le_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

		/* ------------------ binop3 ----------------------- */

	binop3_ba_class = class_new(gensym("&"), (t_newmethod)binop3_ba_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_ba_class, binop3_ba_bang);
	class_addfloat(binop3_ba_class, (t_method)binop3_ba_float);
	class_sethelpsymbol(binop3_ba_class, binop23_sym);
	class_addmethod(binop3_ba_class, (t_method)binop3_ba_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_la_class = class_new(gensym("&&"), (t_newmethod)binop3_la_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_la_class, binop3_la_bang);
	class_addfloat(binop3_la_class, (t_method)binop3_la_float);
	class_sethelpsymbol(binop3_la_class, binop23_sym);
	class_addmethod(binop3_la_class, (t_method)binop3_la_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_bo_class = class_new(gensym("|"), (t_newmethod)binop3_bo_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_bo_class, binop3_bo_bang);
	class_addfloat(binop3_bo_class, (t_method)binop3_bo_float);
	class_sethelpsymbol(binop3_bo_class, binop23_sym);
	class_addmethod(binop3_bo_class, (t_method)binop3_bo_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_lo_class = class_new(gensym("||"), (t_newmethod)binop3_lo_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_lo_class, binop3_lo_bang);
	class_addfloat(binop3_lo_class, (t_method)binop3_lo_float);
	class_sethelpsymbol(binop3_lo_class, binop23_sym);
	class_addmethod(binop3_lo_class, (t_method)binop3_lo_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_ls_class = class_new(gensym("<<"), (t_newmethod)binop3_ls_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_ls_class, binop3_ls_bang);
	class_addfloat(binop3_ls_class, (t_method)binop3_ls_float);
	class_sethelpsymbol(binop3_ls_class, binop23_sym);
	class_addmethod(binop3_ls_class, (t_method)binop3_ls_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_rs_class = class_new(gensym(">>"), (t_newmethod)binop3_rs_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_rs_class, binop3_rs_bang);
	class_addfloat(binop3_rs_class, (t_method)binop3_rs_float);
	class_sethelpsymbol(binop3_rs_class, binop23_sym);
	class_addmethod(binop3_rs_class, (t_method)binop3_rs_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_pc_class = class_new(gensym("%"), (t_newmethod)binop3_pc_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_pc_class, binop3_pc_bang);
	class_addfloat(binop3_pc_class, (t_method)binop3_pc_float);
	class_sethelpsymbol(binop3_pc_class, binop23_sym);
	class_addmethod(binop3_pc_class, (t_method)binop3_pc_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_mod_class = class_new(gensym("mod"), (t_newmethod)binop3_mod_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_mod_class, binop3_mod_bang);
	class_addfloat(binop3_mod_class, (t_method)binop3_mod_float);
	class_sethelpsymbol(binop3_mod_class, binop23_sym);
	class_addmethod(binop3_mod_class, (t_method)binop3_mod_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);

	binop3_div_class = class_new(gensym("div"), (t_newmethod)binop3_div_new, 0,
		sizeof(t_binop), 0, A_GIMME, 0);
	class_addbang(binop3_div_class, binop3_div_bang);
	class_addfloat(binop3_div_class, (t_method)binop3_div_float);
	class_sethelpsymbol(binop3_div_class, binop23_sym);
	class_addmethod(binop3_div_class, (t_method)binop3_div_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
}
