#include "m_pd.h"
#include <math.h>

#ifndef SEMI
#define SEMI(x) log(2) / (x)->tet
#endif

#ifndef BASE
#define BASE(x) (x)->ref * pow(2 ,-69 / (x)->tet)
#endif

typedef struct {
	t_float ref;   /* reference pitch */
	t_float tet;   /* number of tones */
	double bt;     /* lowest note frequency */
	double st;     /* semi-tone */
} t_note;

static inline t_float ntof(t_note *x ,t_float f) {
	return (x->bt * exp(x->st*f));
}

static inline t_float fton(t_note *x ,t_float f) {
	return (x->st * log(x->bt*f));
}

static inline void note_ref(t_note *x ,t_float f) {
	x->ref = f;
	x->bt = BASE(x);
}

static inline void note_tet(t_note *x ,t_float f) {
	x->tet = f;
	x->st = SEMI(x);
	x->bt = BASE(x);
}

static void note_set(t_note *x ,int ac ,t_atom *av) {
	if (ac > 2)
		ac = 2;
	switch (ac)
	{	case 2:
			if (av[1].a_type == A_FLOAT)
			{	x->tet = av[1].a_w.w_float;
				x->st = SEMI(x);   }
		case 1:
			if (av->a_type == A_FLOAT)
				x->ref = av->a_w.w_float;   }
	x->bt = BASE(x);
}
