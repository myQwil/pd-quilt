#include "blunt.h"

#ifdef MSW // MSYS2 cannot find this function in <string.h>
char *stpcpy(char *dest ,const char *src) {
	size_t len = strlen(src);
	return memcpy(dest ,src ,len + 1) + len;
}
#endif

/* --------------------------------------------------------------- */
/*                       hot arithmetics                           */
/* --------------------------------------------------------------- */

typedef struct {
	t_object obj;
	t_bop *x;
} t_hot_pxy;

typedef struct {
	t_bop x;
	t_hot_pxy *p;
} t_hot;

static void hot_pxy_bang(t_hot_pxy *p) {
	t_bop *x = p->x;
	pd_bang((t_pd*)x);
}

static void hot_pxy_float(t_hot_pxy *p ,t_float f) {
	t_bop *x = p->x;
	x->f2 = f;
	pd_bang((t_pd*)x);
}

static void hot_pxy_f1(t_hot_pxy *p ,t_float f) {
	bop_f1(p->x ,f);
}

static void hot_pxy_f2(t_hot_pxy *p ,t_float f) {
	bop_f2(p->x ,f);
}

static void hot_pxy_skip(t_hot_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	t_bop *x = p->x;
	if (ac && av->a_type == A_FLOAT)
		x->f1 = av->a_w.w_float;
	pd_bang((t_pd*)x);
}

static void hot_pxy_set(t_hot_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	t_bop *x = p->x;
	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->f2 = av->a_w.w_float;
		ac-- ,av++;  }
	if (ac && av->a_type == A_FLOAT)
		x->f1 = av->a_w.w_float;
}

static t_hot *hot_new(t_class *cz ,t_class *cp ,t_symbol *s ,int ac ,t_atom *av) {
	t_hot *z = (t_hot*)pd_new(cz);
	t_hot_pxy *p = (t_hot_pxy*)pd_new(cp);
	t_bop *x = &z->x;
	z->p = p;
	p->x = x;
	bop_init(x ,ac ,av);
	inlet_new(&x->bl.obj ,(t_pd*)p ,0 ,0);
	return (z);
}

static void hot_free(t_hot *z) {
	pd_free((t_pd*)z->p);
}


/* --------------------- binop1:  + ,- ,* ,/ --------------------- */

/* --------------------- addition -------------------------------- */
static t_class *hplus_class;
static t_class *hplus_proxy;

static void hplus_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_plus(x->f1 ,x->f2));
}

static void *hplus_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hplus_class ,hplus_proxy ,s ,ac ,av));
}

/* --------------------- subtraction ----------------------------- */
static t_class *hminus_class;
static t_class *hminus_proxy;

static void hminus_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_minus(x->f1 ,x->f2));
}

static void *hminus_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hminus_class ,hminus_proxy ,s ,ac ,av));
}

/* --------------------- multiplication -------------------------- */
static t_class *htimes_class;
static t_class *htimes_proxy;

static void htimes_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_times(x->f1 ,x->f2));
}

static void *htimes_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(htimes_class ,htimes_proxy ,s ,ac ,av));
}

/* --------------------- division -------------------------------- */
static t_class *hdiv_class;
static t_class *hdiv_proxy;

static void hdiv_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_div(x->f1 ,x->f2));
}

static void *hdiv_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hdiv_class ,hdiv_proxy ,s ,ac ,av));
}

/* --------------------- log ------------------------------------- */
static t_class *hlog_class;
static t_class *hlog_proxy;

static void hlog_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_log(x->f1 ,x->f2));
}

static void *hlog_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hlog_class ,hlog_proxy ,s ,ac ,av));
}

/* --------------------- pow ------------------------------------- */
static t_class *hpow_class;
static t_class *hpow_proxy;

static void hpow_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pow(x->f1 ,x->f2));
}

static void *hpow_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hpow_class ,hpow_proxy ,s ,ac ,av));
}

/* --------------------- max ------------------------------------- */
static t_class *hmax_class;
static t_class *hmax_proxy;

static void hmax_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_max(x->f1 ,x->f2));
}

static void *hmax_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hmax_class ,hmax_proxy ,s ,ac ,av));
}

/* --------------------- min ------------------------------------- */
static t_class *hmin_class;
static t_class *hmin_proxy;

static void hmin_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_min(x->f1 ,x->f2));
}

static void *hmin_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hmin_class ,hmin_proxy ,s ,ac ,av));
}

/* --------------- binop2: == ,!= ,> ,< ,>= ,<=. ----------------- */

/* --------------------- == -------------------------------------- */
static t_class *hee_class;
static t_class *hee_proxy;

static void hee_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ee(x->f1 ,x->f2));
}

static void *hee_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hee_class ,hee_proxy ,s ,ac ,av));
}

/* --------------------- != -------------------------------------- */
static t_class *hne_class;
static t_class *hne_proxy;

static void hne_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ne(x->f1 ,x->f2));
}

static void *hne_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hne_class ,hne_proxy ,s ,ac ,av));
}

/* --------------------- > --------------------------------------- */
static t_class *hgt_class;
static t_class *hgt_proxy;

static void hgt_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_gt(x->f1 ,x->f2));
}

static void *hgt_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hgt_class ,hgt_proxy ,s ,ac ,av));
}

/* --------------------- < --------------------------------------- */
static t_class *hlt_class;
static t_class *hlt_proxy;

static void hlt_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_lt(x->f1 ,x->f2));
}

static void *hlt_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hlt_class ,hlt_proxy ,s ,ac ,av));
}

/* --------------------- >= -------------------------------------- */
static t_class *hge_class;
static t_class *hge_proxy;

static void hge_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ge(x->f1 ,x->f2));
}

static void *hge_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hge_class ,hge_proxy ,s ,ac ,av));
}

/* --------------------- <= -------------------------------------- */
static t_class *hle_class;
static t_class *hle_proxy;

static void hle_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_le(x->f1 ,x->f2));
}

static void *hle_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hle_class ,hle_proxy ,s ,ac ,av));
}

/* ------- binop3: & ,| ,&& ,|| ,<< ,>> ,^ ,% ,mod ,div ------------- */

/* --------------------- & --------------------------------------- */
static t_class *hba_class;
static t_class *hba_proxy;

static void hba_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ba(x->f1 ,x->f2));
}

static void *hba_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hba_class ,hba_proxy ,s ,ac ,av));
}

/* --------------------- && -------------------------------------- */
static t_class *hla_class;
static t_class *hla_proxy;

static void hla_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_la(x->f1 ,x->f2));
}

static void *hla_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hla_class ,hla_proxy ,s ,ac ,av));
}

/* --------------------- | --------------------------------------- */
static t_class *hbo_class;
static t_class *hbo_proxy;

static void hbo_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_bo(x->f1 ,x->f2));
}

static void *hbo_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hbo_class ,hbo_proxy ,s ,ac ,av));
}

/* --------------------- || -------------------------------------- */
static t_class *hlo_class;
static t_class *hlo_proxy;

static void hlo_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_lo(x->f1 ,x->f2));
}

static void *hlo_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hlo_class ,hlo_proxy ,s ,ac ,av));
}

/* --------------------- << -------------------------------------- */
static t_class *hls_class;
static t_class *hls_proxy;

static void hls_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ls(x->f1 ,x->f2));
}

static void *hls_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hls_class ,hls_proxy ,s ,ac ,av));
}

/* --------------------- >> -------------------------------------- */
static t_class *hrs_class;
static t_class *hrs_proxy;

static void hrs_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_rs(x->f1 ,x->f2));
}

static void *hrs_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hrs_class ,hrs_proxy ,s ,ac ,av));
}

/* --------------------- ^ --------------------------------------- */
static t_class *hxor_class;
static t_class *hxor_proxy;

static void hxor_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_xor(x->f1 ,x->f2));
}

static void *hxor_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hxor_class ,hxor_proxy ,s ,ac ,av));
}

/* --------------------- f% --------------------------------------- */
static t_class *hfpc_class;
static t_class *hfpc_proxy;

static void hfpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fpc(x->f1 ,x->f2));
}

static void *hfpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hfpc_class ,hfpc_proxy ,s ,ac ,av));
}

/* --------------------- % --------------------------------------- */
static t_class *hpc_class;
static t_class *hpc_proxy;

static void hpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pc(x->f1 ,x->f2));
}

static void *hpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hpc_class ,hpc_proxy ,s ,ac ,av));
}

/* --------------------- mod ------------------------------------- */
static t_class *hmod_class;
static t_class *hmod_proxy;

static void hmod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_mod(x->f1 ,x->f2));
}

static void *hmod_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hmod_class ,hmod_proxy ,s ,ac ,av));
}

/* --------------------- div ------------------------------------- */
static t_class *hdivm_class;
static t_class *hdivm_proxy;

static void hdivm_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_divm(x->f1 ,x->f2));
}

static void *hdivm_new(t_symbol *s ,int ac ,t_atom *av) {
	return (hot_new(hdivm_class ,hdivm_proxy ,s ,ac ,av));
}

void hotop_setup(void) {
	const struct _obj
	{	t_class **class;
		t_class **proxy;
		const char *name;
		t_newmethod new;
		t_bopmethod bang;  }
	objs[] =
	{	 { &hplus_class  ,&hplus_proxy  ,"#+"   ,(t_newmethod)hplus_new  ,hplus_bang  }
		,{ &hminus_class ,&hminus_proxy ,"#-"   ,(t_newmethod)hminus_new ,hminus_bang }
		,{ &htimes_class ,&htimes_proxy ,"#*"   ,(t_newmethod)htimes_new ,htimes_bang }
		,{ &hdiv_class   ,&hdiv_proxy   ,"#/"   ,(t_newmethod)hdiv_new   ,hdiv_bang   }
		,{ &hlog_class   ,&hlog_proxy   ,"#log" ,(t_newmethod)hlog_new   ,hlog_bang   }
		,{ &hpow_class   ,&hpow_proxy   ,"#pow" ,(t_newmethod)hpow_new   ,hpow_bang   }
		,{ &hmax_class   ,&hmax_proxy   ,"#max" ,(t_newmethod)hmax_new   ,hmax_bang   }
		,{ &hmin_class   ,&hmin_proxy   ,"#min" ,(t_newmethod)hmin_new   ,hmin_bang   }
		,{ NULL }
		,{ &hee_class    ,&hee_proxy    ,"#=="  ,(t_newmethod)hee_new    ,hee_bang    }
		,{ &hne_class    ,&hne_proxy    ,"#!="  ,(t_newmethod)hne_new    ,hne_bang    }
		,{ &hgt_class    ,&hgt_proxy    ,"#>"   ,(t_newmethod)hgt_new    ,hgt_bang    }
		,{ &hlt_class    ,&hlt_proxy    ,"#<"   ,(t_newmethod)hlt_new    ,hlt_bang    }
		,{ &hge_class    ,&hge_proxy    ,"#>="  ,(t_newmethod)hge_new    ,hge_bang    }
		,{ &hle_class    ,&hle_proxy    ,"#<="  ,(t_newmethod)hle_new    ,hle_bang    }
		,{ NULL }
		,{ &hba_class    ,&hba_proxy    ,"#&"   ,(t_newmethod)hba_new    ,hba_bang    }
		,{ &hla_class    ,&hla_proxy    ,"#&&"  ,(t_newmethod)hla_new    ,hla_bang    }
		,{ &hbo_class    ,&hbo_proxy    ,"#|"   ,(t_newmethod)hbo_new    ,hbo_bang    }
		,{ &hlo_class    ,&hlo_proxy    ,"#||"  ,(t_newmethod)hlo_new    ,hlo_bang    }
		,{ &hls_class    ,&hls_proxy    ,"#<<"  ,(t_newmethod)hls_new    ,hls_bang    }
		,{ &hrs_class    ,&hrs_proxy    ,"#>>"  ,(t_newmethod)hrs_new    ,hrs_bang    }
		,{ &hfpc_class   ,&hfpc_proxy   ,"#f%"  ,(t_newmethod)hfpc_new   ,hfpc_bang   }
		,{ &hpc_class    ,&hpc_proxy    ,"#%"   ,(t_newmethod)hpc_new    ,hpc_bang    }
		,{ &hmod_class   ,&hmod_proxy   ,"#mod" ,(t_newmethod)hmod_new   ,hmod_bang   }
		,{ &hdivm_class  ,&hdivm_proxy  ,"#div" ,(t_newmethod)hdivm_new  ,hdivm_bang  }
		,{ NULL }
		,{ &hxor_class   ,&hxor_proxy   ,"#^"   ,(t_newmethod)hxor_new   ,hxor_bang   }
		,{ NULL }  };

	t_symbol *syms[] =
	{	 gensym("hotbinops1") ,gensym("hotbinops2") ,gensym("hotbinops3")
		,gensym("0x5e") ,NULL  };

	int i=0 ,j=0;
	char alt[10] = "_";
	for (; syms[i]; i++ ,j++)
	{	for (; objs[j].class; j++)
		{	struct _obj obj = objs[j];
			const char *name = obj.name;

			*obj.class = class_new(gensym(name) ,obj.new ,(t_method)hot_free
				,sizeof(t_hot) ,0 ,A_GIMME ,0);
			strcpy(stpcpy(alt+1 ,name) ,"_pxy");
			*obj.proxy = class_new(gensym(alt) ,0 ,0
				,sizeof(t_hot_pxy) ,CLASS_PD | CLASS_NOINLET ,0);

			t_class *class = *obj.class;
			t_class *proxy = *obj.proxy;
			class_addbang  (class ,obj.bang);
			class_addfloat (class ,bop_float);
			class_addmethod(class ,(t_method)bop_f1   ,gensym("f1")  ,A_FLOAT ,0);
			class_addmethod(class ,(t_method)bop_f2   ,gensym("f2")  ,A_FLOAT ,0);
			class_addmethod(class ,(t_method)bop_skip ,gensym(".")   ,A_GIMME ,0);
			class_addmethod(class ,(t_method)bop_set  ,gensym("set") ,A_GIMME ,0);
			class_addmethod(class ,(t_method)blunt_loadbang
				,gensym("loadbang") ,A_DEFFLOAT ,0);

			class_addbang  (proxy ,hot_pxy_bang);
			class_addfloat (proxy ,hot_pxy_float);
			class_addmethod(proxy ,(t_method)hot_pxy_f1   ,gensym("f1")  ,A_FLOAT ,0);
			class_addmethod(proxy ,(t_method)hot_pxy_f2   ,gensym("f2")  ,A_FLOAT ,0);
			class_addmethod(proxy ,(t_method)hot_pxy_skip ,gensym(".")   ,A_GIMME ,0);
			class_addmethod(proxy ,(t_method)hot_pxy_set  ,gensym("set") ,A_GIMME ,0);

			class_sethelpsymbol(class ,syms[i]);  }  }
}
