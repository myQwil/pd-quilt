#include "pak.h"

/* -------------------------- reverse pak ------------------------------ */
static t_class *rpak_class;
static t_class *rpak_proxy;

static void *rpak_new(t_symbol *s ,int argc ,t_atom *argv) {
	return (pak_init(rpak_class ,rpak_proxy ,argc ,argv ,1));
}

static int pak_first(t_pak *x) {
	return x->x_n - 1;
}
static int pak_index(t_pak_pxy *p) {
	return p->p_x->x_n - p->p_i - 1;
}

static void rpak_pointer(t_pak *x ,t_gpointer *gp) {
	int i = pak_first(x);
	t_gpointer *ptr = (i) ? x->x_ins[i-1]->p_ptr : x->x_ptr;
	pak_p(x ,ptr ,gp ,i);
}
static void rpak_pxy_pointer(t_pak_pxy *p ,t_gpointer *gp) {
	t_pak *x = p->p_x;
	int i = pak_index(p);
	t_gpointer *ptr = (i) ? x->x_ins[i-1]->p_ptr : x->x_ptr;
	pak_p(x ,ptr ,gp ,i);
}


static int pak_l(t_pak *x ,t_symbol *s ,int ac ,t_atom *av ,int i) {
	int result = 1;
	t_atom *vp = x->x_vec + i;
	t_atomtype *tp = x->x_type + i;
	t_pak_pxy **pp = x->x_ins + (i-1);
	for (i++; ac-- && i--; vp-- ,tp-- ,pp-- ,av++)
	{	if (av->a_type==A_SYMBOL && !strcmp(av->a_w.w_symbol->s_name ,"."))
			continue;
		t_gpointer *ptr = i ? (*pp)->p_ptr : x->x_ptr;
		if (!pak_set(x ,vp ,ptr ,*av ,*tp) && ((x->x_mute>>i) & 1))
		{	if (i >= x->x_n-1)
			{	pd_error(x ,"@pak_%s: wrong type" ,pak_check(av->a_type));
				result = 0;   }
			else pd_error(x ,"inlet: expected '%s' but got '%s'"
				,pak_check(*tp) ,pak_check(av->a_type));   }   }
	return result;
}

void setup_0x40pak(void) {
	rpak_class = class_new(gensym("@pak")
		,(t_newmethod)rpak_new ,(t_method)pak_free
		,sizeof(t_pak) ,0
		,A_GIMME ,0);
	class_addbang(rpak_class ,pak_bang);
	class_addpointer(rpak_class ,rpak_pointer);
	class_addfloat(rpak_class ,pak_float);
	class_addsymbol(rpak_class ,pak_symbol);
	class_addlist(rpak_class ,pak_list);
	class_addanything(rpak_class ,pak_anything);
	class_addmethod(rpak_class ,(t_method)pak_mute
		,gensym("mute") ,A_FLOAT ,0);
	class_sethelpsymbol(rpak_class ,gensym("rpak"));

	rpak_proxy = class_new(gensym("_@pak_proxy") ,0 ,0
		,sizeof(t_pak_pxy) ,CLASS_PD | CLASS_NOINLET ,0);
	class_addbang(rpak_proxy ,pak_pxy_bang);
	class_addpointer(rpak_proxy ,rpak_pxy_pointer);
	class_addfloat(rpak_proxy ,pak_pxy_float);
	class_addsymbol(rpak_proxy ,pak_pxy_symbol);
	class_addlist(rpak_proxy ,pak_pxy_list);
	class_addanything(rpak_proxy ,pak_pxy_anything);
}
