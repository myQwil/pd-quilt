#include "m_pd.h"
#include <math.h>
#include <string.h> // strlen
#include <stdlib.h> // strtof

#if PD_FLOATSIZE == 32
# define POW powf
# define LOG logf
#else
# define POW pow
# define LOG log
#endif

	// binop1:  +, -, *, /
static inline t_float blunt_plus  (t_float f1 ,t_float f2) { return f1 + f2; }
static inline t_float blunt_minus (t_float f1 ,t_float f2) { return f1 - f2; }
static inline t_float blunt_times (t_float f1 ,t_float f2) { return f1 * f2; }
static inline t_float blunt_div   (t_float f1 ,t_float f2) { return (f2!=0 ? f1/f2 : 0); }

static inline t_float blunt_log(t_float f1 ,t_float f2) {
	t_float r;
	if (f1 <= 0) r = -1000;
	else if (f2 <= 0) r = LOG(f1);
	else r = LOG(f1) / LOG(f2);
	return r;
}

static inline t_float blunt_pow(t_float f1 ,t_float f2) {
	t_float r = (f1 == 0 && f2 < 0) ||
		(f1 < 0 && (f2 - (int)f2) != 0) ?
			0 : POW(f1 ,f2);
	return r;
}

static inline t_float blunt_max(t_float f1 ,t_float f2) { return (f1 > f2 ? f1 : f2); }
static inline t_float blunt_min(t_float f1 ,t_float f2) { return (f1 < f2 ? f1 : f2); }

	// binop2: ==, !=, >, <, >=, <=
static inline t_float blunt_ee(t_float f1 ,t_float f2) { return f1 == f2; }
static inline t_float blunt_ne(t_float f1 ,t_float f2) { return f1 != f2; }
static inline t_float blunt_gt(t_float f1 ,t_float f2) { return f1 >  f2; }
static inline t_float blunt_lt(t_float f1 ,t_float f2) { return f1 <  f2; }
static inline t_float blunt_ge(t_float f1 ,t_float f2) { return f1 >= f2; }
static inline t_float blunt_le(t_float f1 ,t_float f2) { return f1 <= f2; }

	// binop3: &, |, &&, ||, <<, >>, ^, %, mod, div
static inline t_float blunt_ba  (t_float f1 ,t_float f2) { return (int)f1 &  (int)f2; }
static inline t_float blunt_la  (t_float f1 ,t_float f2) { return (int)f1 && (int)f2; }
static inline t_float blunt_bo  (t_float f1 ,t_float f2) { return (int)f1 |  (int)f2; }
static inline t_float blunt_lo  (t_float f1 ,t_float f2) { return (int)f1 || (int)f2; }
static inline t_float blunt_ls  (t_float f1 ,t_float f2) { return (int)f1 << (int)f2; }
static inline t_float blunt_rs  (t_float f1 ,t_float f2) { return (int)f1 >> (int)f2; }
static inline t_float blunt_xor (t_float f1 ,t_float f2) { return (int)f1 ^  (int)f2; }
static inline t_float blunt_fpc (t_float f1 ,t_float f2) { return fmod(f1 ,f2); }

static inline t_float blunt_pc(t_float f1 ,t_float f2) {
	int n2 = f2;
	return (n2 == -1) ? 0 : (int)f1 % (n2 ? n2 : 1);
}

static inline t_float blunt_mod(t_float f1 ,t_float f2) {
	int n2 = abs((int)f2) ,result;
	if (!n2) n2 = 1;
	result = (int)f1 % n2;
	if (result < 0) result += n2;
	return (t_float)result;
}

static inline t_float blunt_divm(t_float f1 ,t_float f2) {
	int n1 = f1 ,n2 = abs((int)f2) ,result;
	if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	return (t_float)result;
}

typedef struct _blunt {
	t_object obj;
	int loadbang;
} t_blunt;

static void blunt_loadbang(t_blunt *x ,t_floatarg action) {
	if (x->loadbang && !action) pd_bang((t_pd *)x);
}

/* -------------------------- blunt binops -------------------------- */

typedef struct _bop {
	t_blunt bl;
	t_float f1;
	t_float f2;
} t_bop;

typedef void (*t_bopmethod)(t_bop *x);

static void bop_float(t_bop *x ,t_float f) {
	x->f1 = f;
	pd_bang((t_pd *)x);
}

static void bop_f1(t_bop *x ,t_float f) {
	x->f1 = f;
}

static void bop_f2(t_bop *x ,t_float f) {
	x->f2 = f;
}

static void bop_skip(t_bop *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
		x->f2 = av->a_w.w_float;
	pd_bang((t_pd *)x);
}

static void bop_set(t_bop *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->f1 = av->a_w.w_float;
		ac-- ,av++;   }
	if (ac && av->a_type == A_FLOAT)
		x->f2 = av->a_w.w_float;
}

static void bop_init(t_bop *x ,int ac ,t_atom *av) {
	if (ac>1 && av->a_type == A_FLOAT)
	{	x->f1 = av->a_w.w_float;
		av++;   }
	else x->f1 = 0;

	x->f2 = x->bl.loadbang = 0;
	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->f2 = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] == '!')
			{	x->f2 = strtof(c ,NULL);
				x->bl.loadbang = 1;   }   }   }

	outlet_new(&x->bl.obj ,&s_float);
}

static t_bop *bop_new(t_class *cl ,t_symbol *s ,int ac ,t_atom *av) {
	t_bop *x = (t_bop *)pd_new(cl);
	bop_init(x ,ac ,av);
	floatinlet_new(&x->bl.obj ,&x->f2);
	return (x);
}
