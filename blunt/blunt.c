#include "m_pd.h"
#include <string.h>
#include <stdlib.h>
#include <math.h>

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

static void pdint_float(t_pdint *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, (t_float)(int64_t)(x->x_f = f));
}

static void pdint_send(t_pdint *x, t_symbol *s) {
	if (s->s_thing)
		pd_float(s->s_thing, (t_float)(int64_t)x->x_f);
	else pd_error(x, "%s: no such object", s->s_name);
}

static void pdint_loadbang(t_pdint *x, t_floatarg action) {
	if (!action && x->x_lb) pdint_bang(x);
}

/* --------------------- float ----------------------------------- */
static t_class *pdfloat_class;

typedef struct _pdfloat {
	t_object x_obj;
	t_float x_f;
	int x_lb;
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

static void pdfloat_loadbang(t_pdfloat *x, t_floatarg action) {
	if (!action && x->x_lb) pdfloat_bang(x);
}

/* --------------------------------------------------------------- */
/*                           arithmetics                           */
/* --------------------------------------------------------------- */

typedef struct _blunt t_blunt;
typedef void (*t_bluntmethod)(t_blunt *x);

struct _blunt {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
	t_bluntmethod x_bang;
	int x_lb;
};

static void *blunt_new
(t_class *bluntclass, t_bluntmethod fn, t_symbol *s, int ac, t_atom *av) {
	t_blunt *x = (t_blunt *)pd_new(bluntclass);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f2);
	x->x_bang = fn;

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

static void blunt_float(t_blunt *x, t_float f) {
	x->x_f1 = f;
	x->x_bang(x);
}

static void blunt_f2(t_blunt *x, t_floatarg f) {
	x->x_f2 = f;
}

static void blunt_skip(t_blunt *x, t_symbol *s, int ac, t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
		x->x_f2 = av->a_w.w_float;
	x->x_bang(x);
}

static void blunt_loadbang(t_blunt *x, t_floatarg action) {
	if (!action && x->x_lb) x->x_bang(x);
}

/* --------------------- binop1:  +, -, *, / --------------------- */

/* --------------------- addition -------------------------------- */

static t_class *b1_plus_class;

static void b1_plus_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 + x->x_f2);
}

static void *b1_plus_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_plus_class, b1_plus_bang, s, ac, av));
}

/* --------------------- subtraction ----------------------------- */

static t_class *b1_minus_class;

static void b1_minus_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 - x->x_f2);
}

static void *b1_minus_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_minus_class, b1_minus_bang, s, ac, av));
}

/* --------------------- multiplication -------------------------- */

static t_class *b1_times_class;

static void b1_times_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 * x->x_f2);
}

static void *b1_times_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_times_class, b1_times_bang, s, ac, av));
}

/* --------------------- division -------------------------------- */

static t_class *b1_div_class;

static void b1_div_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f2 != 0 ? x->x_f1 / x->x_f2 : 0));
}

static void *b1_div_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_div_class, b1_div_bang, s, ac, av));
}

/* --------------------- log ------------------------------------- */

static t_class *b1_log_class;

static void b1_log_bang(t_blunt *x) {
    t_float r;
    if (x->x_f1 <= 0)
        r = -1000;
    else if (x->x_f2 <= 0)
        r = log(x->x_f1);
    else r = log(x->x_f1)/log(x->x_f2);
    outlet_float(x->x_obj.ob_outlet, r);
}

static void *b1_log_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_log_class, b1_log_bang, s, ac, av));
}

/* --------------------- pow ------------------------------------- */

static t_class *b1_pow_class;

static void b1_pow_bang(t_blunt *x) {
	t_float r = (x->x_f1 == 0 && x->x_f2 < 0) ||
		(x->x_f1 < 0 && (x->x_f2 - (int)x->x_f2) != 0) ?
			0 : pow(x->x_f1, x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *b1_pow_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_pow_class, b1_pow_bang, s, ac, av));
}

/* --------------------- max ------------------------------------- */

static t_class *b1_max_class;

static void b1_max_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > x->x_f2 ? x->x_f1 : x->x_f2));
}

static void *b1_max_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_max_class, b1_max_bang, s, ac, av));
}

/* --------------------- min ------------------------------------- */

static t_class *b1_min_class;

static void b1_min_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void *b1_min_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b1_min_class, b1_min_bang, s, ac, av));
}

/* --------------- binop2: ==, !=, >, <, >=, <=. ----------------- */

/* --------------------- == -------------------------------------- */

static t_class *b2_ee_class;

static void b2_ee_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 == x->x_f2);
}

static void *b2_ee_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b2_ee_class, b2_ee_bang, s, ac, av));
}

/* --------------------- != -------------------------------------- */

static t_class *b2_ne_class;

static void b2_ne_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void *b2_ne_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b2_ne_class, b2_ne_bang, s, ac, av));
}

/* --------------------- > --------------------------------------- */

static t_class *b2_gt_class;

static void b2_gt_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 > x->x_f2);
}

static void *b2_gt_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b2_gt_class, b2_gt_bang, s, ac, av));
}

/* --------------------- < --------------------------------------- */

static t_class *b2_lt_class;

static void b2_lt_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 < x->x_f2);
}

static void *b2_lt_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b2_lt_class, b2_lt_bang, s, ac, av));
}

/* --------------------- >= -------------------------------------- */

static t_class *b2_ge_class;

static void b2_ge_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 >= x->x_f2);
}

static void *b2_ge_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b2_ge_class, b2_ge_bang, s, ac, av));
}

/* --------------------- <= -------------------------------------- */

static t_class *b2_le_class;

static void b2_le_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 <= x->x_f2);
}

static void *b2_le_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b2_le_class, b2_le_bang, s, ac, av));
}

/* ------- binop3: &, |, &&, ||, <<, >>, %, mod, div ------------- */

/* --------------------- & --------------------------------------- */

static t_class *b3_ba_class;

static void b3_ba_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) & (int)(x->x_f2));
}

static void *b3_ba_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_ba_class, b3_ba_bang, s, ac, av));
}

/* --------------------- && -------------------------------------- */

static t_class *b3_la_class;

static void b3_la_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) && (int)(x->x_f2));
}

static void *b3_la_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_la_class, b3_la_bang, s, ac, av));
}

/* --------------------- | --------------------------------------- */

static t_class *b3_bo_class;

static void b3_bo_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) | (int)(x->x_f2));
}

static void *b3_bo_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_bo_class, b3_bo_bang, s, ac, av));
}

/* --------------------- || -------------------------------------- */

static t_class *b3_lo_class;

static void b3_lo_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) || (int)(x->x_f2));
}

static void *b3_lo_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_lo_class, b3_lo_bang, s, ac, av));
}

/* --------------------- << -------------------------------------- */

static t_class *b3_ls_class;

static void b3_ls_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) << (int)(x->x_f2));
}

static void *b3_ls_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_ls_class, b3_ls_bang, s, ac, av));
}

/* --------------------- >> -------------------------------------- */

static t_class *b3_rs_class;

static void b3_rs_bang(t_blunt *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) >> (int)(x->x_f2));
}

static void *b3_rs_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_rs_class, b3_rs_bang, s, ac, av));
}

/* --------------------- % --------------------------------------- */

static t_class *b3_pc_class;

static void b3_pc_bang(t_blunt *x) {
	int n2 = x->x_f2;
		/* apparently "%" raises an exception for INT_MIN and -1 */
	if (n2 == -1)
		outlet_float(x->x_obj.ob_outlet, 0);
	else outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) % (n2 ? n2 : 1));
}

static void *b3_pc_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_pc_class, b3_pc_bang, s, ac, av));
}

/* --------------------- mod ------------------------------------- */

static t_class *b3_mod_class;

static void b3_mod_bang(t_blunt *x) {
	int n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	result = ((int)(x->x_f1)) % n2;
	if (result < 0) result += n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void *b3_mod_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_mod_class, b3_mod_bang, s, ac, av));
}

/* --------------------- div ------------------------------------- */

static t_class *b3_div_class;

static void b3_div_bang(t_blunt *x) {
	int n1 = x->x_f1, n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void *b3_div_new(t_symbol *s, int ac, t_atom *av) {
	return (blunt_new(b3_div_class, b3_div_bang, s, ac, av));
}

void blunt_setup(void) {

	post("Blunt! 0.1.0");

		/* ---------------- connectives --------------------- */

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

	b1_plus_class = class_new(gensym("+"), (t_newmethod)b1_plus_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_plus_class, b1_plus_bang);

	b1_minus_class = class_new(gensym("-"), (t_newmethod)b1_minus_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_minus_class, b1_minus_bang);

	b1_times_class = class_new(gensym("*"), (t_newmethod)b1_times_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_times_class, b1_times_bang);

	b1_div_class = class_new(gensym("/"), (t_newmethod)b1_div_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_div_class, b1_div_bang);

	b1_log_class = class_new(gensym("log"), (t_newmethod)b1_log_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_log_class, b1_log_bang);

	b1_pow_class = class_new(gensym("pow"), (t_newmethod)b1_pow_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_pow_class, b1_pow_bang);

	b1_max_class = class_new(gensym("max"), (t_newmethod)b1_max_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_max_class, b1_max_bang);

	b1_min_class = class_new(gensym("min"), (t_newmethod)b1_min_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b1_min_class, b1_min_bang);

	t_class *b1s[] = {
		b1_plus_class, b1_minus_class, b1_times_class, b1_div_class,
		b1_log_class, b1_pow_class, b1_max_class, b1_min_class
	};
	int i = sizeof(b1s) / sizeof*(b1s);
	t_symbol *b1_sym = gensym("operators");
	while (i--) {
		class_addfloat(b1s[i], (t_method)blunt_float);
		class_addmethod(b1s[i], (t_method)blunt_f2,
			gensym("f2"), A_FLOAT, 0);
		class_addmethod(b1s[i], (t_method)blunt_skip,
			gensym("."), A_GIMME, 0);
		class_addmethod(b1s[i], (t_method)blunt_loadbang,
			gensym("loadbang"), A_DEFFLOAT, 0);
		class_sethelpsymbol(b1s[i], b1_sym);
	}

		/* ------------------ binop2 ----------------------- */

	b2_ee_class = class_new(gensym("=="), (t_newmethod)b2_ee_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b2_ee_class, b2_ee_bang);

	b2_ne_class = class_new(gensym("!="), (t_newmethod)b2_ne_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b2_ne_class, b2_ne_bang);

	b2_gt_class = class_new(gensym(">"), (t_newmethod)b2_gt_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b2_gt_class, b2_gt_bang);

	b2_lt_class = class_new(gensym("<"), (t_newmethod)b2_lt_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b2_lt_class, b2_lt_bang);

	b2_ge_class = class_new(gensym(">="), (t_newmethod)b2_ge_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b2_ge_class, b2_ge_bang);

	b2_le_class = class_new(gensym("<="), (t_newmethod)b2_le_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b2_le_class, b2_le_bang);

		/* ------------------ binop3 ----------------------- */

	b3_ba_class = class_new(gensym("&"), (t_newmethod)b3_ba_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_ba_class, b3_ba_bang);

	b3_la_class = class_new(gensym("&&"), (t_newmethod)b3_la_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_la_class, b3_la_bang);

	b3_bo_class = class_new(gensym("|"), (t_newmethod)b3_bo_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_bo_class, b3_bo_bang);

	b3_lo_class = class_new(gensym("||"), (t_newmethod)b3_lo_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_lo_class, b3_lo_bang);

	b3_ls_class = class_new(gensym("<<"), (t_newmethod)b3_ls_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_ls_class, b3_ls_bang);

	b3_rs_class = class_new(gensym(">>"), (t_newmethod)b3_rs_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_rs_class, b3_rs_bang);

	b3_pc_class = class_new(gensym("%"), (t_newmethod)b3_pc_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_pc_class, b3_pc_bang);

	b3_mod_class = class_new(gensym("mod"), (t_newmethod)b3_mod_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_mod_class, b3_mod_bang);

	b3_div_class = class_new(gensym("div"), (t_newmethod)b3_div_new, 0,
		sizeof(t_blunt), 0, A_GIMME, 0);
	class_addbang(b3_div_class, b3_div_bang);

	t_class *b23s[] = {
		b2_ee_class, b2_ne_class,
		b2_gt_class, b2_lt_class, b2_ge_class, b2_le_class,
		b3_ba_class, b3_la_class, b3_bo_class, b3_lo_class,
		b3_ls_class, b3_rs_class, b3_pc_class, b3_mod_class, b3_div_class
	};
	i = sizeof(b23s) / sizeof*(b23s);
	t_symbol *b23_sym = gensym("otherbinops");
	while (i--) {
		class_addfloat(b23s[i], (t_method)blunt_float);
		class_addmethod(b23s[i], (t_method)blunt_f2,
			gensym("f2"), A_FLOAT, 0);
		class_addmethod(b23s[i], (t_method)blunt_skip,
			gensym("."), A_GIMME, 0);
		class_addmethod(b23s[i], (t_method)blunt_loadbang,
			gensym("loadbang"), A_DEFFLOAT, 0);
		class_sethelpsymbol(b23s[i], b23_sym);
	}
}
