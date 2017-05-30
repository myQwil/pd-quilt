#include "m_pd.h"
#include <math.h>

/* -------------------------- ntof -------------------------- */

t_float ntof(t_float f, double root, double semi) {
	return (root * exp(semi*f));
}

static t_class *ntof_class;
static t_class *ntof_ref_class;
static t_class *ntof_tet_class;

typedef struct _ntof {
	t_object x_obj;
	double x_rt, x_st;		/* root tone, semi-tone */
	t_float x_ref, x_tet;	/* ref-pitch, # of tones */
	t_pd *p_ref, *p_tet;
} t_ntof;

typedef struct _ntof_proxy {
	t_object p_obj;
	t_ntof *p_master;
} t_ntof_proxy;

static void ntof_ref(t_ntof *x, t_floatarg f) {
	x->x_rt = (x->x_ref=f) * pow(2,-69/x->x_tet);
}

static void ntof_tet(t_ntof *x, t_floatarg f) {
	x->x_rt = x->x_ref * pow(2,-69/f);
	x->x_st = log(2) / (x->x_tet=f);
}

static void ntof_ref_float(t_ntof_proxy *x, t_float f) {
	t_ntof *m = x->p_master;
	ntof_ref(m, f);
}

static void ntof_tet_float(t_ntof_proxy *x, t_float f) {
	t_ntof *m = x->p_master;
	ntof_tet(m, f);
}

static void ntof_float(t_ntof *x, t_float f) {
	outlet_float(x->x_obj.ob_outlet, ntof(f, x->x_rt, x->x_st));
}

static void *ntof_new(t_symbol *s, int argc, t_atom *argv) {
	t_ntof *x = (t_ntof *)pd_new(ntof_class);
	outlet_new(&x->x_obj, &s_float);
	
	t_pd *pref = pd_new(ntof_ref_class);
	x->p_ref = pref;
	((t_ntof_proxy *)pref)->p_master = x;
	inlet_new(&x->x_obj, pref, 0, 0);
	
	t_pd *ptet = pd_new(ntof_tet_class);
	x->p_tet = ptet;
	((t_ntof_proxy *)ptet)->p_master = x;
	inlet_new(&x->x_obj, ptet, 0, 0);
	
	t_float ref=440, tet=12;
	switch (argc)
	{ case 2: tet = atom_getfloat(argv+1);
	  case 1: ref = atom_getfloat(argv); }
	x->x_rt = (x->x_ref=ref) * pow(2,-69/tet);
	x->x_st = log(2) / (x->x_tet=tet);
	return (x);
}

static void ntof_free(t_ntof *x) {
	pd_free(x->p_ref); pd_free(x->p_tet);
}

void ntof_setup(void) {
	ntof_class = class_new(gensym("ntof"),
		(t_newmethod)ntof_new, (t_method)ntof_free,
		sizeof(t_ntof), 0,
		A_GIMME, 0);
	class_addfloat(ntof_class, ntof_float);
	class_addmethod(ntof_class, (t_method)ntof_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(ntof_class, (t_method)ntof_tet,
		gensym("tet"), A_FLOAT, 0);
	
	ntof_ref_class = class_new(gensym("_ntof_ref"), 0, 0,
		sizeof(t_ntof_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(ntof_ref_class, ntof_ref_float);
	
	ntof_tet_class = class_new(gensym("_ntof_tet"), 0, 0,
		sizeof(t_ntof_proxy),
		CLASS_PD | CLASS_NOINLET, 0);
	class_addfloat(ntof_tet_class, ntof_tet_float);
}
