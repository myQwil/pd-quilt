#include "ufloat.h"

/* -------------------------- sploat -------------------------- */
static t_class *sploat_class;

typedef struct _sploat {
	t_object x_obj;
	ufloat uf;
	t_outlet *o_mt;
	t_outlet *o_ex;
	t_outlet *o_sg;
} t_sploat;

static void sploat_peek(t_sploat *x ,t_symbol *s) {
	ufloat uf = x->uf;
	post("%s%s0x%x %u %u = %g"
		,s->s_name ,*s->s_name?": ":""
		,uf.mt ,uf.ex ,uf.sg ,uf.f);
}

static void sploat_bang(t_sploat *x) {
	outlet_float(x->o_sg ,x->uf.sg);
	outlet_float(x->o_ex ,x->uf.ex);
	outlet_float(x->o_mt ,x->uf.mt);
}

static void sploat_set(t_sploat *x ,t_floatarg f) {
	x->uf.f = f;
}

static void sploat_float(t_sploat *x ,t_float f) {
	sploat_set(x ,f);
	sploat_bang(x);
}

static void *sploat_new(t_floatarg f) {
	t_sploat *x = (t_sploat *)pd_new(sploat_class);
	x->o_mt = outlet_new(&x->x_obj ,&s_float);
	x->o_ex = outlet_new(&x->x_obj ,&s_float);
	x->o_sg = outlet_new(&x->x_obj ,&s_float);
	inlet_new(&x->x_obj ,&x->x_obj.ob_pd ,&s_float ,gensym("set"));
	sploat_set(x ,f);
	return (x);
}

void sploat_setup(void) {
	sploat_class = class_new(gensym("sploat")
		,(t_newmethod)sploat_new ,0
		,sizeof(t_sploat) ,0
		,A_DEFFLOAT ,0);
	class_addbang  (sploat_class ,sploat_bang);
	class_addfloat (sploat_class ,sploat_float);
	class_addmethod(sploat_class ,(t_method)sploat_set
		,gensym("set")  ,A_FLOAT  ,0);
	class_addmethod(sploat_class ,(t_method)sploat_peek
		,gensym("peek") ,A_DEFSYM ,0);
}
