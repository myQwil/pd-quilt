#include "m_pd.h"

typedef union {
	float f;
	struct { unsigned mnt:23,exp:8,sgn:1; } u;
} ufloat;
#define mnt u.mnt
#define exp u.exp
#define sgn u.sgn

/* -------------------------- sploat -------------------------- */

static t_class *sploat_class;

typedef struct _sploat {
	t_object x_obj;
	t_float x_f;
	t_outlet *o_m, *o_e, *o_s;
} t_sploat;

static void sploat_peek(t_sploat *x, t_symbol *s) {
	ufloat uf = {.f=x->x_f};
	post("%s%s0x%x %u %u = %g",
		s->s_name, *s->s_name?": ":"",
		uf.mnt, uf.exp, uf.sgn, uf.f);
}

static void sploat_bang(t_sploat *x) {
	ufloat uf = {.f=x->x_f};
	outlet_float(x->o_s, uf.sgn);
	outlet_float(x->o_e, uf.exp);
	outlet_float(x->o_m, uf.mnt);
}

static void sploat_float(t_sploat *x, t_float f) {
	x->x_f = f;
	sploat_bang(x);
}

static void *sploat_new(t_floatarg f) {
	t_sploat *x = (t_sploat *)pd_new(sploat_class);
	x->o_m = outlet_new(&x->x_obj, &s_float);
	x->o_e = outlet_new(&x->x_obj, &s_float);
	x->o_s = outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f);
	x->x_f = f;
	return (x);
}

void sploat_setup(void) {
	sploat_class = class_new(gensym("sploat"),
		(t_newmethod)sploat_new, 0,
		sizeof(t_sploat), 0,
		A_DEFFLOAT, 0);
	class_addbang(sploat_class, sploat_bang);
	class_addfloat(sploat_class, sploat_float);
	class_addmethod(sploat_class, (t_method)sploat_peek,
		gensym("peek"), A_DEFSYM, 0);
}
