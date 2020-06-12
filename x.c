#include "m_pd.h"

/* -------------------------- explicit trigger ------------------------------ */
static t_class *xtrigger_class;

#define TR_BANG 0
#define TR_FLOAT 1
#define TR_SYMBOL 2
#define TR_POINTER 3
#define TR_LIST 4
#define TR_ANYTHING 5

typedef struct xtriggerout {
	int u_type;		 /* outlet type from above */
	t_outlet *u_outlet;
} t_xtriggerout;

typedef struct _xtrigger {
	t_object x_obj;
	t_int x_n;
	t_xtriggerout *x_vec;
} t_xtrigger;

static void *xtrigger_new(t_symbol *s, int argc, t_atom *argv) {
	t_xtrigger *x = (t_xtrigger *)pd_new(xtrigger_class);
	t_atom defarg[2], *ap;
	t_xtriggerout *u;
	int i;
	if (!argc)
	{	argv = defarg;
		argc = 2;
		SETFLOAT(&defarg[0], 0);
		SETFLOAT(&defarg[1], 0);   }
	x->x_n = argc;
	x->x_vec = (t_xtriggerout *)getbytes(argc * sizeof(*x->x_vec));
	for (i = 0, ap = argv, u = x->x_vec; i < argc; u++, ap++, i++)
	{	t_atomtype thistype = ap->a_type;
		char c;
		if (thistype == TR_SYMBOL) c = ap->a_w.w_symbol->s_name[0];
		else if (thistype == TR_FLOAT) c = 'a';
		else c = 0;
		if (c == 'p')
			u->u_type = TR_POINTER,
				u->u_outlet = outlet_new(&x->x_obj, &s_pointer);
		else if (c == 'f')
			u->u_type = TR_FLOAT, u->u_outlet = outlet_new(&x->x_obj, &s_float);
		else if (c == 'b')
			u->u_type = TR_BANG, u->u_outlet = outlet_new(&x->x_obj, &s_bang);
		else if (c == 'l')
			u->u_type = TR_LIST, u->u_outlet = outlet_new(&x->x_obj, &s_list);
		else if (c == 's')
			u->u_type = TR_SYMBOL,
				u->u_outlet = outlet_new(&x->x_obj, &s_symbol);
		else if (c == 'a')
			u->u_type = TR_ANYTHING,
				u->u_outlet = outlet_new(&x->x_obj, 0);
		else
		{	pd_error(x, "xtrigger: %s: bad type", ap->a_w.w_symbol->s_name);
			u->u_type = TR_ANYTHING;
			u->u_outlet = outlet_new(&x->x_obj, 0);   }   }
	return (x);
}

static void xtrigger_list(t_xtrigger *x, t_symbol *s, int argc, t_atom *argv) {
	t_xtriggerout *u;
	int i;
	for (i = (int)x->x_n, u = x->x_vec + i; u--, i--;)
	{	int type = u->u_type;
		if (type==TR_ANYTHING && argc==1) type = argv->a_type;

		if (type == TR_FLOAT)
			outlet_float(u->u_outlet, (argc ? atom_getfloat(argv) : 0));
		else if (type == TR_BANG)
			outlet_bang(u->u_outlet);
		else if (type == TR_SYMBOL)
			outlet_symbol(u->u_outlet,
				(argc ? atom_getsymbol(argv) : &s_symbol));
		else if (type == TR_POINTER)
		{	if (!argc || argv->a_type != TR_POINTER)
				pd_error(x, "unpack: bad pointer");
			else outlet_pointer(u->u_outlet, argv->a_w.w_gpointer);   }
		else outlet_list(u->u_outlet, &s_list, argc, argv);   }
}

static void xtrigger_anything(t_xtrigger *x, t_symbol *s, int argc, t_atom *argv) {
	t_xtriggerout *u;
	int i;
	for (i = (int)x->x_n, u = x->x_vec + i; u--, i--;)
	{	if (u->u_type == TR_BANG)
			outlet_bang(u->u_outlet);
		else if (u->u_type == TR_ANYTHING)
			outlet_anything(u->u_outlet, s, argc, argv);
		else pd_error(x, "xtrigger: can only convert 's' to 'b' or 'a'");   }
}

static void xtrigger_bang(t_xtrigger *x) {
	xtrigger_list(x, 0, 0, 0);
}

static void xtrigger_pointer(t_xtrigger *x, t_gpointer *gp) {
	t_atom at;
	SETPOINTER(&at, gp);
	xtrigger_list(x, 0, 1, &at);
}

static void xtrigger_float(t_xtrigger *x, t_float f) {
	t_atom at;
	SETFLOAT(&at, f);
	xtrigger_list(x, 0, 1, &at);
}

static void xtrigger_symbol(t_xtrigger *x, t_symbol *s) {
	t_atom at;
	SETSYMBOL(&at, s);
	xtrigger_list(x, 0, 1, &at);
}

static void xtrigger_free(t_xtrigger *x) {
	freebytes(x->x_vec, x->x_n * sizeof(*x->x_vec));
}

void x_setup(void) {
	xtrigger_class = class_new(gensym("x"),
		(t_newmethod)xtrigger_new, (t_method)xtrigger_free,
		sizeof(t_xtrigger), 0,
		A_GIMME, 0);
	class_addlist(xtrigger_class, xtrigger_list);
	class_addbang(xtrigger_class, xtrigger_bang);
	class_addpointer(xtrigger_class, xtrigger_pointer);
	class_addfloat(xtrigger_class, xtrigger_float);
	class_addsymbol(xtrigger_class, xtrigger_symbol);
	class_addanything(xtrigger_class, xtrigger_anything);
}
