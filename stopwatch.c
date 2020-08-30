#include "m_pd.h"

#define TIMEUNITPERMSEC (32. * 441.)
#define TIMEUNITPERSECOND (TIMEUNITPERMSEC * 1000.)

double clock_gettimelapsewithunits
(double elapsedtime, double units, int sampflag) {
	if (sampflag)
		return (elapsedtime / ((TIMEUNITPERSECOND / sys_getsr()) * units));
	else return (elapsedtime / (TIMEUNITPERMSEC * units));
}

EXTERN void parsetimeunits(void *x, t_float amount, t_symbol *unitname,
	t_float *unit, int *samps);

/* -------------------------- stopwatch ------------------------------ */
static t_class *stopwatch_class;

typedef struct _stopwatch {
	t_object x_obj;
	t_symbol *unitname;
	t_float  unit, oldunit;
	int      samps, oldsamps;
	double   setmore, lapmore; /* time accounted for during tempo changes */
	double   settime, laptime; /* starting time, minus tempo changes */
	unsigned pause:1;  /* pause toggle */
	unsigned tempo:1;  /* flag indicating a tempo change */
	t_outlet *o_lap;
} t_stopwatch;

static void stopwatch_set(t_stopwatch *x) {
	x->settime = x->laptime = clock_getlogicaltime();
	x->oldsamps = x->samps;
	x->oldunit = x->unit;
}

static void stopwatch_bang(t_stopwatch *x) {
	x->setmore = x->lapmore = 0;
	x->pause = x->tempo = 0;
	stopwatch_set(x);
}

static void stopwatch_bang2(t_stopwatch *x) {
	if (x->pause)
		outlet_float(x->x_obj.ob_outlet, clock_gettimelapsewithunits(x->settime,
			x->oldunit, x->oldsamps) + x->setmore);
	else
		outlet_float(x->x_obj.ob_outlet, clock_gettimesincewithunits(x->settime,
			x->unit, x->samps) + x->setmore);
}

static void stopwatch_lap(t_stopwatch *x) {
	double settime = x->settime;
	double laptime = x->laptime;
	if (x->pause)
	{	settime = clock_getlogicaltime() - settime;
		laptime = clock_getlogicaltime() - laptime;   }
	t_atom lap[] =
	{	{ A_FLOAT, {clock_gettimesincewithunits(laptime, x->oldunit, x->oldsamps)
			+ x->lapmore} },
		{ A_FLOAT, {clock_gettimesincewithunits(settime, x->oldunit, x->oldsamps)
			+ x->setmore} }   };
	outlet_list(x->o_lap, 0, 2, lap);
	x->laptime = x->pause ? 0 : clock_getlogicaltime();
	x->lapmore = 0;
}

static void stopwatch_elapse(t_stopwatch *x) {
	x->setmore += clock_gettimesincewithunits(x->settime, x->oldunit, x->oldsamps);
	x->lapmore += clock_gettimesincewithunits(x->laptime, x->oldunit, x->oldsamps);
	stopwatch_set(x);
}

static void stopwatch_pause(t_stopwatch *x) {
	x->pause = !x->pause;
	x->settime = clock_getlogicaltime() - x->settime;
	x->laptime = clock_getlogicaltime() - x->laptime;
	if (!x->pause && x->tempo)
	{	stopwatch_elapse(x);
		x->tempo = 0;   }
}

static void stopwatch_parse(t_stopwatch *x, int ac, t_atom *av) {
	if (ac > 2) ac = 2;
	for (;ac--;)
	{	if (av[ac].a_type == A_SYMBOL)
			x->unitname = av[ac].a_w.w_symbol;
		else if (av[ac].a_type == A_FLOAT)
			x->unit = av[ac].a_w.w_float;   }
	parsetimeunits(x, x->unit, x->unitname, &x->unit, &x->samps);
}

static void stopwatch_tempo(t_stopwatch *x, t_symbol *s, int ac, t_atom *av) {
	stopwatch_parse(x, ac, av);
	if (!x->pause)
		stopwatch_elapse(x);
	else x->tempo = 1;
}

static void *stopwatch_new(t_symbol *s, int argc, t_atom *argv) {
	t_stopwatch *x = (t_stopwatch *)pd_new(stopwatch_class);
	inlet_new(&x->x_obj, &x->x_obj.ob_pd, &s_bang, gensym("bang2"));
	outlet_new(&x->x_obj, gensym("float"));
	x->o_lap = outlet_new(&x->x_obj, 0);

	x->unit = 1;
	x->unitname = gensym("msec");
	stopwatch_parse(x, argc, argv);
	stopwatch_bang(x);
	return (x);
}

void stopwatch_setup(void) {
	stopwatch_class = class_new(gensym("stopwatch"),
		(t_newmethod)stopwatch_new, 0,
		sizeof(t_stopwatch), 0,
		A_GIMME, 0);
	class_addbang(stopwatch_class, stopwatch_bang);
	class_addmethod(stopwatch_class, (t_method)stopwatch_bang2,
		gensym("bang2"), 0);
	class_addmethod(stopwatch_class, (t_method)stopwatch_pause,
		gensym("pause"), 0);
	class_addmethod(stopwatch_class, (t_method)stopwatch_lap,
		gensym("lap"), 0);
	class_addmethod(stopwatch_class, (t_method)stopwatch_tempo,
		gensym("tempo"), A_GIMME, 0);
}
