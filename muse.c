#include "music.h"

/* -------------------------- muse -------------------------- */
static t_class *muse_class;

typedef struct _muse {
	t_music z;
	t_outlet *o_freq;    /* frequency outlet */
	t_outlet *o_midi;    /* midi outlet */
} t_muse;

static double muse_note(t_music *x ,int d) {
	int n = x->siz ,i = d%n ,neg = i<0;
	i += n * neg;
	t_float step = i ? x->flin.fp[i] : 0;
	return (x->oct * (d/n - neg) + x->flin.fp[0] + step);
}

static void muse_float(t_muse *y ,t_float f) {
	t_music *x = &y->z;
	int d = f;
	double nte = muse_note(x ,d);
	if (f != d)
	{	int dir = f<0 ? -1 : 1;
		double nxt = muse_note(x ,d+dir);
		nte += dir * (f-d) * (nxt-nte);   }
	outlet_float(y->o_midi ,nte);
	outlet_float(y->o_freq ,ntof(&x->note ,nte));
}

static void muse_send(t_muse *y ,t_float f) {
	t_music *x = &y->z;
	int i=f ,ac=x->siz-i ,n=ac;
	t_float *fp = x->flin.fp + i;
	t_atom flts[ac];
	while (n--) flts[n] = (t_atom){ A_FLOAT ,{fp[n]}};
	outlet_list(y->o_midi ,0 ,ac ,flts);
}

static void *muse_new(t_symbol *s ,int ac ,t_atom *av) {
	int n = (ac<2 ? 2 : ac);
	t_muse *y = (t_muse *)music_new(muse_class ,n);
	t_music *x = &y->z;

	y->o_freq = outlet_new(&x->flin.x_obj ,&s_float);
	y->o_midi = outlet_new(&x->flin.x_obj ,0);

	t_float *fp = x->flin.fp;
	fp[0]=69 ,fp[1]=7;

	for (int i=0; n--; fp++,i++)
	{	floatinlet_new(&x->flin.x_obj ,fp);
		if (i<ac) *fp = atom_getfloat(av++);   }

	return (y);
}

void muse_setup(void) {
	muse_class = music_setup(gensym("muse")
		,(t_newmethod)muse_new ,(t_method)flin_free ,sizeof(t_muse));
	class_addfloat(muse_class ,muse_float);
	class_addmethod(muse_class ,(t_method)muse_send
		,gensym("send")  ,A_DEFFLOAT ,0);
}
