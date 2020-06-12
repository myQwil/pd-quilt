#include "music.h"

/* -------------------------- chrd -------------------------- */
static t_class *chrd_class;

typedef struct _chrd {
	t_music m;
	unsigned x_all:1;   /* all-outlets toggle */
	unsigned x_midi:1;  /* midi-note toggle */
	t_outlet **x_outs;  /* outlets */
} t_chrd;

static void chrd_midi(t_chrd *x, t_floatarg f) {
	x->x_midi = f;
}

static void chrd_all(t_chrd *x, t_floatarg f) {
	x->x_all = f;
}

static double chrd_getnote(t_chrd *x, int d) {
	t_float root = x->m.scale[0];
	if (d==0) return root;
	
	int n=x->m.n-1, i=(d-(d>0))%n,
		b=i<0, q=(d-!b)/n-b;
	i += b*n+1;
	t_float step = x->m.scale[i];
	return (x->m.oct*q + root+step);
}

static void chrd_float(t_chrd *x, t_float f) {
	int d=f;
	double note = chrd_getnote(x, d);
	if (f!=d)
	{	int b = f<0?-1:1;
		double next = chrd_getnote(x, d+b);
		note += b*(f-d) * (next-note);   }
	int n=x->m.in-1, i=(d-(d>0))%n;
	i += (i<0)*n+1;
	if (d==0) i=0;
	outlet_float(x->x_outs[i], x->x_midi ?
		note : ntof(note, x->m.rt, x->m.st));
}

static void chrd_bang(t_chrd *x) {
	int n=x->m.n, i=x->m.in;
	i = x->x_all ? i : (n>i?i:n);
	for (t_outlet **op=x->x_outs+i; op--, i--;)
	{	double note = chrd_getnote(x, i);
		outlet_float(*op, x->x_midi ?
			note : ntof(note, x->m.rt, x->m.st));   }
}

static void *chrd_new(t_symbol *s, int ac, t_atom *av) {
	t_chrd *x = (t_chrd *)music_new(chrd_class);

	int n = x->m.n = x->m.in = x->m.p = ac<3 ? 3 : ac;
	x->m.scale = (t_float *)getbytes(x->m.p * sizeof(t_float));
	x->x_outs = (t_outlet **)getbytes(x->m.in * sizeof(t_outlet *));
	t_float *fp = x->m.scale;
	t_outlet **op = x->x_outs;
	fp[0]=69, fp[1]=7, fp[2]=12;

	for (int i=0; n--; op++,fp++,i++)
	{	*op = outlet_new(&x->m.obj, &s_float);
		floatinlet_new(&x->m.obj, fp);
		if (i<ac) *fp = atom_getfloat(av++);   }

	return (x);
}

static void chrd_free(t_chrd *x) {
	music_free((t_music *)x);
	freebytes(x->x_outs, x->m.in * sizeof(t_outlet *));
}

void chrd_setup(void) {
	chrd_class = class_new(gensym("chrd"),
		(t_newmethod)chrd_new, (t_method)chrd_free,
		sizeof(t_chrd), 0,
		A_GIMME, 0);
	class_addbang(chrd_class, chrd_bang);
	class_addfloat(chrd_class, chrd_float);
	class_addlist(chrd_class, music_list);
	class_addmethod(chrd_class, (t_method)music_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(chrd_class, (t_method)music_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(chrd_class, (t_method)music_at,
		gensym("@"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)music_doremi,
		gensym("d"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)music_list,
		gensym("l"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)music_i,
		gensym("i"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)music_x,
		gensym("x"), A_GIMME, 0);
	class_addmethod(chrd_class, (t_method)music_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)music_expl,
		gensym("expl"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)music_octave,
		gensym("oct"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)music_ref,
		gensym("ref"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)music_tet,
		gensym("tet"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)music_octet,
		gensym("ot"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_midi,
		gensym("midi"), A_FLOAT, 0);
	class_addmethod(chrd_class, (t_method)chrd_all,
		gensym("all"), A_FLOAT, 0);
}
