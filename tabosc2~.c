#include "m_pd.h"

/******************** tabosc2~ ***********************/

/* this is all copied from d_osc.c... what include file could this go in? */
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
#error No byte order defined
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

static t_class *tabosc2_class;

typedef struct {
	t_object obj;
	t_symbol *arrayname;
	t_word *vec;
	t_float f;
	t_float conv;
	t_float fnpoints;
	t_float finvnpoints;
	t_float edge;
	t_float k;
	double phase;
} t_tabosc2;

static t_int *tabosc2_perform(t_int *w) {
	t_tabosc2 *x = (t_tabosc2 *)(w[1]);
	t_sample *in1 = (t_sample *)(w[2]);
	t_sample *in2 = (t_sample *)(w[3]);
	t_sample *out = (t_sample *)(w[4]);
	int n = (int)(w[5]);
	int normhipart;
	union tabfudge tf;
	t_float fnpoints = x->fnpoints;
	int mask = fnpoints - 1;
	t_float conv = fnpoints * x->conv;
	t_word *tab = x->vec ,*addr;
	double dphase = fnpoints * x->phase + UNITBIT32;

	if (!tab) goto zero;
	tf.d = UNITBIT32;
	normhipart = tf.i[HIOFFSET];

	for (t_sample frac ,edge ,a ,b; n--;)
	{	tf.d = dphase;
		dphase += *in1++ * conv;
		addr = tab + (tf.i[HIOFFSET] & mask);
		tf.i[HIOFFSET] = normhipart;
		frac = tf.d - UNITBIT32;
		edge = *in2++;
		if (frac <= edge)
			*out++ = addr[1].w_float;
		else
		{	if (x->edge != edge)
			{	if (edge < 1)
					x->k = 1. / (1. - edge);
				x->edge = edge;   }
			a = addr[1].w_float;
			b = addr[2].w_float;
			frac = (frac - edge) * x->k;
			*out++ = a * (1. - frac) + b * frac;   }   }

	tf.d = UNITBIT32 * fnpoints;
	normhipart = tf.i[HIOFFSET];
	tf.d = dphase + (UNITBIT32 * fnpoints - UNITBIT32);
	tf.i[HIOFFSET] = normhipart;
	x->phase = (tf.d - UNITBIT32 * fnpoints)  * x->finvnpoints;
	return (w+6);
 zero:
	while (n--) *out++ = 0;

	return (w+6);
}

static void tabosc2_set(t_tabosc2 *x ,t_symbol *s) {
	t_garray *a;
	int npoints ,pointsinarray;

	x->arrayname = s;
	if (!(a = (t_garray *)pd_findbyclass(x->arrayname ,garray_class)))
	{	if (*s->s_name)
			pd_error(x ,"tabosc2~: %s: no such array" ,x->arrayname->s_name);
		x->vec = 0;   }
	else if (!garray_getfloatwords(a ,&pointsinarray ,&x->vec))
	{	pd_error(x ,"%s: bad template for tabosc2~" ,x->arrayname->s_name);
		x->vec = 0;   }
	else if ((npoints = pointsinarray - 3) != (1 << ilog2(pointsinarray - 3)))
	{	pd_error(x ,"%s: number of points (%d) not a power of 2 plus three"
			,x->arrayname->s_name ,pointsinarray);
		x->vec = 0;
		garray_usedindsp(a);   }
	else
	{	x->fnpoints = npoints;
		x->finvnpoints = 1. / npoints;
		garray_usedindsp(a);   }
}

static void tabosc2_dsp(t_tabosc2 *x ,t_signal **sp) {
	x->conv = 1. / sp[0]->s_sr;
	tabosc2_set(x ,x->arrayname);

	dsp_add(tabosc2_perform ,5 ,x
		,sp[0]->s_vec ,sp[1]->s_vec ,sp[2]->s_vec ,(t_int)sp[0]->s_n);
}

static void tabosc2_ft1(t_tabosc2 *x ,t_float f) {
	x->phase = f;
}

static void *tabosc2_new(t_symbol *s ,t_float edge) {
	t_tabosc2 *x = (t_tabosc2 *)pd_new(tabosc2_class);
	x->arrayname = s;
	x->vec = 0;
	x->fnpoints = 512.;
	x->finvnpoints = 1. / x->fnpoints;
	signalinlet_new(&x->obj ,edge);
	inlet_new(&x->obj ,&x->obj.ob_pd ,&s_float ,gensym("ft1"));
	outlet_new(&x->obj ,&s_signal);
	x->f = 0;
	x->k = 1;
	return (x);
}

void tabosc2_tilde_setup(void) {
	tabosc2_class = class_new(gensym("tabosc2~")
		,(t_newmethod)tabosc2_new ,0
		,sizeof(t_tabosc2) ,0
		,A_DEFSYM ,A_DEFFLOAT ,0);
	CLASS_MAINSIGNALIN(tabosc2_class ,t_tabosc2 ,f);
	class_addmethod(tabosc2_class ,(t_method)tabosc2_dsp
		,gensym("dsp") ,A_CANT ,0);
	class_addmethod(tabosc2_class ,(t_method)tabosc2_set
		,gensym("set") ,A_SYMBOL ,0);
	class_addmethod(tabosc2_class ,(t_method)tabosc2_ft1
		,gensym("ft1") ,A_FLOAT ,0);
}
