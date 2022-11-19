#include "m_pd.h"
#include <math.h>

#if PD_FLOATSIZE == 32
# define FMOD fmodf
#else
# define FMOD fmod
#endif

#define EPSILON 1e-6

/* ------------------- hsv (hue-saturation-value) ------------------- */
static t_class *hsv_class;

typedef struct {
	t_object obj;
	t_float h, s, v;
} t_hsv;

static void hsv_bang(t_hsv *x) {
	t_float r, g, b;
	t_float h=x->h, s=x->s, v=x->v;
	if (s <= 0) {
		r=v, g=v, b=v; // Achromatic case
	} else {
		float f, p, q, t;
		int i;

		if (h < 0 || 360 - EPSILON < h) {
			h = FMOD(h, 360);
			if (h < 0) h += 360;
		}
		h /= 60;
		i = (int)floor(h);
		f = h - i;
		p = v * (1 - s);
		q = v * (1 - (s * f));
		t = v * (1 - (s * (1 - f)));

		switch (i) {
			case 0:  r = v; g = t; b = p; break;
			case 1:  r = q; g = v; b = p; break;
			case 2:  r = p; g = v; b = t; break;
			case 3:  r = p; g = q; b = v; break;
			case 4:  r = t; g = p; b = v; break;
			case 5:  r = v; g = p; b = q; break;
			default: r = v; g = v; b = v;
		}
	}
	int R=r*0xFF, G=g*0xFF, B=b*0xFF;
	outlet_float(x->obj.ob_outlet, (R << 16) + (G << 8) + B);
}

static void hsv_float(t_hsv *x, t_float f) {
	x->h = f;
	hsv_bang(x);
}

static void *hsv_new(t_float h, t_float s, t_float v) {
	t_hsv *x = (t_hsv *)pd_new(hsv_class);
	x->h = h, x->s = s, x->v = v;
	floatinlet_new(&x->obj, &x->s);
	floatinlet_new(&x->obj, &x->v);
	outlet_new(&x->obj, &s_float);
	return x;
}

void hsv_setup(void) {
	hsv_class = class_new(gensym("hsv")
	, (t_newmethod)hsv_new, 0
	, sizeof(t_hsv), 0
	, A_DEFFLOAT, A_DEFFLOAT, A_DEFFLOAT, 0);
	class_addbang(hsv_class, hsv_bang);
	class_addfloat(hsv_class, hsv_float);
}
