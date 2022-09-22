#include "pause.h"

EXTERN void parsetimeunits(void *x, t_float amount, t_symbol *unitname
, t_float *unit, int *samps);

typedef struct {
	t_object obj;
	t_symbol *unitname;
	t_float unit;
	int samps;
	unsigned char pause; /* play/pause toggle */
	t_outlet *o_on;      /* outputs play/pause state */
} t_time;

static inline double time_since(t_time *x, double f) {
	return clock_gettimesincewithunits(f, x->unit, x->samps);
}

static inline void time_parse(t_time *x, int ac, t_atom *av) {
	if (ac > 2) {
		ac = 2;
	}
	while (ac--) {
		switch (av[ac].a_type) {
		case A_FLOAT: x->unit = av[ac].a_w.w_float; break;
		case A_SYMBOL: x->unitname = av[ac].a_w.w_symbol; break;
		default: break;
		}
	}
	parsetimeunits(x, x->unit, x->unitname, &x->unit, &x->samps);
}

static inline void time_init(t_time *x) {
	x->unit = 1, x->samps = 0;
	x->unitname = gensym("msec");
	x->o_on = outlet_new(&x->obj, &s_float);
}
