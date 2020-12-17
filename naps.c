#include "m_pd.h"

/* -------------------------- naps -------------------------- */
static t_class *naps_class;

typedef struct _naps {
	t_object x_obj;
	t_float min;
	t_float max;
	t_float scale;
	t_float factor;
} t_naps;

static void naps_float(t_naps *x ,t_float f) {
	outlet_float(x->x_obj.ob_outlet ,(f - x->min) * x->factor);
}

static void naps_calibrate(t_naps *x) {
	x->factor = x->scale / (x->max - x->min);
}

static void naps_min(t_naps *x ,t_float f) {
	x->min = f;
	naps_calibrate(x);
}

static void naps_max(t_naps *x ,t_float f) {
	x->max = f;
	naps_calibrate(x);
}

static void naps_scale(t_naps *x ,t_float f) {
	x->scale = f;
	naps_calibrate(x);
}

static void *naps_new(t_symbol *s ,int argc ,t_atom *argv) {
	t_naps *x = (t_naps *)pd_new(naps_class);
	outlet_new(&x->x_obj ,&s_float);
	inlet_new (&x->x_obj ,&x->x_obj.ob_pd ,&s_float ,gensym("min"));
	inlet_new (&x->x_obj ,&x->x_obj.ob_pd ,&s_float ,gensym("max"));
	inlet_new (&x->x_obj ,&x->x_obj.ob_pd ,&s_float ,gensym("scale"));
	t_float min=0 ,max=1 ,scale=100;
	switch (argc)
	{ case 3:
		scale = atom_getfloat(argv+2); // no break
	  case 2:
		max = atom_getfloat(argv+1);
		min = atom_getfloat(argv);
		break;
	  case 1:
		max = atom_getfloat(argv);   }
	x->min = min ,x->max = max ,x->scale = scale;
	naps_calibrate(x);
	return (x);
}

void naps_setup(void) {
	naps_class = class_new(gensym("naps")
		,(t_newmethod)naps_new ,0
		,sizeof(t_naps) ,0
		,A_GIMME ,0);
	class_addfloat(naps_class ,naps_float);
	class_addmethod(naps_class ,(t_method)naps_min
		,gensym("min")   ,A_FLOAT ,0);
	class_addmethod(naps_class ,(t_method)naps_min
		,gensym("max")   ,A_FLOAT ,0);
	class_addmethod(naps_class ,(t_method)naps_min
		,gensym("scale") ,A_FLOAT ,0);
	class_sethelpsymbol(naps_class, gensym("span"));

}
