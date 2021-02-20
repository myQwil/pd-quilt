#include "ufloat.h"

/* -------------------------- gloat -------------------------- */
static t_class *gloat_class;

typedef struct _gloat {
	t_object obj;
	ufloat uf;
} t_gloat;

static void gloat_peek(t_gloat *x ,t_symbol *s) {
	ufloat uf = x->uf;
	post("%s%s0x%x %u %u = %g"
		,s->s_name ,*s->s_name?": ":""
		,uf.mt ,uf.ex ,uf.sg ,uf.f);
}

static void gloat_bang(t_gloat *x) {
	outlet_float(x->obj.ob_outlet ,x->uf.f);
}

static void gloat_mantissa(t_gloat *x ,t_floatarg f) {
	x->uf.mt = f;
}

static void gloat_exponent(t_gloat *x ,t_floatarg f) {
	x->uf.ex = f;
}

static void gloat_sign(t_gloat *x ,t_floatarg f) {
	x->uf.sg = f;
}

static void gloat_f(t_gloat *x ,t_floatarg f) {
	x->uf.f = f;
}

static void gloat_u(t_gloat *x ,t_floatarg f) {
	x->uf.u = f;
}

static void gloat_float(t_gloat *x ,t_float f) {
	gloat_mantissa(x ,f);
	gloat_bang(x);
}

static void gloat_set(t_gloat *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac>3) ac = 3;
	switch (ac)
	{ case 3: if ((av+2)->a_type == A_FLOAT)
		x->uf.sg = (av+2)->a_w.w_float;
	  case 2: if ((av+1)->a_type == A_FLOAT)
		x->uf.ex = (av+1)->a_w.w_float;
	  case 1: if (av->a_type == A_FLOAT)
		x->uf.mt = av->a_w.w_float; }
}

static void gloat_list(t_gloat *x ,t_symbol *s ,int ac ,t_atom *av) {
	gloat_set(x ,s ,ac ,av);
	gloat_bang(x);
}

static void *gloat_new(t_symbol *s ,int argc ,t_atom *argv) {
	t_gloat *x = (t_gloat *)pd_new(gloat_class);
	outlet_new(&x->obj ,&s_float);
	inlet_new(&x->obj ,&x->obj.ob_pd ,&s_float ,gensym("e"));
	inlet_new(&x->obj ,&x->obj.ob_pd ,&s_float ,gensym("s"));
	gloat_set(x ,s ,argc ,argv);
	return (x);
}

void gloat_setup(void) {
	gloat_class = class_new(gensym("gloat")
		,(t_newmethod)gloat_new ,0
		,sizeof(t_gloat) ,0
		,A_GIMME ,0);
	class_addbang  (gloat_class ,gloat_bang);
	class_addfloat (gloat_class ,gloat_float);
	class_addlist  (gloat_class ,gloat_list);
	class_addmethod(gloat_class ,(t_method)gloat_mantissa
		,gensym("m") ,A_FLOAT ,0);
	class_addmethod(gloat_class ,(t_method)gloat_exponent
		,gensym("e") ,A_FLOAT ,0);
	class_addmethod(gloat_class ,(t_method)gloat_sign
		,gensym("s") ,A_FLOAT ,0);
	class_addmethod(gloat_class ,(t_method)gloat_f
		,gensym("f") ,A_FLOAT ,0);
	class_addmethod(gloat_class ,(t_method)gloat_u
		,gensym("u") ,A_FLOAT ,0);
	class_addmethod(gloat_class ,(t_method)gloat_set
		,gensym("set") ,A_GIMME ,0);
	class_addmethod(gloat_class ,(t_method)gloat_peek
		,gensym("peek") ,A_DEFSYM ,0);
	class_sethelpsymbol(gloat_class ,gensym("sploat"));
}
