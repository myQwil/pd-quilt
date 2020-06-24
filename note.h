#include "m_pd.h"
#include <math.h>

typedef struct _note {
	t_float ref;   /* reference pitch */
	t_float tet;   /* number of tones */
	double rt;     /* root tone */
	double st;     /* semi-tone */
} t_note;

#define note x->x_note

static t_float ntof(t_float f, double root, double semi) {
	return (root * exp(semi*f));
}

static t_float fton(t_float f, double root, double semi) {
	return (semi * log(root*f));
}

static double root(t_note *x) {
	return (x->ref * pow(2, -69 / x->tet));
}

static double semi(t_note *x) {
	return (log(2) / x->tet);
}

static void note_ref(t_note *x, t_float f, int fton) {
	x->ref = f;
	x->rt = (fton) ? 1./root(x) : root(x);
}

static void note_tet(t_note *x, t_float f, int fton) {
	x->tet = f;
	if (fton)
	{	x->rt = 1./root(x);
		x->st = 1./semi(x);   }
	else
	{	x->rt = root(x);
		x->st = semi(x);   }
}

static void note_set(t_note *x, int ac, t_atom *av, int fton) {
	if (ac>2) ac = 2;
	switch (ac)
	{	case 2:
			if ((av+1)->a_type == A_FLOAT)
			{	x->tet = (av+1)->a_w.w_float;
				x->st = (fton) ? 1./semi(x) : semi(x);   }
		case 1:
			if (av->a_type == A_FLOAT)
				x->ref = av->a_w.w_float;   }

	if ((ac==2 && (av+1)->a_type == A_FLOAT) || av->a_type == A_FLOAT)
		x->rt = (fton) ? 1./root(x) : root(x);
}
