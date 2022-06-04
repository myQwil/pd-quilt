#include "unpaq.h"

/* -------------------------- reverse unpaq ------------------------------ */
static t_class *runpaq_class;

static void *runpaq_new(t_symbol *s ,int argc ,t_atom *argv) {
	return new_unpaq(runpaq_class ,s ,argc ,argv ,1);
}

static void unpaq_list(t_unpaq *x ,t_symbol *s ,int argc ,t_atom *argv) {
	(void)s;
	t_atom *ap;
	t_unpaqout *u;
	int i;
	if (argc > x->n) argc = (int)x->n;
	for (i = argc ,u = x->vec + i ,ap = argv; u-- ,i--; ap++)
	{	if (ap->a_type == A_SYMBOL && !strcmp(ap->a_w.w_symbol->s_name ,"."))
			continue;

		t_atomtype type = u->type;
		if (type == A_GIMME) type = ap->a_type;
		else if (type != ap->a_type)
		{	if ((x->mute >> i) & 1) pd_error(x ,"@unpaq: type mismatch");
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

void setup_0x40unpaq(void) {
	runpaq_class = class_new(gensym("@unpaq")
		,(t_newmethod)runpaq_new ,(t_method)unpaq_free
		,sizeof(t_unpaq) ,0
		,A_GIMME ,0);
	class_addlist     (runpaq_class ,unpaq_list);
	class_addanything (runpaq_class ,unpaq_anything);
	class_addmethod   (runpaq_class ,(t_method)unpaq_mute ,gensym("mute") ,A_FLOAT ,0);
	class_sethelpsymbol(runpaq_class ,gensym("rpaq"));
}
