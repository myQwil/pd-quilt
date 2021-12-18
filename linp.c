#include "m_pd.h"

/* -------------------------- linp ------------------------------ */
#define DEFAULTGRAIN 20
static t_class *linp_class;

typedef struct {
	t_object obj;
	t_clock  *clock;
	t_float  grain;
	t_float  setval;
	t_float  targetval;
	double   targettime;
	double   prevtime;
	double   invtime;
	double   in1val;
	unsigned gotinlet :1;
	unsigned pause    :1;
	t_outlet *o_on;
} t_linp;

static void linp_ft1(t_linp *x ,t_float g) {
	x->in1val = g;
	x->gotinlet = 1;
}

static void linp_set(t_linp *x ,t_float f) {
	clock_unset(x->clock);
	x->targetval = x->setval = f;
}

static void linp_freeze(t_linp *x) {
	if (clock_getsystime() >= x->targettime)
	     x->setval  = x->targetval;
	else x->setval += x->invtime * (clock_getsystime() - x->prevtime)
	                              * (x->targetval - x->setval);
	clock_unset(x->clock);
}

static void linp_stop(t_linp *x) {
	if (pd_compatibilitylevel >= 48)
		linp_freeze(x);
	x->targetval = x->setval;
	outlet_float(x->o_on ,0);
}

static void linp_pause(t_linp *x) {
	if (x->setval == x->targetval)
		return;
	outlet_float(x->o_on ,x->pause);
	x->pause = !x->pause;
	if (x->pause)
	{	linp_freeze(x);
		x->targettime = -clock_gettimesince(x->targettime);  }
	else
	{	double msectogo = x->targettime;
		double timenow = clock_getsystime();
		x->targettime = clock_getsystimeafter(msectogo);
		x->invtime = 1. / (x->targettime - timenow);
		x->prevtime = timenow;
		if (x->grain <= 0)
			x->grain = DEFAULTGRAIN;
		clock_delay(x->clock ,(x->grain > msectogo ? msectogo : x->grain));  }
}

static void linp_tick(t_linp *x) {
	double timenow  =  clock_getsystime();
	double msectogo = -clock_gettimesince(x->targettime);
	if (msectogo < 1E-9)
	{	outlet_float(x->o_on ,0);
		outlet_float(x->obj.ob_outlet ,x->targetval);  }
	else
	{	outlet_float(x->obj.ob_outlet
			,x->setval + x->invtime * (timenow - x->prevtime)
			                         * (x->targetval - x->setval));
		if (x->grain <= 0)
			x->grain = DEFAULTGRAIN;
		clock_delay(x->clock ,(x->grain > msectogo ? msectogo : x->grain));  }
}

static void linp_float(t_linp *x ,t_float f) {
	double timenow = clock_getsystime();
	if (x->gotinlet && x->in1val > 0)
	{	if (timenow > x->targettime)
		     x->setval = x->targetval;
		else x->setval = x->setval + x->invtime * (timenow - x->prevtime)
		                                         * (x->targetval - x->setval);
		x->prevtime = timenow;
		x->targettime = clock_getsystimeafter(x->in1val);
		x->targetval = f;
		linp_tick(x);
		x->gotinlet = x->pause = 0;
		x->invtime = 1. / (x->targettime - timenow);
		if (x->grain <= 0)
			x->grain = DEFAULTGRAIN;
		outlet_float(x->o_on ,1);
		clock_delay(x->clock ,(x->grain > x->in1val ? x->in1val : x->grain));  }
	else
	{	clock_unset(x->clock);
		x->targetval = x->setval = f;
		outlet_float(x->obj.ob_outlet ,f);  }
	x->gotinlet = 0;
}

static void *linp_new(t_float f ,t_float grain) {
	t_linp *x = (t_linp *)pd_new(linp_class);
	x->targetval = x->setval = f;
	x->gotinlet  = x->pause  = 0;
	x->invtime   = 1;
	x->grain = grain;
	x->clock = clock_new(x ,(t_method)linp_tick);
	x->targettime = x->prevtime = clock_getsystime();
	outlet_new(&x->obj ,&s_float);
	x->o_on = outlet_new(&x->obj ,&s_float);
	inlet_new(&x->obj ,&x->obj.ob_pd ,&s_float ,gensym("ft1"));
	floatinlet_new(&x->obj ,&x->grain);
	return (x);
}

static void linp_free(t_linp *x) {
	clock_free(x->clock);
}

void linp_setup(void) {
	linp_class = class_new(gensym("linp")
		,(t_newmethod)linp_new ,(t_method)linp_free
		,sizeof(t_linp) ,0
		,A_DEFFLOAT ,A_DEFFLOAT ,0);
	class_addfloat(linp_class ,(t_method)linp_float);
	class_addmethod(linp_class ,(t_method)linp_ft1   ,gensym("ft1")   ,A_FLOAT ,0);
	class_addmethod(linp_class ,(t_method)linp_set   ,gensym("set")   ,A_FLOAT ,0);
	class_addmethod(linp_class ,(t_method)linp_stop  ,gensym("stop")  ,0);
	class_addmethod(linp_class ,(t_method)linp_pause ,gensym("pause") ,0);
}
