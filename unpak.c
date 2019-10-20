#include "m_pd.h"
#include <string.h>

/* -------------------------- unpak ------------------------------ */

static t_class *unpak_class;

typedef struct unpakout {
	t_atomtype u_type;
	t_outlet *u_outlet;
} t_unpakout;

typedef struct _unpak {
	t_object x_obj;
	t_int x_n, x_mute;
	t_unpakout *x_vec;
} t_unpak;

static void *unpak_new(t_symbol *s, int argc, t_atom *argv) {
	t_unpak *x = (t_unpak *)pd_new(unpak_class);
	t_atom defarg[2], *ap;
	t_unpakout *u;
	int i;

	if (!argc)
	{	argv = defarg;
		argc = 2;
		SETFLOAT(&defarg[0], 0);
		SETFLOAT(&defarg[1], 0);   }

	x->x_n = argc;
	x->x_vec = (t_unpakout *)getbytes(argc * sizeof(*x->x_vec));
	for (i = 0, ap = argv, u = x->x_vec; i < argc; u++, ap++, i++)
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
	return (x);
}

static void unpak_list(t_unpak *x, t_symbol *s, int argc, t_atom *argv) {
	t_atom *ap;
	t_unpakout *u;
	int i;
	if (argc > x->x_n) argc = (int)x->x_n;
	for (i = argc, u = x->x_vec + i, ap = argv + i; u--, ap--, i--;)
	{	if (ap->a_type==A_SYMBOL && !strcmp(ap->a_w.w_symbol->s_name, "."))
			continue;

		t_atomtype type = u->u_type;
		if (type == A_GIMME) type = ap->a_type;
		else if (type != ap->a_type)
		{	if ((x->x_mute>>i)&1) pd_error(x, "unpak: type mismatch");
			continue;   }

		if (type == A_FLOAT)
			outlet_float(u->u_outlet, ap->a_w.w_float);
		else if (type == A_SYMBOL)
		{	if (!strcmp(ap->a_w.w_symbol->s_name, "bang"))
				outlet_bang(u->u_outlet);
			else outlet_symbol(u->u_outlet, ap->a_w.w_symbol);   }
		else if (type == A_POINTER)
			outlet_pointer(u->u_outlet, ap->a_w.w_gpointer);   }
}

static void unpak_anything(t_unpak *x, t_symbol *s, int ac, t_atom *av) {
	t_atom *av2 = (t_atom *)getbytes((ac + 1) * sizeof(t_atom));
	int i;
	for (i = 0; i < ac; i++)
		av2[i + 1] = av[i];
	SETSYMBOL(av2, s);
	unpak_list(x, 0, ac+1, av2);
	freebytes(av2, (ac + 1) * sizeof(t_atom));
}

static void unpak_mute(t_unpak *x, t_floatarg f) {
	x->x_mute = ~(int)f;
}

static void unpak_free(t_unpak *x) {
	freebytes(x->x_vec, x->x_n * sizeof(*x->x_vec));
}

void unpak_setup(void) {
	unpak_class = class_new(gensym("unpak"),
		(t_newmethod)unpak_new, (t_method)unpak_free,
		sizeof(t_unpak), 0,
		A_GIMME, 0);
	class_addlist(unpak_class, unpak_list);
	class_addanything(unpak_class, unpak_anything);
	class_addmethod(unpak_class, (t_method)unpak_mute,
		gensym("mute"), A_FLOAT, 0);
	class_sethelpsymbol(unpak_class, gensym("pak"));
}
