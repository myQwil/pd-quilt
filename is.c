#include "m_pd.h"
#include <string.h>

/* -------------------------- is -------------------------- */

static t_class *is_class;
static t_class *is_proxy_class;

typedef struct _is {
	t_object x_obj;
	t_symbol *x_type;
	struct _is_proxy *x_p;
} t_is;

typedef struct _is_proxy {
	t_object p_obj;
	t_is *p_owner;
} t_is_proxy;

static void is_peek(t_is *x, t_symbol *s) {
	if (*s->s_name) startpost("%s: ", s->s_name);
	post("%s", x->x_type->s_name);
}

static void is_bang(t_is *x) {
	outlet_float(x->x_obj.ob_outlet, !strcmp(x->x_type->s_name, "bang"));
}

static void is_anything(t_is *x, t_symbol *s, int ac, t_atom *av) {
	int result = (x->x_type == s);
	outlet_float(x->x_obj.ob_outlet, result);
}

static t_symbol *is_check(t_symbol *s) {
	const char *name = s->s_name;
	if      (!strcmp(name, "b")) return &s_bang;
	else if (!strcmp(name, "f")) return &s_float;
	else if (!strcmp(name, "s")) return &s_symbol;
	else if (!strcmp(name, "l")) return &s_list;
	else if (!strcmp(name, "p")) return &s_pointer;
	else return s;
}

static void is_proxy_anything(t_is_proxy *p, t_symbol *s, int ac, t_atom *av) {
	p->p_owner->x_type = is_check(s);
}

static void is_type(t_is *x, t_symbol *s, int ac, t_atom *av) {
	if (!ac) return;
	if (av->a_type == A_SYMBOL) x->x_type = is_check(av->a_w.w_symbol);
	else if (av->a_type == A_FLOAT) x->x_type = gensym("float");
	else if (av->a_type == A_POINTER) x->x_type = gensym("pointer");
}

static void *is_new(t_symbol *s) {
	t_is *x = (t_is *)pd_new(is_class);
	t_is_proxy *p = (t_is_proxy *)pd_new(is_proxy_class);

	x->x_p = p;
	p->p_owner = x;
	x->x_type = (*s->s_name) ? is_check(s) : gensym("float");

	inlet_new((t_object *)x, (t_pd *)p, 0, 0);
	outlet_new(&x->x_obj, &s_float);
	return (x);
}

static void is_free(t_is *x) {
	if (x->x_p) pd_free((t_pd *)x->x_p);
}

void is_setup(void) {
	is_class = class_new(gensym("is"),
		(t_newmethod)is_new, (t_method)is_free,
		sizeof(t_is), 0,
		A_DEFSYM, 0);
	class_addbang(is_class, is_bang);
	class_addanything(is_class, is_anything);
	class_addmethod(is_class, (t_method)is_type,
		gensym("type"), A_GIMME, 0);
	class_addmethod(is_class, (t_method)is_peek,
		gensym("peek"), A_DEFSYM, 0);

	is_proxy_class = class_new(gensym("_is_proxy"), 0, 0,
		sizeof(t_is_proxy), CLASS_PD | CLASS_NOINLET, 0);
	class_addanything(is_proxy_class, is_proxy_anything);
}
