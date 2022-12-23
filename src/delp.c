#include "thyme.h"

/* -------------------------- delp ------------------------------ */
static t_class *delp_class;

typedef struct {
	t_thyme z;
	t_clock *clock;
	double deltime;     /* delay time */
	double settime;     /* logical clock time */
	double remtime;     /* remaining time */
	unsigned char stop; /* true if stopped */
	t_outlet *o_rem;    /* outputs remaining time */
} t_delp;

static inline void delp_end(t_delp *x) {
	x->stop = 1;
	outlet_float(x->z.o_on, 0);
}

static void delp_tick(t_delp *x) {
	delp_end(x);
	outlet_bang(x->z.obj.ob_outlet);
}

static void delp_stop(t_delp *x) {
	delp_end(x);
	clock_unset(x->clock);
}

static void delp_delay(t_delp *x, t_float f) {
	x->remtime += f;
	if (!x->stop && !x->z.pause) {
		clock_unset(x->clock);
		x->remtime -= thyme_since(&x->z, x->settime);
		x->settime = clock_getlogicaltime();
		clock_delay(x->clock, x->remtime);
	}
}

static void delp_time(t_delp *x) {
	outlet_float(x->o_rem
	, x->remtime - (x->z.pause ? 0 : thyme_since(&x->z, x->settime)));
}

static void delp_pause(t_delp *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (x->stop || pause_state(&x->z.pause, ac, av)) {
		return;
	}
	outlet_float(x->z.o_on, !x->z.pause);

	if (x->z.pause) {
		clock_unset(x->clock);
		x->remtime -= thyme_since(&x->z, x->settime);
		outlet_float(x->o_rem, x->remtime);
	} else {
		x->settime = clock_getlogicaltime();
		clock_delay(x->clock, x->remtime);
	}
}

static void delp_tempo(t_delp *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!x->stop && !x->z.pause) {
		x->remtime -= thyme_since(&x->z, x->settime);
		x->settime = clock_getlogicaltime();
	}
	thyme_parse(&x->z, ac, av);
	clock_setunit(x->clock, x->z.unit, x->z.samps);
}

static void delp_ft1(t_delp *x, t_float f) {
	if (f < 0) {
		f = 0;
	}
	x->deltime = f;
}

static void delp_bang(t_delp *x) {
	clock_delay(x->clock, x->deltime);
	x->settime = clock_getlogicaltime();
	x->remtime = x->deltime;
	x->z.pause = x->stop = 0;
	outlet_float(x->z.o_on, 1);
}

static void delp_float(t_delp *x, t_float f) {
	delp_ft1(x, f);
	delp_bang(x);
}

static void *delp_new(t_symbol *s, int argc, t_atom *argv) {
	(void)s;
	t_delp *y = (t_delp *)pd_new(delp_class);
	t_thyme *x = &y->z;
	inlet_new(&x->obj, &x->obj.ob_pd, &s_float, gensym("ft1"));
	outlet_new(&x->obj, &s_bang);
	y->o_rem = outlet_new(&x->obj, &s_float);

	y->clock = clock_new(y, (t_method)delp_tick);
	y->settime = clock_getlogicaltime();
	if (argc && argv->a_type == A_FLOAT) {
		delp_ft1(y, argv->a_w.w_float);
		argc--, argv++;
	}
	y->stop = 1;
	thyme_init(x);
	delp_tempo(y, 0, argc, argv);
	return y;
}

static void delp_free(t_delp *x) {
	clock_free(x->clock);
}

void delp_setup(void) {
	delp_class = class_new(gensym("delp")
	, (t_newmethod)delp_new, (t_method)delp_free
	, sizeof(t_delp), 0
	, A_GIMME, 0);
	class_addbang(delp_class, delp_bang);
	class_addfloat(delp_class, delp_float);
	class_addmethod(delp_class, (t_method)delp_ft1, gensym("ft1"), A_FLOAT, 0);
	class_addmethod(delp_class, (t_method)delp_delay, gensym("del"), A_FLOAT, 0);
	class_addmethod(delp_class, (t_method)delp_delay, gensym("delay"), A_FLOAT, 0);
	class_addmethod(delp_class, (t_method)delp_pause, gensym("pause"), A_GIMME, 0);
	class_addmethod(delp_class, (t_method)delp_tempo, gensym("tempo"), A_GIMME, 0);
	class_addmethod(delp_class, (t_method)delp_stop, gensym("stop"), 0);
	class_addmethod(delp_class, (t_method)delp_time, gensym("time"), 0);
}
