#include "note.h"

#ifndef FTON
#define FTON 0
#endif

typedef struct _ntof {
	t_object x_obj;
	t_note note;
} t_ntof;


static void ntof_ref(t_ntof *x ,t_floatarg f) {
	note_ref(&x->note ,f ,FTON);
}

static void ntof_tet(t_ntof *x ,t_floatarg f) {
	note_tet(&x->note ,f ,FTON);
}

static void ntof_set(t_ntof *x ,t_symbol *s ,int ac ,t_atom *av) {
	note_set(&x->note ,ac ,av ,FTON);
}

static t_ntof *new_ntof(t_class *cl ,int argc ,t_atom *argv) {
	t_ntof *x = (t_ntof *)pd_new(cl);
	outlet_new(&x->x_obj ,&s_float);
	inlet_new(&x->x_obj ,&x->x_obj.ob_pd ,&s_float ,gensym("ref"));
	inlet_new(&x->x_obj ,&x->x_obj.ob_pd ,&s_float ,gensym("tet"));

	t_float ref=440 ,tet=12;
	switch (argc)
	{	case 2: tet = atom_getfloat(argv+1);
		case 1: ref = atom_getfloat(argv);   }
	x->note.ref = ref;
	note_tet(&x->note ,tet ,FTON);

	return x;
}

static t_class *setup_ntof(t_symbol *s ,t_newmethod newm) {
	t_class *nclass = class_new(s ,newm ,0 ,sizeof(t_ntof) ,0 ,A_GIMME ,0);
	class_addmethod(nclass ,(t_method)ntof_ref
		,gensym("ref") ,A_FLOAT ,0);
	class_addmethod(nclass ,(t_method)ntof_tet
		,gensym("tet") ,A_FLOAT ,0);
	class_addmethod(nclass ,(t_method)ntof_set
		,gensym("set") ,A_GIMME ,0);

	return nclass;
}
