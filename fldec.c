#include "ufloat.h"

/* -------------------------- fldec -------------------------- */
static t_class *fldec_class;

typedef struct {
	t_object obj;
	ufloat uf;
	t_outlet *o_mt;
	t_outlet *o_ex;
	t_outlet *o_sg;
} t_fldec;

static void fldec_peek(t_fldec *x ,t_symbol *s) {
	ufloat uf = x->uf;
	post("%s%s0x%x %u %u = %g"
		,s->s_name ,*s->s_name?": ":""
		,uf.mt ,uf.ex ,uf.sg ,uf.f);
}

static void fldec_bang(t_fldec *x) {
	outlet_float(x->o_sg ,x->uf.sg);
	outlet_float(x->o_ex ,x->uf.ex);
	outlet_float(x->o_mt ,x->uf.mt);
}

static void fldec_set(t_fldec *x ,t_float f) {
	x->uf.f = f;
}

static void fldec_float(t_fldec *x ,t_float f) {
	fldec_set(x ,f);
	fldec_bang(x);
}

static void *fldec_new(t_float f) {
	t_fldec *x = (t_fldec*)pd_new(fldec_class);
	x->o_mt = outlet_new(&x->obj ,&s_float);
	x->o_ex = outlet_new(&x->obj ,&s_float);
	x->o_sg = outlet_new(&x->obj ,&s_float);
	inlet_new(&x->obj ,&x->obj.ob_pd ,&s_float ,gensym("set"));
	fldec_set(x ,f);
	return (x);
}

void fldec_setup(void) {
	fldec_class = class_new(gensym("fldec")
		,(t_newmethod)fldec_new ,0
		,sizeof(t_fldec) ,0
		,A_DEFFLOAT ,0);
	class_addbang  (fldec_class ,fldec_bang);
	class_addfloat (fldec_class ,fldec_float);
	class_addmethod(fldec_class ,(t_method)fldec_set  ,gensym("set")  ,A_FLOAT  ,0);
	class_addmethod(fldec_class ,(t_method)fldec_peek ,gensym("peek") ,A_DEFSYM ,0);
	class_sethelpsymbol(fldec_class ,gensym("flenc"));
}
