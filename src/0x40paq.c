#define PAQ_FIRST(x) ((x)->n - 1)
#define PAQ_INDEX(p) ((p)->x->n - (p)->idx - 1)

#include "paq.h"

/* -------------------------- reverse paq ------------------------------ */
static t_class *rpaq_class;
static t_class *rpaq_proxy;

static void *rpaq_new(t_symbol *s, int argc, t_atom *argv) {
	return new_paq(rpaq_class, rpaq_proxy, s, argc, argv, 1);
}

static void rpaq_pointer(t_paq *x, t_gpointer *gp) {
	int i = PAQ_FIRST(x);
	t_gpointer *ptr = (i) ? x->ins[i - 1]->ptr : x->ptr;
	paq_p(x, ptr, gp, i);
}

static void rpaq_pxy_pointer(t_paq_pxy *p, t_gpointer *gp) {
	t_paq *x = p->x;
	int i = PAQ_INDEX(p);
	t_gpointer *ptr = (i) ? x->ins[i - 1]->ptr : x->ptr;
	paq_p(x, ptr, gp, i);
}

static int paq_l(t_paq *x, int ac, t_atom *av, int i) {
	int result = 1;
	t_atom *vp = x->vec + i;
	t_atomtype *tp = x->type + i;
	t_paq_pxy **pp = x->ins + (i - 1);
	for (i++; ac-- && i--; vp--, tp--, pp--, av++) {
		if (av->a_type == A_SYMBOL && !strcmp(av->a_w.w_symbol->s_name, ".")) {
			continue;
		}
		t_gpointer *ptr = i ? (*pp)->ptr : x->ptr;
		if (!paq_set(vp, ptr, *av, *tp) && ((x->mute >> i) & 1)) {
			if (i >= x->n - 1) {
				pd_error(x, "@paq_%s: wrong type", paq_check(av->a_type));
				result = 0;
			} else {
				pd_error(x, "inlet: expected '%s' but got '%s'"
				, paq_check(*tp), paq_check(av->a_type));
			}
		}
	}
	return result;
}

void setup_0x40paq(void) {
	rpaq_class = class_new(gensym("@paq")
	, (t_newmethod)rpaq_new, (t_method)paq_free
	, sizeof(t_paq), 0
	, A_GIMME, 0);
	rpaq_proxy = class_new(gensym("_@paq_proxy")
	, 0, 0
	, sizeof(t_paq_pxy), CLASS_PD | CLASS_NOINLET
	, 0);
	class_addpaq(rpaq_class, rpaq_proxy);
	class_addpointer(rpaq_class, rpaq_pointer);
	class_addpointer(rpaq_proxy, rpaq_pxy_pointer);
	class_sethelpsymbol(rpaq_class, gensym("rpaq"));
}
