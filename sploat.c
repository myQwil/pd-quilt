#include "m_pd.h"

typedef union {
	float f;
	struct { unsigned mant:23,expo:8,sign:1; } u;
} ufloat;

/* -------------------------- sploat -------------------------- */

static t_class *sploat_class;

typedef struct _sploat {
	t_object x_obj;
	t_float x_f;
	t_outlet *m_out, *e_out, *s_out;
} t_sploat;

static void sploat_peek(t_sploat *x, t_symbol *s) {
	ufloat uf = {.f=x->x_f};
	post("%s%s0x%x %u %u = %g",
		s->s_name, *s->s_name?": ":"",
		uf.u.mant, uf.u.expo, uf.u.sign, uf.f);
}

static void sploat_bang(t_sploat *x) {
	ufloat uf = {.f=x->x_f};
	outlet_float(x->s_out, uf.u.sign);
	outlet_float(x->e_out, uf.u.expo);
	outlet_float(x->m_out, uf.u.mant);
}

static void sploat_float(t_sploat *x, t_float f) {
	ufloat uf = {.f=x->x_f=f};
	outlet_float(x->s_out, uf.u.sign);
	outlet_float(x->e_out, uf.u.expo);
	outlet_float(x->m_out, uf.u.mant);
}

static void *sploat_new(t_floatarg f) {
	t_sploat *x = (t_sploat *)pd_new(sploat_class);
	x->m_out = outlet_new(&x->x_obj, &s_float);
	x->e_out = outlet_new(&x->x_obj, &s_float);
	x->s_out = outlet_new(&x->x_obj, &s_float);
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
