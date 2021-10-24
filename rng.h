#include "m_pd.h"
#include <time.h>

#define UINT_LIMIT 0x100000000

static unsigned seed;

typedef struct {
	t_object obj;
	unsigned state;
} t_rng;

static unsigned rng_time(void) {
	unsigned thym = (time(0) * 2) % UINT_LIMIT;
	return (thym|1); // odd numbers only
}

static void rng_makeseed(t_rng *x) {
	seed = seed * rng_time() + 938284287;
	x->state = seed;
}

static void rng_seed(t_rng *x ,t_symbol *s ,int ac ,t_atom *av) {
	x->state = ac ? (unsigned)atom_getfloat(av) : rng_time();
}

static void rng_state(t_rng *x ,t_symbol *s) {
	post("%s%s%u" ,s->s_name ,*s->s_name?": ":"" ,x->state);
}

static inline double rng_next(t_rng *x) {
	x->state = x->state * 472940017 + 832416023;
	return (double)x->state / UINT_LIMIT;
}
