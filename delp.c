#include "m_pd.h"

#define timesince clock_gettimesincewithunits
EXTERN void parsetimeunits(void *x ,t_float amount ,t_symbol *unitname
	,t_float *unit ,int *samps);

/* -------------------------- delp ------------------------------ */
static t_class *delp_class;

typedef struct _delp {
	t_object obj;
	t_clock  *clock;
	t_symbol *unitname;
	t_float  unit;
	int      samps;
	double   deltime; /* delay time */
	double   settime; /* logical clock time */
	double   remtime; /* remaining time */
	unsigned pause:1; /* play/pause toggle */
	unsigned stop :1; /* true if stopped */
	t_outlet *o_rem;  /* outputs remaining time */
	t_outlet *o_on;   /* outputs play/pause state */
} t_delp;

static void delp_tick(t_delp *x) {
	x->stop = 1;
	outlet_float(x->o_on ,0);
	outlet_bang(x->obj.ob_outlet);
}

static void delp_stop(t_delp *x) {
	clock_unset(x->clock);
	x->stop = 1;
	outlet_float(x->o_on ,0);
}

static void delp_ft1(t_delp *x ,t_floatarg f) {
	if (f < 0) f = 0;
	x->deltime = f;
}

static void delp_bang(t_delp *x) {
	clock_delay(x->clock ,x->deltime);
	x->settime = clock_getlogicaltime();
	x->remtime = x->deltime;
	x->pause = x->stop = 0;
	outlet_float(x->o_on ,1);
}

static void delp_float(t_delp *x ,t_float f) {
	delp_ft1(x ,f);
	delp_bang(x);
}

static void delp_pause(t_delp *x) {
	if (x->stop) return;
	outlet_float(x->o_on ,x->pause);
	x->pause = !x->pause;
	if (x->pause)
	{	clock_unset(x->clock);
		x->remtime -= timesince(x->settime ,x->unit ,x->samps);
		outlet_float(x->o_rem ,x->remtime);   }
	else
	{	x->settime = clock_getlogicaltime();
		clock_delay(x->clock ,x->remtime);   }
}

static void delp_tempo(t_delp *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (!x->stop && !x->pause)
	{	x->remtime -= timesince(x->settime ,x->unit ,x->samps);
		x->settime = clock_getlogicaltime();   }
	if (ac > 2) ac = 2;
	while (ac--)
	{	switch (av[ac].a_type)
		{	case A_FLOAT  :x->unit     = av[ac].a_w.w_float  ;break;
			case A_SYMBOL :x->unitname = av[ac].a_w.w_symbol ;break;
			default: break;   }   }
	parsetimeunits(x ,x->unit ,x->unitname ,&x->unit ,&x->samps);
	clock_setunit(x->clock ,x->unit ,x->samps);
}

static void delp_free(t_delp *x) {
	clock_free(x->clock);
}

static void *delp_new(t_symbol *s ,int argc ,t_atom *argv) {
	t_delp *x = (t_delp *)pd_new(delp_class);
	inlet_new(&x->obj ,&x->obj.ob_pd ,gensym("float") ,gensym("ft1"));
	outlet_new(&x->obj ,gensym("bang"));
	x->o_rem = outlet_new(&x->obj ,&s_float);
	x->o_on  = outlet_new(&x->obj ,&s_float);

	x->clock = clock_new(x ,(t_method)delp_tick);
	if (argc && argv->a_type == A_FLOAT)
	{	delp_ft1(x ,argv->a_w.w_float);
		argc-- ,argv++;   }
	x->unit = x->stop = 1 ,x->samps = 0;
	x->unitname = gensym("msec");
	delp_tempo(x ,0 ,argc ,argv);
	return (x);
}

void delp_setup(void) {
	delp_class = class_new(gensym("delp")
		,(t_newmethod)delp_new ,(t_method)delp_free
		,sizeof(t_delp) ,0
		,A_GIMME ,0);
	class_addbang  (delp_class ,delp_bang);
	class_addfloat (delp_class ,delp_float);
	class_addmethod(delp_class ,(t_method)delp_stop
		,gensym("stop")  ,0);
	class_addmethod(delp_class ,(t_method)delp_pause
		,gensym("pause") ,0);
	class_addmethod(delp_class ,(t_method)delp_ft1
		,gensym("ft1")   ,A_FLOAT ,0);
	class_addmethod(delp_class ,(t_method)delp_tempo
		,gensym("tempo") ,A_GIMME ,0);
}
