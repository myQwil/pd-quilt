#include "m_pd.h"
#include <math.h>

/* -------------------------- ruse -------------------------- */

static t_class *ruse_class;

typedef struct _ruse {
	t_object x_obj;
	t_int x_n, x_max;		/* # of notes in a scale */
	t_float x_oct;			/* octave */
	t_float *x_scl;			/* scale-input values */
	t_outlet *f_out, *m_out;/* frequency, midi */
} t_ruse;

static void ruse_float(t_ruse *x, t_float f) {
	double root=x->x_scl[0], oct=x->x_oct, round=0,
		rock=fmod(root,oct), fock=fmod(f-rock,oct);
	int i, croc=(f-rock)/oct;
	t_float *fp;
	for (i=x->x_n, fp=x->x_scl; i--;)
	{	double item = (i?fp[i]:0);
		if (fabs(fock-round) > fabs(item-fock)) round=item;   }
	if (fabs(fock-round) > fabs(oct-fock)) round=oct;
	double note = oct*croc + rock + round;
	outlet_float(x->m_out, note);
	outlet_float(x->f_out, mtof(note));
}

static void ruse_list(t_ruse *x, t_symbol *s, int ac, t_atom *av) {
	if (!ac||ac>=x->x_max)
	{ pd_error(x, "ruse: too many/few args"); return; }
	
	int i; t_float *fp = x->x_scl+1;
	x->x_n=ac+1;
	for (i=ac; i--; av++, fp++)
		if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
}

static void ruse_key(t_ruse *x, t_symbol *s, int ac, t_atom *av) {
	if (!ac||ac>x->x_max)
	{ pd_error(x, "ruse: too many/few args"); return; }
	
	if (av->a_type == A_FLOAT) *x->x_scl = av->a_w.w_float;
	if (ac>1) ruse_list(x, 0, ac-1, av+1);
}

static void ruse_size(t_ruse *x, t_floatarg f) {
	x->x_n = f;
}

static void ruse_octave(t_ruse *x, t_floatarg f) {
	x->x_oct = f;
}

static void *ruse_new(t_symbol *s, int argc, t_atom *argv) {
	t_ruse *x = (t_ruse *)pd_new(ruse_class);
	
	x->x_oct = 12;
	x->x_max = (argc > 12 ? argc : 12); // enough space for a chromatic scale
	x->x_scl = (t_float *)getbytes(x->x_max * sizeof(t_float));
	
	if (argc < 2) {
		*x->x_scl = (argc ? atom_getfloat(argv) : 0);
		floatinlet_new(&x->x_obj, x->x_scl);
		*(x->x_scl+1) = 7; // perfect fifth
		x->x_n = 2;
		argc = 0;
	} else x->x_n = argc;
	
	int i; t_float *fp;
	for (i=argc, fp=x->x_scl; i--; argv++, fp++)
	{	*fp = atom_getfloat(argv);
		floatinlet_new(&x->x_obj, fp);   }
	x->f_out = outlet_new(&x->x_obj, &s_float); // frequency
	x->m_out = outlet_new(&x->x_obj, &s_float); // midi note
	return (x);
}

static void ruse_free(t_ruse *x) {
	freebytes(x->x_scl, x->x_max * sizeof(*x->x_scl));
}

void ruse_setup(void) {
	ruse_class = class_new(gensym("ruse"),
		(t_newmethod)ruse_new, (t_method)ruse_free,
		sizeof(t_ruse), 0,
		A_GIMME, 0);
		
	class_addfloat(ruse_class, ruse_float);
	class_addlist(ruse_class, ruse_list);
	class_addmethod(ruse_class, (t_method)ruse_key,
		gensym("k"), A_GIMME, 0);
	class_addmethod(ruse_class, (t_method)ruse_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(ruse_class, (t_method)ruse_octave,
		gensym("oct"), A_FLOAT, 0);
}
