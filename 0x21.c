#include "m_pd.h"

/* -------------------------- logical negation -------------------------- */
static t_class *lnot_class;

typedef struct {
	t_object obj;
	t_float f;
} t_lnot;

static void lnot_bang(t_lnot *x) {
	outlet_float(x->obj.ob_outlet ,!(int)x->f);
}

static void lnot_float(t_lnot *x ,t_float f) {
	outlet_float(x->obj.ob_outlet ,!(int)(x->f=f));
}

static void *lnot_new(t_float f) {
	t_lnot *x = (t_lnot *)pd_new(lnot_class);
	outlet_new(&x->obj ,&s_float);
	x->f = f;
	return (x);
}

void setup_0x21(void) {
	lnot_class = class_new(gensym("!")
		,(t_newmethod)lnot_new ,0
		,sizeof(t_lnot) ,0
		,A_DEFFLOAT ,0);
	class_addbang  (lnot_class ,lnot_bang);
	class_addfloat (lnot_class ,lnot_float);
	class_sethelpsymbol(lnot_class ,gensym("0x21"));
}
