#include "gmepd.h"

/* -------------------------- gmes~ ------------------------------ */
static t_class *gmes_tilde_class;

static void *gmes_tilde_new(t_symbol *s, int ac, t_atom *av) {
	return gmepd_new(gmes_tilde_class, 16, s, ac, av);
}

void gmes_tilde_setup(void) {
	gmes_tilde_class = gmepd_setup(gensym("gmes~"), (t_newmethod)gmes_tilde_new);
	class_addmethod(gmes_tilde_class, (t_method)gmepd_dsp
	, gensym("dsp"), A_CANT, 0);
}
