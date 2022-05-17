#include "gmepd.h"

/* -------------------------- gme~ ------------------------------ */
static t_class *gme_tilde_class;

static void *gme_tilde_new(t_symbol *s ,int ac ,t_atom *av) {
	return gmepd_new(gme_tilde_class ,2 ,s ,ac ,av);
}

void gme_tilde_setup(void) {
	gme_tilde_class = gmepd_setup(gensym("gme~") ,(t_newmethod)gme_tilde_new);
	class_addmethod(gme_tilde_class ,(t_method)gmepd_dsp
		,gensym("dsp") ,A_CANT ,0);
}
