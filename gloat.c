#include "m_pd.h"

typedef union {
	t_float f;
	unsigned u;
	struct {
		unsigned int mantissa : 23;
		unsigned int exponent : 8;
		unsigned int sign : 1;
	} p;
} ufloat;

/* -------------------------- gloat -------------------------- */

static t_class *gloat_class;

typedef struct _gloat {
	t_object x_obj;
	t_float x_m, x_e, x_s;
} t_gloat;

static void gloat_bang(t_gloat *x) {
	ufloat uf;
	uf.p.mantissa = x->x_m;
	uf.p.exponent = x->x_e;
	uf.p.sign = x->x_s;
	outlet_float(x->x_obj.ob_outlet, uf.f);
}

static void *gloat_new(t_floatarg f) {
	t_gloat *x = (t_gloat *)pd_new(gloat_class);
	floatinlet_new(&x->x_obj, &x->x_s);
	floatinlet_new(&x->x_obj, &x->x_e);
	floatinlet_new(&x->x_obj, &x->x_m);
	outlet_new(&x->x_obj, &s_float);
	return (x);
}

void gloat_setup(void) {
	gloat_class = class_new(gensym("gloat"),
		(t_newmethod)gloat_new, 0,
		sizeof(t_gloat), 0,
		A_DEFFLOAT, 0);
	
	class_addbang(gloat_class, gloat_bang);
	class_sethelpsymbol(gloat_class, gensym("sploat.pd"));
}
