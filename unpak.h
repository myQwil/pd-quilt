#include "m_pd.h"
#include <string.h>

typedef struct unpakout {
	t_atomtype u_type;
	t_outlet *u_outlet;
} t_unpakout;

typedef struct _unpak {
	t_object x_obj;
	t_unpakout *x_vec;
	t_int x_mute;
	int x_n;
} t_unpak;

static t_unpak *unpak_init(t_class *cl, int ac, t_atom *av, int r) {
	t_unpak *x = (t_unpak *)pd_new(cl);
	t_atom defarg[2], *ap;
	t_unpakout *u;
	int i;

	if (!ac)
	{	av = defarg;
		ac = 2;
		SETFLOAT(&defarg[0], 0);
		SETFLOAT(&defarg[1], 0);   }

	x->x_n = ac;
	x->x_vec = (t_unpakout *)getbytes(ac * sizeof(t_unpakout));

	ap = av + (r ? ac-1 : 0);
	r = r ? -1 : 1;
	for (i=0, u=x->x_vec; i < ac; i++, u++, ap+=r)
	{	t_atomtype type = ap->a_type;
		if (type == A_SYMBOL)
		{	char c = *ap->a_w.w_symbol->s_name;
			if (c == 'f')
			{	u->u_type = A_FLOAT;
				u->u_outlet = outlet_new(&x->x_obj, &s_float);   }
			else if (c == 's')
			{	u->u_type = A_SYMBOL;
				u->u_outlet = outlet_new(&x->x_obj, &s_symbol);   }
			else if (c == 'p')
			{	u->u_type =  A_POINTER;
				u->u_outlet = outlet_new(&x->x_obj, &s_pointer);   }
			else
			{	if (c != 'a') pd_error(x, "unpak: %s: bad type",
					ap->a_w.w_symbol->s_name);
				u->u_type =  A_GIMME;
				u->u_outlet = outlet_new(&x->x_obj, 0);   }   }
		else
		{	u->u_type =  A_GIMME;
			u->u_outlet = outlet_new(&x->x_obj, 0);   }   }
	return x;
}

static void unpak_list(t_unpak *x, t_symbol *s, int argc, t_atom *argv);

static void unpak_anything(t_unpak *x, t_symbol *s, int ac, t_atom *av) {
	t_atom atoms[ac+1];
	atoms[0] = (t_atom){A_SYMBOL, {.w_symbol = s}};
	memcpy(atoms+1, av, ac * sizeof(t_atom));
	unpak_list(x, 0, ac+1, atoms);
}

static void unpak_mute(t_unpak *x, t_floatarg f) {
	x->x_mute = ~(int)f;
}

static void unpak_free(t_unpak *x) {
	freebytes(x->x_vec, x->x_n * sizeof(*x->x_vec));
}
