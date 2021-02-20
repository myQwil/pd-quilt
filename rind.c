#include "m_pd.h"
#include <time.h>

/* -------------------------- rind -------------------------- */
static t_class *rind_class;

typedef struct _rind {
	t_object obj;
	t_float min;
	t_float max;
	unsigned state;
} t_rind;

static unsigned rind_time(void) {
	unsigned thym = (time(0) * 2) % 0x100000000;
	return (thym|1); // odd numbers only
}

static unsigned rind_makeseed(void) {
	static unsigned rind_next = 1378742615;
	rind_next = rind_next * rind_time() + 938284287;
	return rind_next;
}

static void rind_seed(t_rind *x ,t_symbol *s ,int ac ,t_atom *av) {
	x->state = ac ? (unsigned)atom_getfloat(av) : rind_time();
}

static void rind_state(t_rind *x ,t_symbol *s) {
	post("%s%s%u" ,s->s_name ,*s->s_name?": ":"" ,x->state);
}

static void rind_peek(t_rind *x ,t_symbol *s) {
	post("%s%s%g <=> %g" ,s->s_name ,*s->s_name?": ":"" ,x->max ,x->min);
}

static void rind_bang(t_rind *x) {
	double min=x->min ,range=x->max-min ,nval;
	unsigned *sp = &x->state;
	*sp = *sp * 472940017 + 832416023;
	nval = *sp * range / 0x100000000 + min;
	outlet_float(x->obj.ob_outlet ,nval);
}

static void rind_list(t_rind *x ,t_symbol *s ,int ac ,t_atom *av) {
	switch (ac)
	{	case 2: if (av[1].a_type == A_FLOAT) x->min = av[1].a_w.w_float;
		case 1: if (av[0].a_type == A_FLOAT) x->max = av[0].a_w.w_float;   }
}

static void *rind_new(t_symbol *s ,int ac ,t_atom *av) {
	t_rind *x = (t_rind *)pd_new(rind_class);
	outlet_new(&x->obj ,&s_float);

	floatinlet_new(&x->obj ,&x->max);
	if (ac != 1) floatinlet_new(&x->obj ,&x->min);

	switch (ac)
	{	case 2: x->min = atom_getfloat(av+1);
		case 1: x->max = atom_getfloat(av);   }
	if (!ac) x->max = 1;

	x->state = rind_makeseed();

	return (x);
}

void rind_setup(void) {
	rind_class = class_new(gensym("rind")
		,(t_newmethod)rind_new ,0
		,sizeof(t_rind) ,0
		,A_GIMME ,0);
	class_addbang(rind_class ,rind_bang);
	class_addlist(rind_class ,rind_list);
	class_addmethod(rind_class ,(t_method)rind_seed
		,gensym("seed")  ,A_GIMME  ,0);
	class_addmethod(rind_class ,(t_method)rind_state
		,gensym("state") ,A_DEFSYM ,0);
	class_addmethod(rind_class ,(t_method)rind_peek
		,gensym("peek")  ,A_DEFSYM ,0);
}
