#include "unpaq.h"

/* -------------------------- unpaq ------------------------------ */
static t_class *unpaq_class;

static void *unpaq_new(t_symbol *s ,int argc ,t_atom *argv) {
	return new_unpaq(unpaq_class ,s ,argc ,argv ,0);
}

static void unpaq_list(t_unpaq *x ,t_symbol *s ,int argc ,t_atom *argv) {
	(void)s;
	t_atom *ap;
	t_unpaqout *u;
	int i;
	if (argc > x->n) argc = (int)x->n;
	for (i = argc ,u = x->vec + i ,ap = argv + i; u-- ,ap-- ,i--;)
	{	if (ap->a_type == A_SYMBOL && !strcmp(ap->a_w.w_symbol->s_name ,"."))
			continue;

		t_atomtype type = u->type;
		if (type == A_GIMME) type = ap->a_type;
		else if (type != ap->a_type)
		{	if ((x->mute >> i) & 1) pd_error(x ,"unpaq: type mismatch");
			continue;  }

		if (type == A_FLOAT)
			outlet_float(u->outlet ,ap->a_w.w_float);
		else if (type == A_SYMBOL)
		{	if (!strcmp(ap->a_w.w_symbol->s_name ,"bang"))
				outlet_bang(u->outlet);
			else outlet_symbol(u->outlet ,ap->a_w.w_symbol);  }
		else if (type == A_POINTER)
			outlet_pointer(u->outlet ,ap->a_w.w_gpointer);  }
}

void unpaq_setup(void) {
	unpaq_class = class_new(gensym("unpaq")
		,(t_newmethod)unpaq_new ,(t_method)unpaq_free
		,sizeof(t_unpaq) ,0
		,A_GIMME ,0);
	class_addlist     (unpaq_class ,unpaq_list);
	class_addanything (unpaq_class ,unpaq_anything);
	class_addmethod   (unpaq_class ,(t_method)unpaq_mute ,gensym("mute") ,A_FLOAT ,0);
	class_sethelpsymbol(unpaq_class ,gensym("paq"));
}
