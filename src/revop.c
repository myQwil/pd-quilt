#include "blunt.h"

/* --------------------------------------------------------------- */
/*                   reverse arithmetics                           */
/* --------------------------------------------------------------- */

/* --------------------- subtraction ----------------------------- */
static t_class *rminus_class;

static void rminus_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_minus(x->f2 ,x->f1));
}

static void *rminus_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rminus_class ,s ,ac ,av));
}

/* --------------------- division -------------------------------- */
static t_class *rdiv_class;

static void rdiv_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_div(x->f2 ,x->f1));
}

static void *rdiv_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rdiv_class ,s ,ac ,av));
}

/* --------------------- log ------------------------------------- */
static t_class *rlog_class;

static void rlog_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_log(x->f2 ,x->f1));
}

static void *rlog_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rlog_class ,s ,ac ,av));
}

/* --------------------- pow ------------------------------------- */
static t_class *rpow_class;

static void rpow_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pow(x->f2 ,x->f1));
}

static void *rpow_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rpow_class ,s ,ac ,av));
}

/* --------------------- << -------------------------------------- */
static t_class *rls_class;

static void rls_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ls(x->f2 ,x->f1));
}

static void *rls_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rls_class ,s ,ac ,av));
}

/* --------------------- >> -------------------------------------- */
static t_class *rrs_class;

static void rrs_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_rs(x->f2 ,x->f1));
}

static void *rrs_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rrs_class ,s ,ac ,av));
}

/* --------------------- f% --------------------------------------- */
static t_class *rfpc_class;

static void rfpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fpc(x->f2 ,x->f1));
}

static void *rfpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rfpc_class ,s ,ac ,av));
}

/* --------------------- % --------------------------------------- */
static t_class *rpc_class;

static void rpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pc(x->f2 ,x->f1));
}

static void *rpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rpc_class ,s ,ac ,av));
}

/* --------------------- mod ------------------------------------- */
static t_class *rmod_class;

static void rmod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_mod(x->f2 ,x->f1));
}

static void *rmod_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rmod_class ,s ,ac ,av));
}

/* --------------------- div ------------------------------------- */
static t_class *rdivm_class;

static void rdivm_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_divm(x->f2 ,x->f1));
}

static void *rdivm_new(t_symbol *s ,int ac ,t_atom *av) {
	return (bop_new(rdivm_class ,s ,ac ,av));
}


/* ------------------- reverse moses ----------------------------- */
static t_class *rmoses_class;

typedef struct {
	t_object obj;
	t_outlet *out2;
	t_float y;
} t_rmoses;

static void *rmoses_new(t_float f) {
	t_rmoses *x = (t_rmoses*)pd_new(rmoses_class);
	floatinlet_new(&x->obj ,&x->y);
	outlet_new(&x->obj ,&s_float);
	x->out2 = outlet_new(&x->obj ,&s_float);
	x->y = f;
	return (x);
}

static void rmoses_float(t_rmoses *x ,t_float f) {
	if (f > x->y) outlet_float(x->obj.ob_outlet ,f);
	else outlet_float(x->out2 ,f);
}

static void rmoses_setup(void) {
	rmoses_class = class_new(gensym("@moses") ,(t_newmethod)rmoses_new ,0
		,sizeof(t_rmoses) ,0 ,A_DEFFLOAT ,0);
	class_addfloat(rmoses_class ,rmoses_float);
	class_sethelpsymbol(rmoses_class ,gensym("revbinops"));
}

void revop_setup(void) {
	const struct _obj
	{	t_class **class;
		const char *name;
		t_newmethod new;
		void *bang;  }
	objs[] =
	{	 { &rminus_class ,"@-"   ,(t_newmethod)rminus_new ,rminus_bang }
		,{ &rdiv_class   ,"@/"   ,(t_newmethod)rdiv_new   ,rdiv_bang   }
		,{ &rlog_class   ,"@log" ,(t_newmethod)rlog_new   ,rlog_bang   }
		,{ &rpow_class   ,"@pow" ,(t_newmethod)rpow_new   ,rpow_bang   }
		,{ &rls_class    ,"@<<"  ,(t_newmethod)rls_new    ,rls_bang    }
		,{ &rrs_class    ,"@>>"  ,(t_newmethod)rrs_new    ,rrs_bang    }
		,{ &rfpc_class   ,"@f%"  ,(t_newmethod)rfpc_new   ,rfpc_bang   }
		,{ &rpc_class    ,"@%"   ,(t_newmethod)rpc_new    ,rpc_bang    }
		,{ &rmod_class   ,"@mod" ,(t_newmethod)rmod_new   ,rmod_bang   }
		,{ &rdivm_class  ,"@div" ,(t_newmethod)rdiv_new   ,rdiv_bang   }
		,{ NULL }  } ,*obj = objs;

	t_symbol *s_rev = gensym("revbinops");
	for (; obj->class; obj++)
	{	*obj->class = class_new(gensym(obj->name) ,obj->new  ,0
			,sizeof(t_bop) ,0 ,A_GIMME ,0);

		t_class *class = *obj->class;
		class_addbang  (class ,obj->bang);
		class_addfloat (class ,bop_float);
		class_addmethod(class ,(t_method)bop_f1   ,gensym("f1")  ,A_FLOAT ,0);
		class_addmethod(class ,(t_method)bop_f2	,gensym("f2")  ,A_FLOAT ,0);
		class_addmethod(class ,(t_method)bop_skip ,gensym(".")   ,A_GIMME ,0);
		class_addmethod(class ,(t_method)bop_set  ,gensym("set") ,A_GIMME ,0);
		class_addmethod(class ,(t_method)blunt_loadbang
			,gensym("loadbang") ,A_DEFFLOAT ,0);
		class_sethelpsymbol(class ,s_rev);  }

	rmoses_setup();
}
