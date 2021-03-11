#include "m_pd.h"

/* -------------------------- linp~ ------------------------------ */
static t_class *linp_tilde_class;

typedef struct {
	t_object obj;
	t_sample target; /* target value of ramp */
	t_sample value;  /* current value of ramp at block-borders */
	t_sample biginc;
	t_sample inc;
	t_float coefn;
	t_float dspticktomsec;
	t_float inletvalue;
	t_float inletwas;
	int ticksleft;
	unsigned retarget :1;
	unsigned pause    :1;
	t_outlet *o_on;
} t_linp;

static t_int *linp_tilde_perform(t_int *w) {
	t_linp *x = (t_linp *)(w[1]);
	t_sample *out = (t_sample *)(w[2]);
	int n = (int)(w[3]);
	t_sample f = x->value ,g;

	if (PD_BIGORSMALL(f))
		x->value = f = 0;
	if (x->retarget)
	{	int nticks = x->inletwas * x->dspticktomsec;
		if (!nticks) nticks = 1;
		x->ticksleft = nticks;
		x->biginc = (x->target - x->value)/(t_float)nticks;
		x->inc = x->coefn * x->biginc;
		x->retarget = 0;   }
	if (x->ticksleft && !x->pause)
	{	g = x->value;
		while (n--)
			*out++ = g ,g += x->inc;
		x->value += x->biginc;
		x->ticksleft--;   }
	else
	{	if (!x->pause)
		{	x->value = x->target;
			outlet_float(x->o_on ,0);   }
		g = x->value;
		while (n--)
			*out++ = g;   }
	return (w+4);
}

/* TB: vectorized version */
static t_int *linp_tilde_perf8(t_int *w) {
	t_linp *x = (t_linp *)(w[1]);
	t_sample *out = (t_sample *)(w[2]);
	int n = (int)(w[3]);
	t_sample f = x->value ,g;

	if (PD_BIGORSMALL(f))
		x->value = f = 0;
	if (x->retarget)
	{	int nticks = x->inletwas * x->dspticktomsec;
		if (!nticks) nticks = 1;
		x->ticksleft = nticks;
		x->biginc = (x->target - x->value)/(t_sample)nticks;
		x->inc = x->coefn * x->biginc;
		x->retarget = 0;   }
	if (x->ticksleft && !x->pause)
	{	g = x->value;
		while (n--)
			*out++ = g ,g += x->inc;
		x->value += x->biginc;
		x->ticksleft--;   }
	else
	{	if (!x->pause)
		{	x->value = x->target;
			outlet_float(x->o_on ,0);   }
		g = x->value;
		for (; n; n -= 8 ,out += 8)
		{	out[0] = out[1] = out[2] = out[3] =
			out[4] = out[5] = out[6] = out[7] = g;   }   }
	return (w+4);
}

static void linp_tilde_stop(t_linp *x) {
	x->target = x->value;
	x->ticksleft = x->retarget = 0;
}

static void linp_tilde_pause(t_linp *x) {
	if (x->target == x->value)
		return;
	outlet_float(x->o_on ,x->pause);
	x->pause = !x->pause;
}

static void linp_tilde_float(t_linp *x ,t_float f) {
	if (x->inletvalue <= 0)
	{	x->target = x->value = f;
		x->ticksleft = x->retarget = 0;   }
	else
	{	x->target = f;
		x->retarget = 1;
		x->inletwas = x->inletvalue;
		x->inletvalue = x->pause = 0;
		outlet_float(x->o_on ,1);   }
}

static void linp_tilde_dsp(t_linp *x ,t_signal **sp) {
	if(sp[0]->s_n&7)
	     dsp_add(linp_tilde_perform ,3 ,x ,sp[0]->s_vec ,(t_int)sp[0]->s_n);
	else dsp_add(linp_tilde_perf8   ,3 ,x ,sp[0]->s_vec ,(t_int)sp[0]->s_n);
	x->coefn = 1./sp[0]->s_n;
	x->dspticktomsec = sp[0]->s_sr / (1000 * sp[0]->s_n);
}

static void *linp_tilde_new(void) {
	t_linp *x = (t_linp *)pd_new(linp_tilde_class);
	floatinlet_new(&x->obj ,&x->inletvalue);
	outlet_new(&x->obj ,&s_signal);
	x->o_on = outlet_new(&x->obj ,&s_float);
	x->ticksleft = x->retarget = x->pause = 0;
	x->value = x->target = x->inletvalue = x->inletwas = 0;
	return (x);
}

void linp_tilde_setup(void) {
	linp_tilde_class = class_new(gensym("linp~")
		,linp_tilde_new ,0
		,sizeof(t_linp) ,0
		,0);
	class_addfloat(linp_tilde_class ,(t_method)linp_tilde_float);
	class_addmethod(linp_tilde_class ,(t_method)linp_tilde_dsp
		,gensym("dsp")   ,A_CANT ,0);
	class_addmethod(linp_tilde_class ,(t_method)linp_tilde_stop
		,gensym("stop")  ,0);
	class_addmethod(linp_tilde_class ,(t_method)linp_tilde_pause
		,gensym("pause") ,0);
}
