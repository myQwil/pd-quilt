#include "note.h"

typedef struct {
	t_object obj;
	t_note note;
} t_tone;


static void tone_ref(t_tone *x, t_float f) {
	note_ref(&x->note, f);
}

static void tone_tet(t_tone *x, t_float f) {
	note_tet(&x->note, f);
}

static void tone_list(t_tone *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	note_set(&x->note, ac, av);
}

static t_tone *tone_new(t_class *cl, t_symbol *s, int argc, t_atom *argv) {
	(void)s;
	t_tone *x = (t_tone *)pd_new(cl);
	outlet_new(&x->obj, &s_float);
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("ref"));
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("tet"));

	t_float ref = 440, tet = 12;
	switch (argc) {
	case 2: tet = atom_getfloat(argv + 1);
	// fall through
	case 1: ref = atom_getfloat(argv);
	}
	x->note.ref = ref;
	note_tet(&x->note, tet);

	return x;
}

static t_class *class_tone(t_symbol *s, t_newmethod newm) {
	t_class *nclass = class_new(s, newm, 0, sizeof(t_tone), 0, A_GIMME, 0);
	class_addlist(nclass, tone_list);
	class_addmethod(nclass, (t_method)tone_ref, gensym("ref"), A_FLOAT, 0);
	class_addmethod(nclass, (t_method)tone_tet, gensym("tet"), A_FLOAT, 0);
	class_addmethod(nclass, (t_method)tone_list, gensym("set"), A_GIMME, 0);

	return nclass;
}
