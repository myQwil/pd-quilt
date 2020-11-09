#include "unpak.h"

/* -------------------------- unpak ------------------------------ */
static t_class *unpak_class;

static void *unpak_new(t_symbol *s ,int argc ,t_atom *argv) {
	return (unpak_init(unpak_class ,argc ,argv ,0));
}

static void unpak_list(t_unpak *x ,t_symbol *s ,int argc ,t_atom *argv) {
	t_atom *ap;
	t_unpakout *u;
	int i;
	if (argc > x->x_n) argc = (int)x->x_n;
	for (i = argc ,u = x->x_vec + i ,ap = argv + i; u-- ,ap-- ,i--;)
	{	if (ap->a_type==A_SYMBOL && !strcmp(ap->a_w.w_symbol->s_name ,"."))
			continue;

		t_atomtype type = u->u_type;
		if (type == A_GIMME) type = ap->a_type;
		else if (type != ap->a_type)
		{	if ((x->x_mute>>i)&1) pd_error(x ,"unpak: type mismatch");
			continue;   }

		if (type == A_FLOAT)
			outlet_float(u->u_outlet ,ap->a_w.w_float);
		else if (type == A_SYMBOL)
		{	if (!strcmp(ap->a_w.w_symbol->s_name ,"bang"))
				outlet_bang(u->u_outlet);
			else outlet_symbol(u->u_outlet ,ap->a_w.w_symbol);   }
		else if (type == A_POINTER)
			outlet_pointer(u->u_outlet ,ap->a_w.w_gpointer);   }
}

void unpak_setup(void) {
	unpak_class = class_new(gensym("unpak")
		,(t_newmethod)unpak_new ,(t_method)unpak_free
		,sizeof(t_unpak) ,0
		,A_GIMME ,0);
	class_addlist      (unpak_class ,unpak_list);
	class_addanything  (unpak_class ,unpak_anything);
	class_addmethod    (unpak_class ,(t_method)unpak_mute
		,gensym("mute") ,A_FLOAT ,0);
	class_sethelpsymbol(unpak_class ,gensym("pak"));
}
