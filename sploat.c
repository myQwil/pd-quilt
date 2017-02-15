#include "m_pd.h"

typedef union {
	t_float f;
	struct {
		unsigned int mantissa : 23;
		unsigned int exponent : 8;
		unsigned int sign : 1;
	} u;
} ufloat;

/* -------------------------- sploat -------------------------- */

static t_class *sploat_class;

typedef struct _sploat {
	t_object x_obj;
	t_float x_f;
	t_outlet *m_out, *e_out, *s_out;
} t_sploat;

static void sploat_bang(t_sploat *x) {
	ufloat uf;
	uf.f = x->x_f;
	outlet_float(x->s_out, uf.u.sign);
	outlet_float(x->e_out, uf.u.exponent);
	outlet_float(x->m_out, uf.u.mantissa);
}

static void sploat_float(t_sploat *x, t_float f) {
	ufloat uf;
	uf.f = x->x_f = f;
	outlet_float(x->s_out, uf.u.sign);
	outlet_float(x->e_out, uf.u.exponent);
	outlet_float(x->m_out, uf.u.mantissa);
}

static void *sploat_new(t_floatarg f) {
	t_sploat *x = (t_sploat *)pd_new(sploat_class);
	x->x_f = f;
	floatinlet_new(&x->x_obj, &x->x_f);
	x->m_out = outlet_new(&x->x_obj, &s_float);
	x->e_out = outlet_new(&x->x_obj, &s_float);
	x->s_out = outlet_new(&x->x_obj, &s_float);
	return (x);
}

void sploat_setup(void) {
	sploat_class = class_new(gensym("sploat"),
		(t_newmethod)sploat_new, 0,
		sizeof(t_sploat), 0,
		A_DEFFLOAT, 0);
	
	class_addbang(sploat_class, sploat_bang);
	class_addfloat(sploat_class, sploat_float);
}
