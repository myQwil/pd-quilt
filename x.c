#include "m_pd.h"

/* -------------------------- explicit trigger ------------------------------ */
static t_class *xtrigger_class;

typedef enum {
	 TR_BANG
	,TR_FLOAT
	,TR_SYMBOL
	,TR_POINTER
	,TR_LIST
	,TR_ANYTHING
} xtype;

typedef struct {
	xtype type;		 /* outlet type from above */
	t_outlet *outlet;
} t_xtriggerout;

typedef struct {
	t_object obj;
	t_int siz;
	t_xtriggerout *vec;
} t_xtrigger;

static void *xtrigger_new(t_symbol *s ,int argc ,t_atom *argv) {
	t_xtrigger *x = (t_xtrigger *)pd_new(xtrigger_class);
	t_atom defarg[2] ,*ap;
	t_xtriggerout *u;
	int i;
	if (!argc)
	{	argv = defarg;
		argc = 2;
		SETFLOAT(&defarg[0] ,0);
		SETFLOAT(&defarg[1] ,0);   }
	x->siz = argc;
	x->vec = (t_xtriggerout *)getbytes(argc * sizeof(*x->vec));
	for (i = 0 ,ap = argv ,u = x->vec; i < argc; u++ ,ap++ ,i++)
	{	char c;
		xtype thistype = (xtype)ap->a_type;
		if      (thistype == TR_SYMBOL) c = ap->a_w.w_symbol->s_name[0];
		else if (thistype == TR_FLOAT)  c = 'a';
		else c = 0;

		switch (c)
		{ case 'b':
			u->type = TR_BANG;
			u->outlet = outlet_new(&x->obj ,&s_bang);    break;
		  case 'f':
			u->type = TR_FLOAT;
			u->outlet = outlet_new(&x->obj ,&s_float);   break;
		  case 's':
			u->type = TR_SYMBOL;
			u->outlet = outlet_new(&x->obj ,&s_symbol);  break;
		  case 'p':
			u->type = TR_POINTER;
			u->outlet = outlet_new(&x->obj ,&s_pointer); break;
		  case 'l':
			u->type = TR_LIST;
			u->outlet = outlet_new(&x->obj ,&s_list);    break;
		  default:
			pd_error(x ,"xtrigger: %s: bad type" ,ap->a_w.w_symbol->s_name);
		  case 'a':
			u->type = TR_ANYTHING;
			u->outlet = outlet_new(&x->obj ,0);   }   }
	return (x);
}

static void xtrigger_list(t_xtrigger *x ,t_symbol *s ,int argc ,t_atom *argv) {
	t_xtriggerout *u;
	int i;
	for (i = (int)x->siz ,u = x->vec + i; u-- ,i--;)
	{	xtype type = u->type;
		if (type == TR_ANYTHING && argc == 1)
			type = argv->a_type;

		switch (type)
		{ case TR_BANG:
			outlet_bang(u->outlet);
			break;
		  case TR_FLOAT:
			outlet_float(u->outlet ,(argc ? atom_getfloat(argv) : 0));
			break;
		  case TR_SYMBOL:
			outlet_symbol(u->outlet ,(argc ? atom_getsymbol(argv) : &s_symbol));
			break;
		  case TR_POINTER:
			if (!argc || (xtype)argv->a_type != TR_POINTER)
				pd_error(x ,"unpack: bad pointer");
			else outlet_pointer(u->outlet ,argv->a_w.w_gpointer);
			break;
		  default:
			outlet_list(u->outlet ,&s_list ,argc ,argv);   }   }
}

static void xtrigger_anything
(t_xtrigger *x ,t_symbol *s ,int argc ,t_atom *argv) {
	t_xtriggerout *u;
	int i;
	for (i = (int)x->siz ,u = x->vec + i; u-- ,i--;)
	{	if (u->type == TR_BANG)
			outlet_bang(u->outlet);
		else if (u->type == TR_ANYTHING)
			outlet_anything(u->outlet ,s ,argc ,argv);
		else pd_error(x ,"xtrigger: can only convert 's' to 'b' or 'a'");   }
}

static void xtrigger_bang(t_xtrigger *x) {
	xtrigger_list(x ,0 ,0 ,0);
}

static void xtrigger_pointer(t_xtrigger *x ,t_gpointer *gp) {
	t_atom at;
	SETPOINTER(&at ,gp);
	xtrigger_list(x ,0 ,1 ,&at);
}

static void xtrigger_float(t_xtrigger *x ,t_float f) {
	t_atom at;
	SETFLOAT(&at ,f);
	xtrigger_list(x ,0 ,1 ,&at);
}

static void xtrigger_symbol(t_xtrigger *x ,t_symbol *s) {
	t_atom at;
	SETSYMBOL(&at ,s);
	xtrigger_list(x ,0 ,1 ,&at);
}

static void xtrigger_free(t_xtrigger *x) {
	freebytes(x->vec ,x->siz * sizeof(*x->vec));
}

void x_setup(void) {
	xtrigger_class = class_new(gensym("x")
		,(t_newmethod)xtrigger_new ,(t_method)xtrigger_free
		,sizeof(t_xtrigger) ,0
		,A_GIMME ,0);
	class_addlist     (xtrigger_class ,xtrigger_list);
	class_addbang     (xtrigger_class ,xtrigger_bang);
	class_addpointer  (xtrigger_class ,xtrigger_pointer);
	class_addfloat    (xtrigger_class ,xtrigger_float);
	class_addsymbol   (xtrigger_class ,xtrigger_symbol);
	class_addanything (xtrigger_class ,xtrigger_anything);
}
