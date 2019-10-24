#include "bop.h"
#include <math.h>

void hotop_setup(void);
void revop_setup(void);

/* --------------------------------------------------------------- */
/*                           connectives                           */
/* --------------------------------------------------------------- */

typedef struct _num t_num;
typedef void (*t_nummethod)(t_num *x);

struct _num {
	t_object x_obj;
	t_float x_f;
	t_nummethod x_bang;
	int x_lb;
};

static void *num_new
(t_class *numclass, t_nummethod fn, t_symbol *s, int ac, t_atom *av) {
	t_num *x = (t_num *)pd_new(numclass);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f);
	x->x_bang = fn;

	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->x_f = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] == '!')
			{	x->x_f = strtof(c, NULL);
				x->x_lb = 1;   }
			else x->x_f = 0;   }   }

	return (x);
}

static void num_float(t_num *x, t_float f) {
	x->x_f = f;
	x->x_bang(x);
}

static void num_loadbang(t_num *x, t_floatarg action) {
	if (x->x_lb && !action) x->x_bang(x);
}


/* --------------------- int ------------------------------------- */
static t_class *i_class;

static void i_bang(t_num *x) {
	outlet_float(x->x_obj.ob_outlet, (t_float)(int64_t)(x->x_f));
}

static void i_send(t_num *x, t_symbol *s) {
	if (s->s_thing)
		pd_float(s->s_thing, (t_float)(int64_t)x->x_f);
	else pd_error(x, "%s: no such object", s->s_name);
}

static void *i_new(t_symbol *s, int ac, t_atom *av) {
	return (num_new(i_class, i_bang, s, ac, av));
}

/* --------------------- float ----------------------------------- */
static t_class *f_class;

static void f_bang(t_num *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f);
}

static void f_symbol(t_num *x, t_symbol *s) {
	t_float f = 0.0f;
	char *str_end = NULL;
	f = strtof(s->s_name, &str_end);
	if (f == 0 && s->s_name == str_end)
		pd_error(x, "Couldn't convert %s to float.", s->s_name);
	else outlet_float(x->x_obj.ob_outlet, x->x_f = f);
}

static void f_send(t_num *x, t_symbol *s) {
	if (s->s_thing)
		pd_float(s->s_thing, x->x_f);
	else pd_error(x, "%s: no such object", s->s_name);
}

static void *f_new(t_symbol *s, int ac, t_atom *av) {
	return (num_new(f_class, f_bang, s, ac, av));
}


/* --------------------------------------------------------------- */
/*                           arithmetics                           */
/* --------------------------------------------------------------- */

/* --------------------- binop1:  +, -, *, / --------------------- */

/* --------------------- addition -------------------------------- */
static t_class *b1_plus_class;

static void b1_plus_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 + x->x_f2);
}

static void *b1_plus_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_plus_class, b1_plus_bang, s, ac, av));
}

/* --------------------- subtraction ----------------------------- */
static t_class *b1_minus_class;

static void b1_minus_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 - x->x_f2);
}

static void *b1_minus_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_minus_class, b1_minus_bang, s, ac, av));
}

/* --------------------- multiplication -------------------------- */
static t_class *b1_times_class;

static void b1_times_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 * x->x_f2);
}

static void *b1_times_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_times_class, b1_times_bang, s, ac, av));
}

/* --------------------- division -------------------------------- */
static t_class *b1_div_class;

static void b1_div_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f2 != 0 ? x->x_f1 / x->x_f2 : 0));
}

static void *b1_div_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_div_class, b1_div_bang, s, ac, av));
}

/* --------------------- log ------------------------------------- */
static t_class *b1_log_class;

static void b1_log_bang(t_bop *x) {
	t_float r;
	if (x->x_f1 <= 0)
		r = -1000;
	else if (x->x_f2 <= 0)
		r = log(x->x_f1);
	else r = log(x->x_f1) / log(x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *b1_log_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_log_class, b1_log_bang, s, ac, av));
}

/* --------------------- pow ------------------------------------- */
static t_class *b1_pow_class;

static void b1_pow_bang(t_bop *x) {
	t_float r = (x->x_f1 == 0 && x->x_f2 < 0) ||
		(x->x_f1 < 0 && (x->x_f2 - (int)x->x_f2) != 0) ?
			0 : pow(x->x_f1, x->x_f2);
	outlet_float(x->x_obj.ob_outlet, r);
}

static void *b1_pow_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_pow_class, b1_pow_bang, s, ac, av));
}

/* --------------------- max ------------------------------------- */
static t_class *b1_max_class;

static void b1_max_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 > x->x_f2 ? x->x_f1 : x->x_f2));
}

static void *b1_max_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_max_class, b1_max_bang, s, ac, av));
}

/* --------------------- min ------------------------------------- */
static t_class *b1_min_class;

static void b1_min_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet,
		(x->x_f1 < x->x_f2 ? x->x_f1 : x->x_f2));
}

static void *b1_min_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b1_min_class, b1_min_bang, s, ac, av));
}

/* --------------- binop2: ==, !=, >, <, >=, <=. ----------------- */

/* --------------------- == -------------------------------------- */
static t_class *b2_ee_class;

static void b2_ee_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 == x->x_f2);
}

static void *b2_ee_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b2_ee_class, b2_ee_bang, s, ac, av));
}

/* --------------------- != -------------------------------------- */
static t_class *b2_ne_class;

static void b2_ne_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 != x->x_f2);
}

static void *b2_ne_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b2_ne_class, b2_ne_bang, s, ac, av));
}

/* --------------------- > --------------------------------------- */
static t_class *b2_gt_class;

static void b2_gt_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 > x->x_f2);
}

static void *b2_gt_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b2_gt_class, b2_gt_bang, s, ac, av));
}

/* --------------------- < --------------------------------------- */
static t_class *b2_lt_class;

static void b2_lt_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 < x->x_f2);
}

static void *b2_lt_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b2_lt_class, b2_lt_bang, s, ac, av));
}

/* --------------------- >= -------------------------------------- */
static t_class *b2_ge_class;

static void b2_ge_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 >= x->x_f2);
}

static void *b2_ge_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b2_ge_class, b2_ge_bang, s, ac, av));
}

/* --------------------- <= -------------------------------------- */
static t_class *b2_le_class;

static void b2_le_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, x->x_f1 <= x->x_f2);
}

static void *b2_le_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b2_le_class, b2_le_bang, s, ac, av));
}

/* ------- binop3: &, |, &&, ||, <<, >>, %, ^, mod, div ---------- */

/* --------------------- & --------------------------------------- */
static t_class *b3_ba_class;

static void b3_ba_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) & (int)(x->x_f2));
}

static void *b3_ba_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_ba_class, b3_ba_bang, s, ac, av));
}

/* --------------------- && -------------------------------------- */
static t_class *b3_la_class;

static void b3_la_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) && (int)(x->x_f2));
}

static void *b3_la_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_la_class, b3_la_bang, s, ac, av));
}

/* --------------------- | --------------------------------------- */
static t_class *b3_bo_class;

static void b3_bo_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) | (int)(x->x_f2));
}

static void *b3_bo_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_bo_class, b3_bo_bang, s, ac, av));
}

/* --------------------- || -------------------------------------- */
static t_class *b3_lo_class;

static void b3_lo_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) || (int)(x->x_f2));
}

static void *b3_lo_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_lo_class, b3_lo_bang, s, ac, av));
}

/* --------------------- << -------------------------------------- */
static t_class *b3_ls_class;

static void b3_ls_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) << (int)(x->x_f2));
}

static void *b3_ls_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_ls_class, b3_ls_bang, s, ac, av));
}

/* --------------------- >> -------------------------------------- */
static t_class *b3_rs_class;

static void b3_rs_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) >> (int)(x->x_f2));
}

static void *b3_rs_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_rs_class, b3_rs_bang, s, ac, av));
}

/* --------------------- % --------------------------------------- */
static t_class *b3_pc_class;

static void b3_pc_bang(t_bop *x) {
	int n2 = x->x_f2;
		/* apparently "%" raises an exception for INT_MIN and -1 */
	if (n2 == -1)
		outlet_float(x->x_obj.ob_outlet, 0);
	else outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) % (n2 ? n2 : 1));
}

static void *b3_pc_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_pc_class, b3_pc_bang, s, ac, av));
}

/* --------------------- ^ --------------------------------------- */
static t_class *b3_xor_class;

static void b3_xor_bang(t_bop *x) {
	outlet_float(x->x_obj.ob_outlet, ((int)(x->x_f1)) ^ (int)(x->x_f2));
}

static void *b3_xor_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_xor_class, b3_xor_bang, s, ac, av));
}

/* --------------------- mod ------------------------------------- */
static t_class *b3_mod_class;

static void b3_mod_bang(t_bop *x) {
	int n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	result = ((int)(x->x_f1)) % n2;
	if (result < 0) result += n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void *b3_mod_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_mod_class, b3_mod_bang, s, ac, av));
}

/* --------------------- div ------------------------------------- */
static t_class *b3_div_class;

static void b3_div_bang(t_bop *x) {
	int n1 = x->x_f1, n2 = x->x_f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	outlet_float(x->x_obj.ob_outlet, (t_float)result);
}

static void *b3_div_new(t_symbol *s, int ac, t_atom *av) {
	return (bop_new(b3_div_class, b3_div_bang, s, ac, av));
}

void blunt_setup(void) {

	post("Blunt! 0.1.0");

	/* ---------------- connectives --------------------- */

	i_class = class_new(gensym("i"), (t_newmethod)i_new, 0,
		sizeof(t_num), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)i_new, gensym("`i"), A_GIMME, 0);
	class_addmethod(i_class, (t_method)i_send, gensym("send"), A_SYMBOL, 0);
	class_addbang(i_class, i_bang);

	f_class = class_new(gensym("f"), (t_newmethod)f_new, 0,
		sizeof(t_num), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)f_new, gensym("`f"), A_GIMME, 0);
	class_addmethod(f_class, (t_method)f_send, gensym("send"), A_SYMBOL, 0);
	class_addbang(f_class, f_bang);
	class_addsymbol(f_class, f_symbol);

	t_class *nums[] = { i_class, f_class };

	int i = sizeof(nums) / sizeof*(nums);
	t_symbol *num_sym = gensym("blunt");
	while (i--)
	{	class_addfloat(nums[i], num_float);
		class_addmethod(nums[i], (t_method)num_loadbang,
			gensym("loadbang"), A_DEFFLOAT, 0);
		class_sethelpsymbol(nums[i], num_sym);   }

	/* ------------------ binop1 ----------------------- */

	b1_plus_class = class_new(gensym("+"), (t_newmethod)b1_plus_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_plus_new, gensym("`+"), A_GIMME, 0);
	class_addbang(b1_plus_class, b1_plus_bang);

	b1_minus_class = class_new(gensym("-"), (t_newmethod)b1_minus_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_minus_new, gensym("`-"), A_GIMME, 0);
	class_addbang(b1_minus_class, b1_minus_bang);

	b1_times_class = class_new(gensym("*"), (t_newmethod)b1_times_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_times_new, gensym("`*"), A_GIMME, 0);
	class_addbang(b1_times_class, b1_times_bang);

	b1_div_class = class_new(gensym("/"), (t_newmethod)b1_div_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_div_new, gensym("`/"), A_GIMME, 0);
	class_addbang(b1_div_class, b1_div_bang);

	b1_log_class = class_new(gensym("log"), (t_newmethod)b1_log_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_log_new, gensym("`log"), A_GIMME, 0);
	class_addbang(b1_log_class, b1_log_bang);

	b1_pow_class = class_new(gensym("pow"), (t_newmethod)b1_pow_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_pow_new, gensym("`pow"), A_GIMME, 0);
	class_addbang(b1_pow_class, b1_pow_bang);

	b1_max_class = class_new(gensym("max"), (t_newmethod)b1_max_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_max_new, gensym("`max"), A_GIMME, 0);
	class_addbang(b1_max_class, b1_max_bang);

	b1_min_class = class_new(gensym("min"), (t_newmethod)b1_min_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b1_min_new, gensym("`min"), A_GIMME, 0);
	class_addbang(b1_min_class, b1_min_bang);

	/* ------------------ binop2 ----------------------- */

	b2_ee_class = class_new(gensym("=="), (t_newmethod)b2_ee_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b2_ee_new, gensym("`=="), A_GIMME, 0);
	class_addbang(b2_ee_class, b2_ee_bang);

	b2_ne_class = class_new(gensym("!="), (t_newmethod)b2_ne_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b2_ne_new, gensym("`!="), A_GIMME, 0);
	class_addbang(b2_ne_class, b2_ne_bang);

	b2_gt_class = class_new(gensym(">"), (t_newmethod)b2_gt_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b2_gt_new, gensym("`>"), A_GIMME, 0);
	class_addbang(b2_gt_class, b2_gt_bang);

	b2_lt_class = class_new(gensym("<"), (t_newmethod)b2_lt_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b2_lt_new, gensym("`<"), A_GIMME, 0);
	class_addbang(b2_lt_class, b2_lt_bang);

	b2_ge_class = class_new(gensym(">="), (t_newmethod)b2_ge_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b2_ge_new, gensym("`>="), A_GIMME, 0);
	class_addbang(b2_ge_class, b2_ge_bang);

	b2_le_class = class_new(gensym("<="), (t_newmethod)b2_le_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b2_le_new, gensym("`<="), A_GIMME, 0);
	class_addbang(b2_le_class, b2_le_bang);

	/* ------------------ binop3 ----------------------- */

	b3_ba_class = class_new(gensym("&"), (t_newmethod)b3_ba_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_ba_new, gensym("`&"), A_GIMME, 0);
	class_addbang(b3_ba_class, b3_ba_bang);

	b3_la_class = class_new(gensym("&&"), (t_newmethod)b3_la_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_la_new, gensym("`&&"), A_GIMME, 0);
	class_addbang(b3_la_class, b3_la_bang);

	b3_bo_class = class_new(gensym("|"), (t_newmethod)b3_bo_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_bo_new, gensym("`|"), A_GIMME, 0);
	class_addbang(b3_bo_class, b3_bo_bang);

	b3_lo_class = class_new(gensym("||"), (t_newmethod)b3_lo_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_lo_new, gensym("`||"), A_GIMME, 0);
	class_addbang(b3_lo_class, b3_lo_bang);

	b3_ls_class = class_new(gensym("<<"), (t_newmethod)b3_ls_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_ls_new, gensym("`<<"), A_GIMME, 0);
	class_addbang(b3_ls_class, b3_ls_bang);

	b3_rs_class = class_new(gensym(">>"), (t_newmethod)b3_rs_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_rs_new, gensym("`>>"), A_GIMME, 0);
	class_addbang(b3_rs_class, b3_rs_bang);

	b3_pc_class = class_new(gensym("%"), (t_newmethod)b3_pc_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_pc_new, gensym("`%"), A_GIMME, 0);
	class_addbang(b3_pc_class, b3_pc_bang);

	b3_xor_class = class_new(gensym("^"), (t_newmethod)b3_xor_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(b3_xor_class, b3_xor_bang);

	b3_mod_class = class_new(gensym("mod"), (t_newmethod)b3_mod_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_mod_new, gensym("`mod"), A_GIMME, 0);
	class_addbang(b3_mod_class, b3_mod_bang);

	b3_div_class = class_new(gensym("div"), (t_newmethod)b3_div_new, 0,
		sizeof(t_bop), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b3_div_new, gensym("`div"), A_GIMME, 0);
	class_addbang(b3_div_class, b3_div_bang);

	t_class *bops[][23] =
	{	{	b1_plus_class, b1_minus_class, b1_times_class, b1_div_class,
			b1_log_class, b1_pow_class, b1_max_class, b1_min_class,
			b2_ee_class, b2_ne_class, b2_gt_class, b2_lt_class,
			b2_ge_class, b2_le_class, b3_ba_class, b3_la_class,
			b3_bo_class, b3_lo_class, b3_ls_class, b3_rs_class,
			b3_pc_class, b3_mod_class, b3_div_class   },

		{	b3_xor_class   }   };

	t_symbol *syms[] = { num_sym, gensym("0x5e") };

	i = sizeof(syms) / sizeof*(syms);
	while (i--)
	{	int j = 0, max = sizeof(bops[i]) / sizeof*(bops[i]);
		for (; j < max; j++)
		{	if (bops[i][j] == 0) break;
			class_addfloat(bops[i][j], bop_float);
			class_addmethod(bops[i][j], (t_method)bop_f2,
				gensym("f2"), A_FLOAT, 0);
			class_addmethod(bops[i][j], (t_method)bop_skip,
				gensym("."), A_GIMME, 0);
			class_addmethod(bops[i][j], (t_method)bop_loadbang,
				gensym("loadbang"), A_DEFFLOAT, 0);
			class_sethelpsymbol(bops[i][j], syms[i]);   }   }

	/* hot & reverse binops */
	hotop_setup();
	revop_setup();
}
