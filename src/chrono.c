#include "thyme.h"

/* -------------------------- chrono ------------------------------ */
static t_class *chrono_class;

typedef struct {
	t_thyme z;
	double   settime, laptime;
	double   setmore, lapmore; /* paused time and tempo changes */
	t_outlet *o_lap;           /* outputs lap & total time */
} t_chrono;

static inline void chrono_reset(t_chrono *x) {
	x->settime = x->laptime = clock_getlogicaltime();
	x->setmore = x->lapmore = x->z.pause = 0;
}

static inline void chrono_delay(t_chrono *x, t_float f) {
	x->setmore -= f;
}

static void chrono_bang(t_chrono *x) {
	chrono_reset(x);
	outlet_float(x->z.o_on, 1);
}

static void chrono_float(t_chrono *x, t_float f) {
	chrono_reset(x);
	chrono_delay(x, f);
	outlet_float(x->z.o_on, 1);
}

static void chrono_bang2(t_chrono *x) {
	outlet_float(x->z.obj.ob_outlet
	, x->setmore + (x->z.pause ? 0 : thyme_since(&x->z, x->settime)));
}

static void chrono_lap(t_chrono *x) {
	double settime, laptime;
	if (x->z.pause) {
		settime = laptime = clock_getlogicaltime();
	} else {
		settime = x->settime;
		laptime = x->laptime;
		x->laptime = clock_getlogicaltime();
	}
	t_atom lap[] = {
	  {.a_type = A_FLOAT, .a_w = {thyme_since(&x->z, laptime) + x->lapmore} }
	, {.a_type = A_FLOAT, .a_w = {thyme_since(&x->z, settime) + x->setmore} }
	};
	x->lapmore = 0;
	outlet_list(x->o_lap, 0, 2, lap);
}

static void chrono_pause(t_chrono *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (pause_state(&x->z.pause, ac, av)) {
		return;
	}
	outlet_float(x->z.o_on, !x->z.pause);

	if (x->z.pause) {
		x->setmore += thyme_since(&x->z, x->settime);
		x->lapmore += thyme_since(&x->z, x->laptime);
	} else {
		x->settime = x->laptime = clock_getlogicaltime();
	}
}

static void chrono_tempo(t_chrono *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!x->z.pause) {
		x->setmore += thyme_since(&x->z, x->settime);
		x->lapmore += thyme_since(&x->z, x->laptime);
		x->settime = x->laptime = clock_getlogicaltime();
	}
	thyme_parse(&x->z, ac, av);
}

static void *chrono_new(t_symbol *s, int argc, t_atom *argv) {
	(void)s;
	t_chrono *y = (t_chrono *)pd_new(chrono_class);
	t_thyme *x = &y->z;
	inlet_new(&x->obj, &x->obj.ob_pd, &s_bang, gensym("bang2"));
	outlet_new(&x->obj, &s_float);
	y->o_lap = outlet_new(&x->obj, 0);

	thyme_init(x);
	chrono_bang(y);
	chrono_tempo(y, 0, argc, argv);
	return y;
}

void chrono_setup(void) {
	chrono_class = class_new(gensym("chrono")
	, (t_newmethod)chrono_new, 0
	, sizeof(t_chrono), 0
	, A_GIMME, 0);
	class_addbang(chrono_class, chrono_bang);
	class_addfloat(chrono_class, chrono_float);
	class_addmethod(chrono_class, (t_method)chrono_lap, gensym("lap"), A_NULL);
	class_addmethod(chrono_class, (t_method)chrono_bang2, gensym("bang2"), A_NULL);
	class_addmethod(chrono_class, (t_method)chrono_delay, gensym("del"), A_FLOAT, 0);
	class_addmethod(chrono_class, (t_method)chrono_delay, gensym("delay"), A_FLOAT, 0);
	class_addmethod(chrono_class, (t_method)chrono_pause, gensym("pause"), A_GIMME, 0);
	class_addmethod(chrono_class, (t_method)chrono_tempo, gensym("tempo"), A_GIMME, 0);
}
