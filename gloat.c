#include "m_pd.h"

typedef union {
	float f;
	struct { unsigned mnt:23,exp:8,sgn:1; } u;
} ufloat;
#define mnt u.mnt
#define exp u.exp
#define sgn u.sgn

/* -------------------------- gloat -------------------------- */

static t_class *gloat_class;

typedef struct _gloat {
	t_object x_obj;
	t_float x_m, x_e, x_s;
} t_gloat;

static void gloat_peek(t_gloat *x, t_symbol *s) {
	ufloat fu =
	{	.sgn=x->x_s,
		.exp=x->x_e,
		.mnt=x->x_m   };
	float f=fu.f;
	ufloat uf = {.f=f};
	post("%s%s0x%x %u %u = %g",
		s->s_name, *s->s_name?": ":"",
		uf.mnt, uf.exp, uf.sgn, f);
}

static void gloat_bang(t_gloat *x) {
	ufloat uf =
	{	.sgn=x->x_s,
		.exp=x->x_e,
		.mnt=x->x_m   };
	outlet_float(x->x_obj.ob_outlet, uf.f);
}

static void gloat_float(t_gloat *x, t_float f) {
	x->x_m = f;
	gloat_bang(x);
}

static void *gloat_new(t_symbol *s, int argc, t_atom *argv) {
	t_gloat *x = (t_gloat *)pd_new(gloat_class);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_m);
	floatinlet_new(&x->x_obj, &x->x_e);
	floatinlet_new(&x->x_obj, &x->x_s);
	switch (argc)
	{ case 3: x->x_s = atom_getfloat(argv+2);
	  case 2: x->x_e = atom_getfloat(argv+1);
	  case 1: x->x_m = atom_getfloat(argv); }
	return (x);
}

void gloat_setup(void) {
	gloat_class = class_new(gensym("gloat"),
		(t_newmethod)gloat_new, 0,
		sizeof(t_gloat), 0,
		A_GIMME, 0);
	class_addbang(gloat_class, gloat_bang);
	class_addfloat(gloat_class, gloat_float);
	class_addmethod(gloat_class, (t_method)gloat_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_sethelpsymbol(gloat_class, gensym("sploat"));
}
