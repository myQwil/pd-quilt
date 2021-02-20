#include "m_pd.h"

/* -------------------------- bitwise negation -------------------------- */
static t_class *bnot_class;

typedef struct _bnot {
	t_object obj;
	t_float f;
} t_bnot;

static void bnot_bang(t_bnot *x) {
	outlet_float(x->obj.ob_outlet ,~(int)x->f);
}

static void bnot_float(t_bnot *x ,t_float f) {
	outlet_float(x->obj.ob_outlet ,~(int)(x->f=f));
}

static void *bnot_new(t_floatarg f) {
	t_bnot *x = (t_bnot *)pd_new(bnot_class);
	outlet_new(&x->obj ,&s_float);
	x->f = f;
	return (x);
}

void setup_0x21_tilde(void) {
	bnot_class = class_new(gensym("!~")
		,(t_newmethod)bnot_new ,0
		,sizeof(t_bnot) ,0
		,A_DEFFLOAT ,0);
	class_addbang  (bnot_class ,bnot_bang);
	class_addfloat (bnot_class ,bnot_float);
	class_sethelpsymbol(bnot_class ,gensym("0x21~"));
}
