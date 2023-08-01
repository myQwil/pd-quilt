#include "ufloat.h"

/* -------------------------- fldec -------------------------- */
static t_class *fldec_class;

typedef struct _fldec {
	t_object obj;
	ufloat uf;
	t_outlet *o_mantissa;
	t_outlet *o_exponent;
	t_outlet *o_sign;
} t_fldec;

static void fldec_print(t_fldec *x, t_symbol *s) {
	ufloat uf = x->uf;
	post("%s%s0x%x %u %u = %g"
	, s->s_name, *s->s_name ? ": " : ""
	, uf.mantissa, uf.exponent, uf.sign, uf.f);
}

static void fldec_bang(t_fldec *x) {
	outlet_float(x->o_sign, x->uf.sign);
	outlet_float(x->o_exponent, x->uf.exponent);
	outlet_float(x->o_mantissa, x->uf.mantissa);
}

static void fldec_set(t_fldec *x, t_float f) {
	x->uf.f = f;
}

static void fldec_float(t_fldec *x, t_float f) {
	fldec_set(x, f);
	fldec_bang(x);
}

static void *fldec_new(t_float f) {
	t_fldec *x = (t_fldec *)pd_new(fldec_class);
	x->o_mantissa = outlet_new(&x->obj, &s_float);
	x->o_exponent = outlet_new(&x->obj, &s_float);
	x->o_sign = outlet_new(&x->obj, &s_float);
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("set"));
	fldec_set(x, f);
	return x;
}

void fldec_setup(void) {
	fldec_class = class_new(gensym("fldec")
	, (t_newmethod)fldec_new, 0
	, sizeof(t_fldec), 0
	, A_DEFFLOAT, 0);
	class_addbang(fldec_class, fldec_bang);
	class_addfloat(fldec_class, fldec_float);
	class_addmethod(fldec_class, (t_method)fldec_set, gensym("set"), A_FLOAT, 0);
	class_addmethod(fldec_class, (t_method)fldec_print, gensym("print"), A_DEFSYM, 0);
	class_sethelpsymbol(fldec_class, gensym("flenc"));
}
