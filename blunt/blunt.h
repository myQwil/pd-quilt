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
static t_float blunt_plus(t_float f1, t_float f2) { return f1 + f2; }
static t_float blunt_minus(t_float f1, t_float f2) { return f1 - f2; }
static t_float blunt_times(t_float f1, t_float f2) { return f1 * f2; }
static t_float blunt_div(t_float f1, t_float f2) { return (f2!=0 ? f1/f2 : 0); }

static t_float blunt_log(t_float f1, t_float f2) {
	t_float r;
	if (f1 <= 0) r = -1000;
	else if (f2 <= 0) r = LOG(f1);
	else r = LOG(f1) / LOG(f2);
	return r;
}

static t_float blunt_pow(t_float f1, t_float f2) {
	t_float r = (f1 == 0 && f2 < 0) ||
		(f1 < 0 && (f2 - (int)f2) != 0) ?
			0 : POW(f1, f2);
	return r;
}

static t_float blunt_max(t_float f1, t_float f2) { return (f1 > f2 ? f1 : f2); }
static t_float blunt_min(t_float f1, t_float f2) { return (f1 < f2 ? f1 : f2); }

	// binop2: ==, !=, >, <, >=, <=
static t_float blunt_ee(t_float f1, t_float f2) { return f1 == f2; }
static t_float blunt_ne(t_float f1, t_float f2) { return f1 != f2; }
static t_float blunt_gt(t_float f1, t_float f2) { return f1 > f2; }
static t_float blunt_lt(t_float f1, t_float f2) { return f1 < f2; }
static t_float blunt_ge(t_float f1, t_float f2) { return f1 >= f2; }
static t_float blunt_le(t_float f1, t_float f2) { return f1 <= f2; }

	// binop3: &, |, &&, ||, <<, >>, ^, %, mod, div
static t_float blunt_ba(t_float f1, t_float f2) { return ((int)f1) & (int)f2; }
static t_float blunt_la(t_float f1, t_float f2) { return ((int)f1) && (int)f2; }
static t_float blunt_bo(t_float f1, t_float f2) { return ((int)f1) | (int)f2; }
static t_float blunt_lo(t_float f1, t_float f2) { return ((int)f1) || (int)f2; }
static t_float blunt_ls(t_float f1, t_float f2) { return ((int)f1) << (int)f2; }
static t_float blunt_rs(t_float f1, t_float f2) { return ((int)f1) >> (int)f2; }
static t_float blunt_xor(t_float f1, t_float f2) { return ((int)f1) ^ (int)f2; }

static t_float blunt_pc(t_float f1, t_float f2) {
	int n2=f2;
	return (n2 == -1) ? 0 : ((int)f1) % (n2 ? n2 : 1);
}

static t_float blunt_mod(t_float f1, t_float f2) {
	int n2=f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	result = ((int)f1) % n2;
	if (result < 0) result += n2;
	return (t_float)result;
}

static t_float blunt_divm(t_float f1, t_float f2) {
	int n1=f1, n2=f2, result;
	if (n2 < 0) n2 = -n2;
	else if (!n2) n2 = 1;
	if (n1 < 0) n1 -= (n2-1);
	result = n1 / n2;
	return (t_float)result;
}
