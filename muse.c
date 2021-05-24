#include "music.h"

/* -------------------------- muse -------------------------- */
static t_class *muse_class;

typedef struct {
	t_music z;
	t_outlet *o_freq;    /* frequency outlet */
	t_outlet *o_midi;    /* midi outlet */
} t_muse;

static void music_f(t_music *x ,t_float f ,char c ,t_float g) {
	t_float note = x->flin.fp[0] + music_interval(x ,x->flin.fp ,f);
	if (c) music_operate(&note ,c ,g);

	t_muse *y = (t_muse*)x;
	outlet_float(y->o_midi ,note);
	outlet_float(y->o_freq ,ntof(&x->note ,note));
}

static void muse_slice(t_muse *y ,t_symbol *s ,int ac ,t_atom *av) {
	t_music *x = &y->z;
	int n = x->siz;
	int strt=0 ,stop=n ,step=0;
	if (ac > 2 && av[2].a_type == A_FLOAT)
	{	step = atom_getint(av+2);
		if (step < 0)
			strt = n ,stop = 0;   }
	if (ac > 1 && av[1].a_type == A_FLOAT)
	{	stop = atom_getint(av+1) % n;
		if (stop < 0)
			stop += n;   }
	if (ac > 0 && av[0].a_type == A_FLOAT)
	{	strt = atom_getint(av+0) % n;
		if (strt < 0)
			strt += n;   }
	if (!step)
		step = (strt > stop) ? -1 : 1;

	t_float *fp = x->flin.fp;
	int rev = (step < 0);
	step = abs(step);
	t_atom flts[(abs(strt - stop) - 1) / step + 1];
	if (rev)
	{	strt-- ,stop--;
		for (n = 0; strt > stop; strt -= step)
			flts[n++] = (t_atom){ A_FLOAT ,{fp[strt]} };   }
	else
	{	for (n = 0; strt < stop; strt += step)
			flts[n++] = (t_atom){ A_FLOAT ,{fp[strt]} };   }
	outlet_anything(y->o_midi ,gensym("slice") ,n ,flts);
}

static void *muse_new(t_symbol *s ,int ac ,t_atom *av) {
	int n = ac < 2 ? 2 : ac;
	t_muse *y = (t_muse *)music_new(muse_class ,n);
	t_music *x = &y->z;

	y->o_freq = outlet_new(&x->flin.obj ,&s_float);
	y->o_midi = outlet_new(&x->flin.obj ,0);

	t_float *fp = x->flin.fp;
	fp[0]=69 ,fp[1]=7;

	for (int i=0; n--; fp++,i++)
	{	floatinlet_new(&x->flin.obj ,fp);
		if (i < ac)
			*fp = atom_getfloat(av++);   }

	return (y);
}

void muse_setup(void) {
	muse_class = music_setup(gensym("muse")
		,(t_newmethod)muse_new ,(t_method)flin_free ,sizeof(t_muse));
	class_addmethod(muse_class ,(t_method)muse_slice
		,gensym("slice") ,A_GIMME ,0);
}
