#include "m_pd.h"
#include <string.h>

/* -------------------------- is -------------------------- */
static t_class *is_class;
static t_class *is_proxy;

typedef struct _is t_is;

typedef struct _is_pxy {
	t_object obj;
	t_is *x;
} t_is_pxy;

struct _is {
	t_object obj;
	t_is_pxy *p;
	t_symbol *type;
};

static void is_peek(t_is *x ,t_symbol *s) {
	if (*s->s_name) startpost("%s: " ,s->s_name);
	post("%s" ,x->type->s_name);
}

static void is_bang(t_is *x) {
	outlet_float(x->obj.ob_outlet ,!strcmp(x->type->s_name ,"bang"));
}

static void is_anything(t_is *x ,t_symbol *s ,int ac ,t_atom *av) {
	int result = (x->type == s);
	outlet_float(x->obj.ob_outlet ,result);
}

static t_symbol *is_check(t_symbol *s) {
	const char *name = s->s_name;
	if (strlen(name) > 1) return s;
	switch (*name)
	{	case 'b': return &s_bang;
		case 'f': return &s_float;
		case 's': return &s_symbol;
		case 'p': return &s_pointer;
		case 'l': return &s_list;
		default : return s;   }
}

static void is_pxy_anything(t_is_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	p->x->type = is_check(s);
}

static void is_set(t_is *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (!ac) return;
	if      (av->a_type == A_SYMBOL)  x->type = is_check(av->a_w.w_symbol);
	else if (av->a_type == A_FLOAT)   x->type = &s_float;
	else if (av->a_type == A_POINTER) x->type = &s_pointer;
}

static void *is_new(t_symbol *s) {
	t_is *x = (t_is *)pd_new(is_class);
	t_is_pxy *p = (t_is_pxy *)pd_new(is_proxy);

	x->p = p;
	p->x = x;
	x->type = (*s->s_name) ? is_check(s) : &s_float;

	inlet_new((t_object *)x ,(t_pd *)p ,0 ,0);
	outlet_new(&x->obj ,&s_float);
	return (x);
}

static void is_free(t_is *x) {
	pd_free((t_pd *)x->p);
}

void is_setup(void) {
	is_class = class_new(gensym("is")
		,(t_newmethod)is_new ,(t_method)is_free
		,sizeof(t_is) ,0
		,A_DEFSYM ,0);
	class_addbang     (is_class ,is_bang);
	class_addanything (is_class ,is_anything);

	class_addmethod(is_class ,(t_method)is_set
		,gensym("set") ,A_GIMME  ,0);
	class_addmethod(is_class ,(t_method)is_peek
		,gensym("peek") ,A_DEFSYM ,0);

	is_proxy = class_new(gensym("_is_pxy") ,0 ,0
		,sizeof(t_is_pxy) ,CLASS_PD | CLASS_NOINLET ,0);
	class_addanything(is_proxy ,is_pxy_anything);
}
