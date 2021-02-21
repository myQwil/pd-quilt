#include "m_pd.h"

/* -------------------------- has -------------------------- */
static t_class *has_class;

typedef struct _has {
	t_object obj;
	t_atom a;
} t_has;

static void *has_new(t_symbol *s ,int ac ,t_atom *av) {
	t_has *x = (t_has *)pd_new(has_class);
	x->a = (ac) ? *av : (t_atom){ A_FLOAT ,{0} };
	outlet_new(&x->obj ,&s_float);
	return (x);
}

static void has_list(t_has *x ,t_symbol *s ,int ac ,t_atom *av) {
	int found = 0;
	t_atomtype type = x->a.a_type;
	for (; ac--; av++)
		if (av->a_type == type)
			if ((type == A_FLOAT && av->a_w.w_float  == x->a.a_w.w_float)
			                     || av->a_w.w_symbol == x->a.a_w.w_symbol)
			{	found = 1;
				break;   }
	outlet_float(x->obj.ob_outlet ,found);
}

void has_setup(void) {
	has_class = class_new(gensym("has")
		,(t_newmethod)has_new ,0
		,sizeof(t_has) ,0
		,A_GIMME ,0);
	class_addlist(has_class ,has_list);
}
