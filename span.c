#include "m_pd.h"

/* -------------------------- span -------------------------- */
static t_class *span_class;

typedef struct _span {
	t_object x_obj;
	t_float min;
	t_float max;
	t_float scale;
	t_float factor;
} t_span;

static void span_float(t_span *x ,t_float f) {
	outlet_float(x->x_obj.ob_outlet ,f * x->factor + x->min);
}

static void span_calibrate(t_span *x) {
	x->factor = (x->max - x->min) / x->scale;
}

static void span_min(t_span *x ,t_float f) {
	x->min = f;
	span_calibrate(x);
}

static void span_max(t_span *x ,t_float f) {
	x->max = f;
	span_calibrate(x);
}

static void span_scale(t_span *x ,t_float f) {
	x->scale = f;
	span_calibrate(x);
}

// (x->max - x->min) / x->scale
static void *span_new(t_symbol *s ,int argc ,t_atom *argv) {
	t_span *x = (t_span *)pd_new(span_class);
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
	span_calibrate(x);
	return (x);
}

void span_setup(void) {
	span_class = class_new(gensym("span")
		,(t_newmethod)span_new ,0
		,sizeof(t_span) ,0
		,A_GIMME ,0);
	class_addfloat(span_class ,span_float);
	class_addmethod(span_class ,(t_method)span_min
		,gensym("min")   ,A_FLOAT ,0);
	class_addmethod(span_class ,(t_method)span_min
		,gensym("max")   ,A_FLOAT ,0);
	class_addmethod(span_class ,(t_method)span_min
		,gensym("scale") ,A_FLOAT ,0);
}
