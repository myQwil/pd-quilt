#include "m_pd.h"

/******************** tabread2~ ***********************/

static t_class *tabread2_class;

typedef struct {
	t_object obj;
	t_symbol *arrayname;
	t_word *vec;
	t_float f;
	t_float onset;
	t_float edge;
	t_float k;
	int npoints;
} t_tabread2;

static inline void tabread2_edge(t_tabread2 *x ,t_float edge) {
	x->edge = edge;
	x->k = 1. / (1. - edge);
}

static t_int *tabread2_perform(t_int *w) {
	t_tabread2 *x = (t_tabread2*)(w[1]);
	t_sample *in1 = (t_sample*)(w[2]);
	t_sample *in2 = (t_sample*)(w[3]);
	t_sample *out = (t_sample*)(w[4]);
	int n = (int)(w[5]);
	int maxindex;
	t_word *buf = x->vec ,*wp;
	double onset = x->onset;

	maxindex = x->npoints - 3;
	if(maxindex<0) goto zero;

	if (!buf) goto zero;

	for (t_sample frac ,edge ,a ,b; n--;)
	{	double findex = *in1++ + onset;
		int index = findex;
		if (index < 1)
			index = 1 ,frac = 0;
		else if (index > maxindex)
			index = maxindex ,frac = 1;
		else frac = findex - index;
		wp = buf + index;
		edge = *in2++;
		if (frac <= edge)
			*out++ = wp[0].w_float;
		else
		{	if (x->edge != edge)
				tabread2_edge(x ,edge);
			a = wp[0].w_float;
			b = wp[1].w_float;
			*out++ = a + (frac - edge) * x->k * (b - a);  }  }
	return (w+6);
 zero:
	while (n--) *out++ = 0;

	return (w+6);
}

static void tabread2_set(t_tabread2 *x ,t_symbol *s) {
	t_garray *a;

	x->arrayname = s;
	if (!(a = (t_garray*)pd_findbyclass(x->arrayname ,garray_class)))
	{	if (*s->s_name)
			pd_error(x ,"tabread2~: %s: no such array" ,x->arrayname->s_name);
		x->vec = 0;  }
	else if (!garray_getfloatwords(a ,&x->npoints ,&x->vec))
	{	pd_error(x ,"%s: bad template for tabread2~" ,x->arrayname->s_name);
		x->vec = 0;  }
	else garray_usedindsp(a);
}

static void tabread2_dsp(t_tabread2 *x ,t_signal **sp) {
	tabread2_set(x ,x->arrayname);

	dsp_add(tabread2_perform ,5 ,x
		,sp[0]->s_vec ,sp[1]->s_vec ,sp[2]->s_vec ,(t_int)sp[0]->s_n);

}

static void *tabread2_new(t_symbol *s ,t_float edge) {
	t_tabread2 *x = (t_tabread2*)pd_new(tabread2_class);
	x->arrayname = s;
	x->vec = 0;

	tabread2_edge(x ,edge);
	signalinlet_new(&x->obj ,edge);
	floatinlet_new(&x->obj ,&x->onset);
	outlet_new(&x->obj ,gensym("signal"));
	x->f = 0;
	x->onset = 0;
	return (x);
}

void tabread2_tilde_setup(void) {
	tabread2_class = class_new(gensym("tabread2~")
		,(t_newmethod)tabread2_new ,0
		,sizeof(t_tabread2) ,0
		,A_DEFSYM ,A_DEFFLOAT ,0);
	CLASS_MAINSIGNALIN(tabread2_class ,t_tabread2 ,f);
	class_addmethod(tabread2_class ,(t_method)tabread2_dsp ,gensym("dsp") ,A_CANT   ,0);
	class_addmethod(tabread2_class ,(t_method)tabread2_set ,gensym("set") ,A_SYMBOL ,0);
}
