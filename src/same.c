#include "m_pd.h"

/* -------------------------- same -------------------------- */
static t_class *same_class;

typedef struct {
	t_object obj;
	t_float f;
	t_outlet *o_same;
} t_same;

static void *same_new(t_float f) {
	t_same *x = (t_same*)pd_new(same_class);
	x->f = f;
	outlet_new(&x->obj ,&s_float);
	x->o_same = outlet_new(&x->obj ,&s_float);
	return (x);
}

static void same_bang(t_same *x) {
	outlet_float(x->obj.ob_outlet ,x->f);
}

static void same_float(t_same *x ,t_float f) {
	if (x->f != f)
	{	x->f = f;
		outlet_float(x->obj.ob_outlet ,f);  }
	else outlet_float(x->o_same ,f);
}

static void same_set(t_same *x ,t_float f) {
	x->f = f;
}

void same_setup(void) {
	same_class = class_new(gensym("same")
		,(t_newmethod)same_new ,0
		,sizeof(t_same) ,0
		,A_DEFFLOAT ,0);
	class_addbang  (same_class ,same_bang);
	class_addfloat (same_class ,same_float);
	class_addmethod(same_class ,(t_method)same_set ,gensym("set") ,A_DEFFLOAT ,0);
}
