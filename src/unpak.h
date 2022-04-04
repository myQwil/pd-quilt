#include "m_pd.h"
#include <string.h>

typedef struct {
	t_atomtype type;
	t_outlet *outlet;
} t_unpakout;

typedef struct {
	t_object obj;
	t_unpakout *vec;
	t_int mute;
	int n;
} t_unpak;

static t_unpak *new_unpak(t_class *cl ,t_symbol *s ,int ac ,t_atom *av ,int r) {
	(void)s;
	t_unpak *x = (t_unpak*)pd_new(cl);
	t_atom defarg[2] ,*ap;
	t_unpakout *u;
	int i;

	if (!ac)
	{	av = defarg;
		ac = 2;
		SETFLOAT(&defarg[0] ,0);
		SETFLOAT(&defarg[1] ,0);  }

	x->n = ac;
	x->vec = (t_unpakout*)getbytes(x->n * sizeof(t_unpakout));

	ap = av + (r ? ac-1 : 0);
	r = r ? -1 : 1;
	for (i=0 ,u=x->vec; i < ac; i++ ,u++ ,ap+=r)
	{	t_atomtype type = ap->a_type;
		if (type == A_SYMBOL)
		{	char c = *ap->a_w.w_symbol->s_name;
			if (c == 'f')
			{	u->type = A_FLOAT;
				u->outlet = outlet_new(&x->obj ,&s_float);  }
			else if (c == 's')
			{	u->type = A_SYMBOL;
				u->outlet = outlet_new(&x->obj ,&s_symbol);  }
			else if (c == 'p')
			{	u->type = A_POINTER;
				u->outlet = outlet_new(&x->obj ,&s_pointer);  }
			else
			{	if (c != 'a') pd_error(x ,"unpak: %s: bad type"
					,ap->a_w.w_symbol->s_name);
				u->type = A_GIMME;
				u->outlet = outlet_new(&x->obj ,0);  }  }
		else
		{	u->type =  A_GIMME;
			u->outlet = outlet_new(&x->obj ,0);  }  }
	return x;
}

static void unpak_list(t_unpak *x ,t_symbol *s ,int argc ,t_atom *argv);

static void unpak_anything(t_unpak *x ,t_symbol *s ,int ac ,t_atom *av) {
	t_atom atoms[ac+1];
	atoms[0] = (t_atom){.a_type=A_SYMBOL ,.a_w={.w_symbol = s}};
	memcpy(atoms+1 ,av ,ac * sizeof(t_atom));
	unpak_list(x ,0 ,ac+1 ,atoms);
}

static void unpak_mute(t_unpak *x ,t_float f) {
	x->mute = ~(int)f;
}

static void unpak_free(t_unpak *x) {
	freebytes(x->vec ,x->n * sizeof(t_unpakout));
}
