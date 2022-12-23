#include "paq.h"

/* -------------------------- paq ------------------------------ */
static t_class *paq_class;
static t_class *paq_proxy;

static void *paq_new(t_symbol *s, int argc, t_atom *argv) {
	return new_paq(paq_class, paq_proxy, s, argc, argv, 0);
}

static void paq_pointer(t_paq *x, t_gpointer *gp) {
	paq_p(x, x->ptr, gp, 0);
}

static void paq_pxy_pointer(t_paq_pxy *p, t_gpointer *gp) {
	paq_p(p->x, p->ptr, gp, p->idx);
}

static int paq_l(t_paq *x, int ac, t_atom *av, int i) {
	int ins = x->n - i, result = 1;
	t_atom *vp = x->vec + i;
	t_atomtype *tp = x->type + i;
	t_paq_pxy **pp = x->ins + (i - 1);
	for (; ac-- && ins--; i++, vp++, tp++, pp++, av++) {
		if (av->a_type == A_SYMBOL && !strcmp(av->a_w.w_symbol->s_name, ".")) {
			continue;
		}
		t_gpointer *ptr = i ? (*pp)->ptr : x->ptr;
		if (!paq_set(vp, ptr, *av, *tp) && ((x->mute >> i) & 1)) {
			if (i) {
				pd_error(x, "inlet: expected '%s' but got '%s'"
				, paq_check(*tp), paq_check(av->a_type));
			} else {
				pd_error(x, "paq_%s: wrong type", paq_check(av->a_type));
				result = 0;
			}
		}
	}
	return result;
}

void paq_setup(void) {
	paq_class = class_new(gensym("paq")
	, (t_newmethod)paq_new, (t_method)paq_free
	, sizeof(t_paq), 0
	, A_GIMME, 0);
	paq_proxy = class_new(gensym("_paq_pxy")
	, 0, 0
	, sizeof(t_paq_pxy), CLASS_PD | CLASS_NOINLET
	, 0);
	class_addpaq(paq_class, paq_proxy);
	class_addpointer(paq_class, paq_pointer);
	class_addpointer(paq_proxy, paq_pxy_pointer);
}
