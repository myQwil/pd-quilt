#define NCH 2
#include "gmepd.h"

/* -------------------------- gme~ ------------------------------ */
static t_class *gme_tilde_class;

static void gme_tilde_dsp(t_gme *x ,t_signal **sp) {
	dsp_add(gmepd_perform ,NCH+4 ,x ,sp[0]->s_vec ,sp[1]->s_vec
		,sp[2]->s_vec ,sp[3]->s_vec ,sp[0]->s_n);
}

static void *gme_tilde_new(t_symbol *s ,int ac ,t_atom *av) {
	return (gmepd_new(gme_tilde_class ,s ,ac ,av));
}

void gme_tilde_setup(void) {
	gme_tilde_class = gmepd_setup(gensym("gme~") ,(t_newmethod)gme_tilde_new);
	class_addmethod(gme_tilde_class ,(t_method)gme_tilde_dsp
		,gensym("dsp") ,A_CANT ,0);
}
