#define NCH 16
#define MULTI 1
#include "gme~.h"

/* -------------------------- gmes~ ------------------------------ */
static t_class *gmes_tilde_class;

static void gmes_tilde_dsp(t_gme_tilde *x, t_signal **sp) {
	dsp_add(gme_tilde_perform, NCH+2, x,
		sp[0]->s_vec, sp[1]->s_vec, sp[2]->s_vec, sp[3]->s_vec,
		sp[4]->s_vec, sp[5]->s_vec, sp[6]->s_vec, sp[7]->s_vec,
		sp[8]->s_vec, sp[9]->s_vec, sp[10]->s_vec, sp[11]->s_vec,
		sp[12]->s_vec, sp[13]->s_vec, sp[14]->s_vec, sp[15]->s_vec, sp[0]->s_n);
}

static void *gmes_tilde_new(t_symbol *s, int ac, t_atom *av) {
	return (gme_new(gmes_tilde_class, s, ac, av));
}

extern "C" EXPORT void gmes_tilde_setup(void) {
	gmes_tilde_class = class_new(gensym("gmes~"),
		(t_newmethod)gmes_tilde_new, (t_method)gme_tilde_free,
		sizeof(t_gme_tilde), 0,
		A_GIMME, 0);
	class_addbang(gmes_tilde_class, gme_tilde_bang);
	class_addfloat(gmes_tilde_class, gme_tilde_float);
	class_addmethod(gmes_tilde_class, (t_method)gmes_tilde_dsp,
		gensym("dsp"), A_CANT, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_info,
		gensym("info"), A_DEFSYM, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_path,
		gensym("path"), A_DEFSYM, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_read,
		gensym("read"), A_DEFSYM, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_goto,
		gensym("goto"), A_FLOAT, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_tempo,
		gensym("tempo"), A_FLOAT, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_track,
		gensym("track"), A_FLOAT, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_time,
		gensym("time"), A_GIMME, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_mute,
		gensym("mute"), A_GIMME, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_solo,
		gensym("solo"), A_GIMME, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_mask,
		gensym("mask"), A_GIMME, 0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_stop,
		gensym("stop"), (t_atomtype)0);
	class_addmethod(gmes_tilde_class, (t_method)gme_tilde_bang,
		gensym("play"), (t_atomtype)0);
}
