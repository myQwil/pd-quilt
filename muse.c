#include "music.h"

/* -------------------------- muse -------------------------- */
static t_class *muse_class;

typedef struct _muse {
	t_music m;
	t_outlet *o_freq;    /* frequency outlet */
	t_outlet *o_midi;    /* midi outlet */
} t_muse;

static double muse_getnote(t_muse *x, int d) {
	int n=x->m.n, i=d%n, b=i<0, q=d/n-b;
	i += b*n;
	t_float root = x->m.scale[0],
		step = i ? x->m.scale[i] : 0;
	return (x->m.oct*q + root+step);
}

static void muse_float(t_muse *x, t_float f) {
	int d=f;
	double note = muse_getnote(x, d);
	if (f!=d)
	{	int b = f<0?-1:1;
		double next = muse_getnote(x, d+b);
		note += b*(f-d) * (next-note);   }
	outlet_float(x->o_midi, note);
	outlet_float(x->o_freq, ntof(note, x->m.rt, x->m.st));
}

static void *muse_new(t_symbol *s, int ac, t_atom *av) {
	t_muse *x = (t_muse *)music_new(muse_class);
	x->o_freq = outlet_new(&x->m.obj, &s_float);
	x->o_midi = outlet_new(&x->m.obj, &s_float);

	int n = x->m.n = x->m.in = x->m.p = ac<2 ? 2 : ac;
	x->m.scale = (t_float *)getbytes(x->m.p * sizeof(t_float));
	t_float *fp = x->m.scale;
	fp[0]=69, fp[1]=7;

	for (int i=0; n--; fp++, i++)
	{	floatinlet_new(&x->m.obj, fp);
		if (i<ac) *fp = atom_getfloat(av++);   }

	return (x);
}

void muse_setup(void) {
	muse_class = class_new(gensym("muse"),
		(t_newmethod)muse_new, (t_method)music_free,
		sizeof(t_muse), 0,
		A_GIMME, 0);
	class_addfloat(muse_class, muse_float);
	class_addlist(muse_class, music_list);
	class_addmethod(muse_class, (t_method)music_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(muse_class, (t_method)music_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(muse_class, (t_method)music_at,
		gensym("@"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)music_doremi,
		gensym("d"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)music_list,
		gensym("l"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)music_i,
		gensym("i"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)music_x,
		gensym("x"), A_GIMME, 0);
	class_addmethod(muse_class, (t_method)music_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)music_expl,
		gensym("expl"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)music_octave,
		gensym("oct"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)music_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)music_tet,
		gensym("tet"), A_FLOAT, 0);
	class_addmethod(muse_class, (t_method)music_octet,
		gensym("ot"), A_FLOAT, 0);
}
