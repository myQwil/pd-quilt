#include "ufloat.h"

/* -------------------------- flenc -------------------------- */
static t_class *flenc_class;

typedef struct {
	t_object obj;
	ufloat uf;
} t_flenc;

static void flenc_peek(t_flenc *x ,t_symbol *s) {
	ufloat uf = x->uf;
	post("%s%s0x%x %u %u = %g"
		,s->s_name ,*s->s_name?": ":""
		,uf.mt ,uf.ex ,uf.sg ,uf.f);
}

static void flenc_bang(t_flenc *x) {
	outlet_float(x->obj.ob_outlet ,x->uf.f);
}

static void flenc_mantissa(t_flenc *x ,t_float f) {
	x->uf.mt = f;
}

static void flenc_exponent(t_flenc *x ,t_float f) {
	x->uf.ex = f;
}

static void flenc_sign(t_flenc *x ,t_float f) {
	x->uf.sg = f;
}

static void flenc_f(t_flenc *x ,t_float f) {
	x->uf.f = f;
}

static void flenc_u(t_flenc *x ,t_float f) {
	x->uf.u = f;
}

static void flenc_float(t_flenc *x ,t_float f) {
	flenc_mantissa(x ,f);
	flenc_bang(x);
}

static void flenc_set(t_flenc *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac>3) ac = 3;
	switch (ac)
	{ case 3: if ((av+2)->a_type == A_FLOAT)
		x->uf.sg = (av+2)->a_w.w_float;
	  case 2: if ((av+1)->a_type == A_FLOAT)
		x->uf.ex = (av+1)->a_w.w_float;
	  case 1: if (av->a_type == A_FLOAT)
		x->uf.mt = av->a_w.w_float; }
}

static void flenc_list(t_flenc *x ,t_symbol *s ,int ac ,t_atom *av) {
	flenc_set(x ,s ,ac ,av);
	flenc_bang(x);
}

static void *flenc_new(t_symbol *s ,int argc ,t_atom *argv) {
	t_flenc *x = (t_flenc*)pd_new(flenc_class);
	outlet_new(&x->obj ,&s_float);
	inlet_new(&x->obj ,&x->obj.ob_pd ,&s_float ,gensym("e"));
	inlet_new(&x->obj ,&x->obj.ob_pd ,&s_float ,gensym("s"));
	flenc_set(x ,s ,argc ,argv);
	return (x);
}

void flenc_setup(void) {
	flenc_class = class_new(gensym("flenc")
		,(t_newmethod)flenc_new ,0
		,sizeof(t_flenc) ,0
		,A_GIMME ,0);
	class_addbang  (flenc_class ,flenc_bang);
	class_addfloat (flenc_class ,flenc_float);
	class_addlist  (flenc_class ,flenc_list);
	class_addmethod(flenc_class ,(t_method)flenc_mantissa ,gensym("m")    ,A_FLOAT  ,0);
	class_addmethod(flenc_class ,(t_method)flenc_exponent ,gensym("e")    ,A_FLOAT  ,0);
	class_addmethod(flenc_class ,(t_method)flenc_sign     ,gensym("s")    ,A_FLOAT  ,0);
	class_addmethod(flenc_class ,(t_method)flenc_f        ,gensym("f")    ,A_FLOAT  ,0);
	class_addmethod(flenc_class ,(t_method)flenc_u        ,gensym("u")    ,A_FLOAT  ,0);
	class_addmethod(flenc_class ,(t_method)flenc_set      ,gensym("set")  ,A_GIMME  ,0);
	class_addmethod(flenc_class ,(t_method)flenc_peek     ,gensym("peek") ,A_DEFSYM ,0);
}
