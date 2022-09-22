#include "m_pd.h"

#define UNITBIT32 1572864.  /* 3*2^19; bit 32 has place value 1 */


#if defined(__FreeBSD__) || defined(__APPLE__) || defined(__FreeBSD_kernel__) \
	|| defined(__OpenBSD__)
#include <machine/endian.h>
#endif

#if defined(__linux__) || defined(__CYGWIN__) || defined(__GNU__) || \
	defined(ANDROID)
#include <endian.h>
#endif

#ifdef __MINGW32__
#include <sys/param.h>
#endif

#ifdef _MSC_VER
/* _MSVC lacks BYTE_ORDER and LITTLE_ENDIAN */
#define LITTLE_ENDIAN 0x0001
#define BYTE_ORDER LITTLE_ENDIAN
#endif

#if !defined(BYTE_ORDER) || !defined(LITTLE_ENDIAN)
#include <endian.h>
#endif

#if BYTE_ORDER == LITTLE_ENDIAN
# define HIOFFSET 1
# define LOWOFFSET 0
#else
# define HIOFFSET 0    /* word offset to find MSB */
# define LOWOFFSET 1    /* word offset to find LSB */
#endif

union tabfudge {
	double d;
	int32_t i[2];
};

/* -------------------------- metro~ ------------------------------ */
static t_class *metro_tilde_class;

typedef struct {
	t_object obj;
	t_sample prev;
	double phase;
	t_float conv;
	t_float f; // scalar frequency
} t_metro_tilde;

static t_int *metro_tilde_perform(t_int *w) {
	t_metro_tilde *x = (t_metro_tilde *)(w[1]);
	t_sample *in = (t_float *)(w[2]);
	int n = (int)(w[3]);
	double dphase = x->phase + (double)UNITBIT32;
	union tabfudge tf;
	int normhipart;
	t_float conv = x->conv;

	tf.d = UNITBIT32;
	normhipart = tf.i[HIOFFSET];
	tf.d = dphase;

	for (; n--; in++) {
		tf.i[HIOFFSET] = normhipart;
		dphase += *in * conv;
		t_sample f = tf.d - UNITBIT32;
		if (*in < 0) {
			if (f < x->prev) {
				outlet_bang(x->obj.ob_outlet);
			}
		} else if (f > x->prev) {
			outlet_bang(x->obj.ob_outlet);
		}
		x->prev = f;
		tf.d = dphase;
	}
	tf.i[HIOFFSET] = normhipart;
	x->phase = tf.d - UNITBIT32;
	return (w + 4);
}

static void metro_tilde_dsp(t_metro_tilde *x, t_signal **sp) {
	x->conv = -1. / sp[0]->s_sr;
	dsp_add(metro_tilde_perform, 3, x, sp[0]->s_vec, (t_int)sp[0]->s_n);
}

static void metro_tilde_ft1(t_metro_tilde *x, t_float f) {
	x->phase = (double)f;
}

static void *metro_tilde_new(t_floatarg f) {
	t_metro_tilde *x = (t_metro_tilde *)pd_new(metro_tilde_class);
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("ft1"));
	outlet_new(&x->obj, &s_bang);
	x->phase = x->conv = x->prev = 0;
	x->f = f;
	return x;
}

void metro_tilde_setup(void) {
	metro_tilde_class = class_new(gensym("metro~")
	, (t_newmethod)metro_tilde_new, 0
	, sizeof(t_metro_tilde), 0
	, A_DEFFLOAT, 0);
	class_domainsignalin(metro_tilde_class, (intptr_t)(&((t_metro_tilde *)0)->f));
	class_addmethod(metro_tilde_class, (t_method)metro_tilde_dsp
	, gensym("dsp"), A_CANT, 0);
	class_addmethod(metro_tilde_class, (t_method)metro_tilde_ft1
	, gensym("ft1"), A_FLOAT, 0);
}
