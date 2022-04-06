#include "blunt.h"

/* --------------------------------------------------------------- */
/*                           connectives                           */
/* --------------------------------------------------------------- */

typedef struct {
	t_blunt bl;
	t_float f;
} t_num;

static void num_print(t_num *x ,t_symbol *s) {
	if (*s->s_name) startpost("%s: " ,s->s_name);
	startpost("%g" ,x->f);
	endpost();
}

static inline void num_set(t_num *x ,t_float f) {
	x->f = f;
}

static inline void num_float(t_num *x ,t_float f) {
	num_set(x ,f);
	pd_bang((t_pd*)x);
}

static void num_symbol(t_num *x ,t_symbol *s) {
	t_float f = 0.;
	char *str_end = NULL;
	f = strtof(s->s_name ,&str_end);
	if (f == 0 && s->s_name == str_end)
		pd_error(x ,"Couldn't convert %s to float." ,s->s_name);
	else num_float(x ,f);
}

static t_num *num_new(t_class *cl ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	t_num *x = (t_num*)pd_new(cl);
	blunt_init(&x->bl ,&ac ,av);
	x->f = atom_getfloatarg(0 ,ac ,av);
	outlet_new(&x->bl.obj ,&s_float);
	floatinlet_new(&x->bl.obj ,&x->f);
	return x;
}

static t_class *class_num(t_symbol *s ,t_newmethod newm ,t_method bang ,t_method send) {
	t_class *c = class_new(s ,newm ,0 ,sizeof(t_bop) ,0 ,A_GIMME ,0);
	class_addbang  (c ,bang);
	class_addfloat (c ,num_float);
	class_addsymbol(c ,num_symbol);

	blunt_addmethod(c);
	class_addmethod(c ,(t_method)num_print ,gensym("print") ,A_DEFSYM ,0);
	class_addmethod(c ,(t_method)num_set   ,gensym("set")   ,A_FLOAT  ,0);
	class_addmethod(c ,(t_method)send      ,gensym("send")  ,A_SYMBOL ,0);
	class_sethelpsymbol(c ,gensym("blunt"));
	return c;
}

/* --------------------- int ------------------------------------- */
static t_class *i_class;

static void i_send(t_num *x ,t_symbol *s) {
	if (s->s_thing)
		pd_float(s->s_thing ,(t_float)(int64_t)x->f);
	else pd_error(x ,"%s: no such object" ,s->s_name);
}

static void i_bang(t_num *x) {
	outlet_float(x->bl.obj.ob_outlet ,(t_float)(int64_t)x->f);
}

static void *i_new(t_symbol *s ,int ac ,t_atom *av) {
	return num_new(i_class ,s ,ac ,av);
}

/* --------------------- float ----------------------------------- */
static t_class *f_class;

static void f_send(t_num *x ,t_symbol *s) {
	if (s->s_thing)
		pd_float(s->s_thing ,x->f);
	else pd_error(x ,"%s: no such object" ,s->s_name);
}

static void f_bang(t_num *x) {
	outlet_float(x->bl.obj.ob_outlet ,x->f);
}

static void *f_new(t_symbol *s ,int ac ,t_atom *av) {
	t_num *x = num_new(f_class ,s ,ac ,av);
	pd_this->pd_newest = &x->bl.obj.ob_pd;
	return x;
}


/* --------------------------------------------------------------- */
/*                           arithmetics                           */
/* --------------------------------------------------------------- */

/* ------------ unop:  !  ~  floor  ceil  factorial  ------------- */

static t_object *uop_new(t_class *cl) {
	t_object *x = (t_object*)pd_new(cl);
	outlet_new(x ,&s_float);
	return x;
}

/* --------------------- logical negation ------------------------ */
static t_class *lnot_class;

static void lnot_float(t_object *x ,t_float f) {
	outlet_float(x->ob_outlet ,!(int)f);
}

static void *lnot_new() {
	return uop_new(lnot_class);
}

/* --------------------- bitwise negation ------------------------ */
static t_class *bnot_class;

static void bnot_float(t_object *x ,t_float f) {
	outlet_float(x->ob_outlet ,~(int)f);
}

static void *bnot_new() {
	return uop_new(bnot_class);
}

/* --------------------- floor ----------------------------------- */
static t_class *floor_class;

static void floor_float(t_object *x ,t_float f) {
	outlet_float(x->ob_outlet ,FLOOR(f));
}

static void *floor_new() {
	return uop_new(floor_class);
}

/* --------------------- ceiling --------------------------------- */
static t_class *ceil_class;

static void ceil_float(t_object *x ,t_float f) {
	outlet_float(x->ob_outlet ,CEIL(f));
}

static void *ceil_new() {
	return uop_new(ceil_class);
}

/* --------------------- factorial ------------------------------- */
static t_class *fact_class;

static void fact_float(t_object *x ,t_float f) {
	outlet_float(x->ob_outlet ,blunt_factorial(f));
}

static void *fact_new() {
	return uop_new(fact_class);
}


/* --------------------- binop1:  +  -  *  /  -------------------- */

/* --------------------- addition -------------------------------- */
static t_class *b1_plus_class;

static void b1_plus_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_plus(x->f1 ,x->f2));
}

static void *b1_plus_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_plus_class ,s ,ac ,av);
}

/* --------------------- subtraction ----------------------------- */
static t_class *b1_minus_class;

static void b1_minus_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_minus(x->f1 ,x->f2));
}

static void *b1_minus_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_minus_class ,s ,ac ,av);
}

/* --------------------- multiplication -------------------------- */
static t_class *b1_times_class;

static void b1_times_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_times(x->f1 ,x->f2));
}

static void *b1_times_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_times_class ,s ,ac ,av);
}

/* --------------------- division -------------------------------- */
static t_class *b1_div_class;

static void b1_div_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_div(x->f1 ,x->f2));
}

static void *b1_div_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_div_class ,s ,ac ,av);
}

/* --------------------- log ------------------------------------- */
static t_class *b1_log_class;

static void b1_log_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_log(x->f1 ,x->f2));
}

static void *b1_log_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_log_class ,s ,ac ,av);
}

/* --------------------- pow ------------------------------------- */
static t_class *b1_pow_class;

static void b1_pow_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pow(x->f1 ,x->f2));
}

static void *b1_pow_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_pow_class ,s ,ac ,av);
}

/* --------------------- max ------------------------------------- */
static t_class *b1_max_class;

static void b1_max_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_max(x->f1 ,x->f2));
}

static void *b1_max_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_max_class ,s ,ac ,av);
}

/* --------------------- min ------------------------------------- */
static t_class *b1_min_class;

static void b1_min_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_min(x->f1 ,x->f2));
}

static void *b1_min_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b1_min_class ,s ,ac ,av);
}


/* --------------- binop2:  ==  !=  >  <  >=  <=  ---------------- */

/* --------------------- == -------------------------------------- */
static t_class *b2_ee_class;

static void b2_ee_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ee(x->f1 ,x->f2));
}

static void *b2_ee_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b2_ee_class ,s ,ac ,av);
}

/* --------------------- != -------------------------------------- */
static t_class *b2_ne_class;

static void b2_ne_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ne(x->f1 ,x->f2));
}

static void *b2_ne_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b2_ne_class ,s ,ac ,av);
}

/* --------------------- > --------------------------------------- */
static t_class *b2_gt_class;

static void b2_gt_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_gt(x->f1 ,x->f2));
}

static void *b2_gt_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b2_gt_class ,s ,ac ,av);
}

/* --------------------- < --------------------------------------- */
static t_class *b2_lt_class;

static void b2_lt_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_lt(x->f1 ,x->f2));
}

static void *b2_lt_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b2_lt_class ,s ,ac ,av);
}

/* --------------------- >= -------------------------------------- */
static t_class *b2_ge_class;

static void b2_ge_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ge(x->f1 ,x->f2));
}

static void *b2_ge_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b2_ge_class ,s ,ac ,av);
}

/* --------------------- <= -------------------------------------- */
static t_class *b2_le_class;

static void b2_le_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_le(x->f1 ,x->f2));
}

static void *b2_le_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b2_le_class ,s ,ac ,av);
}


/* ------- binop3:  &  |  &&  ||  <<  >>  ^  %  mod  div  -------- */

/* --------------------- & --------------------------------------- */
static t_class *b3_ba_class;

static void b3_ba_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ba(x->f1 ,x->f2));
}

static void *b3_ba_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_ba_class ,s ,ac ,av);
}

/* --------------------- && -------------------------------------- */
static t_class *b3_la_class;

static void b3_la_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_la(x->f1 ,x->f2));
}

static void *b3_la_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_la_class ,s ,ac ,av);
}

/* --------------------- | --------------------------------------- */
static t_class *b3_bo_class;

static void b3_bo_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_bo(x->f1 ,x->f2));
}

static void *b3_bo_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_bo_class ,s ,ac ,av);
}

/* --------------------- || -------------------------------------- */
static t_class *b3_lo_class;

static void b3_lo_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_lo(x->f1 ,x->f2));
}

static void *b3_lo_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_lo_class ,s ,ac ,av);
}

/* --------------------- << -------------------------------------- */
static t_class *b3_ls_class;

static void b3_ls_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ls(x->f1 ,x->f2));
}

static void *b3_ls_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_ls_class ,s ,ac ,av);
}

/* --------------------- >> -------------------------------------- */
static t_class *b3_rs_class;

static void b3_rs_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_rs(x->f1 ,x->f2));
}

static void *b3_rs_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_rs_class ,s ,ac ,av);
}

/* --------------------- % --------------------------------------- */
static t_class *b3_pc_class;

static void b3_pc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pc(x->f1 ,x->f2));
}

static void *b3_pc_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_pc_class ,s ,ac ,av);
}

/* --------------------- f% --------------------------------------- */
static t_class *b3_fpc_class;

static void b3_fpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fpc(x->f1 ,x->f2));
}

static void *b3_fpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_fpc_class ,s ,ac ,av);
}

/* --------------------- mod ------------------------------------- */
static t_class *b3_mod_class;

static void b3_mod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_mod(x->f1 ,x->f2));
}

static void *b3_mod_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_mod_class ,s ,ac ,av);
}

/* --------------------- fmod ------------------------------------ */
static t_class *b3_fmod_class;

static void b3_fmod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fmod(x->f1 ,x->f2));
}

static void *b3_fmod_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_fmod_class ,s ,ac ,av);
}

/* --------------------- div ------------------------------------- */
static t_class *b3_div_class;

static void b3_div_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_divm(x->f1 ,x->f2));
}

static void *b3_div_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_div_class ,s ,ac ,av);
}

/* --------------------- ^ --------------------------------------- */
static t_class *b3_xor_class;

static void b3_xor_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_xor(x->f1 ,x->f2));
}

static void *b3_xor_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(b3_xor_class ,s ,ac ,av);
}


/* -------------------------- bang ------------------------------ */
static t_class *bng_class;

typedef struct {
	t_blunt bl;
} t_bng;

static void b_bang(t_bng *x) {
	outlet_bang(x->bl.obj.ob_outlet);
}

static void *b_new(t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	t_bng *x = (t_bng*)pd_new(bng_class);
	blunt_init(&x->bl ,&ac ,av);
	outlet_new(&x->bl.obj ,&s_bang);
	pd_this->pd_newest = &x->bl.obj.ob_pd;
	return x;
}

static void bng_setup(void) {
	bng_class = class_new(gensym("b") ,(t_newmethod)b_new ,0
		,sizeof(t_bng) ,0 ,A_GIMME ,0);
	class_addcreator((t_newmethod)b_new ,gensym("`b") ,A_GIMME ,0);
	class_addbang     (bng_class ,b_bang);
	class_addfloat    (bng_class ,b_bang);
	class_addsymbol   (bng_class ,b_bang);
	class_addlist     (bng_class ,b_bang);
	class_addanything (bng_class ,b_bang);

	blunt_addmethod(bng_class);
	class_sethelpsymbol(bng_class ,gensym("blunt"));
}


/* -------------------------- symbol ------------------------------ */
static t_class *sym_class;

typedef struct {
	t_blunt bl;
	t_symbol *sym;
} t_sym;

static void sym_print(t_sym *x ,t_symbol *s) {
	if (*s->s_name) startpost("%s: " ,s->s_name);
	startpost("%s" ,x->sym->s_name);
	endpost();
}

static void sym_bang(t_sym *x) {
	outlet_symbol(x->bl.obj.ob_outlet ,x->sym);
}

static void sym_symbol(t_sym *x ,t_symbol *s) {
	outlet_symbol(x->bl.obj.ob_outlet ,x->sym = s);
}

static void sym_anything(t_sym *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)ac;
	(void)av;
	outlet_symbol(x->bl.obj.ob_outlet ,x->sym = s);
}

static void sym_list(t_sym *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	if (!ac)
		sym_bang(x);
	else if (av->a_type == A_SYMBOL)
		sym_symbol(x ,av->a_w.w_symbol);
	else sym_anything(x ,s ,ac ,av);
}

static void *sym_new(t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	t_sym *x = (t_sym*)pd_new(sym_class);
	blunt_init(&x->bl ,&ac ,av);
	x->sym = atom_getsymbolarg(0 ,ac ,av);
	outlet_new(&x->bl.obj ,&s_symbol);
	symbolinlet_new(&x->bl.obj ,&x->sym);
	pd_this->pd_newest = &x->bl.obj.ob_pd;
	return x;
}

void sym_setup(void) {
	sym_class = class_new(gensym("sym") ,(t_newmethod)sym_new ,0
		,sizeof(t_sym) ,0 ,A_GIMME ,0);
	class_addbang     (sym_class ,sym_bang);
	class_addsymbol   (sym_class ,sym_symbol);
	class_addlist     (sym_class ,sym_list);
	class_addanything (sym_class ,sym_anything);

	blunt_addmethod(sym_class);
	class_addmethod(sym_class ,(t_method)sym_print ,gensym("print") ,A_DEFSYM ,0);
	class_sethelpsymbol(sym_class ,gensym("blunt"));
}


/* --------------------------------------------------------------- */
/*                   reverse arithmetics                           */
/* --------------------------------------------------------------- */

/* --------------------- subtraction ----------------------------- */
static t_class *rminus_class;

static void rminus_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_minus(x->f2 ,x->f1));
}

static void *rminus_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rminus_class ,s ,ac ,av);
}

/* --------------------- division -------------------------------- */
static t_class *rdiv_class;

static void rdiv_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_div(x->f2 ,x->f1));
}

static void *rdiv_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rdiv_class ,s ,ac ,av);
}

/* --------------------- log ------------------------------------- */
static t_class *rlog_class;

static void rlog_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_log(x->f2 ,x->f1));
}

static void *rlog_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rlog_class ,s ,ac ,av);
}

/* --------------------- pow ------------------------------------- */
static t_class *rpow_class;

static void rpow_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pow(x->f2 ,x->f1));
}

static void *rpow_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rpow_class ,s ,ac ,av);
}

/* --------------------- << -------------------------------------- */
static t_class *rls_class;

static void rls_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ls(x->f2 ,x->f1));
}

static void *rls_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rls_class ,s ,ac ,av);
}

/* --------------------- >> -------------------------------------- */
static t_class *rrs_class;

static void rrs_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_rs(x->f2 ,x->f1));
}

static void *rrs_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rrs_class ,s ,ac ,av);
}

/* --------------------- % --------------------------------------- */
static t_class *rpc_class;

static void rpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pc(x->f2 ,x->f1));
}

static void *rpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rpc_class ,s ,ac ,av);
}

/* --------------------- f% -------------------------------------- */
static t_class *rfpc_class;

static void rfpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fpc(x->f2 ,x->f1));
}

static void *rfpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rfpc_class ,s ,ac ,av);
}

/* --------------------- mod ------------------------------------- */
static t_class *rmod_class;

static void rmod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_mod(x->f2 ,x->f1));
}

static void *rmod_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rmod_class ,s ,ac ,av);
}

/* --------------------- fmod ------------------------------------ */
static t_class *rfmod_class;

static void rfmod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fmod(x->f2 ,x->f1));
}

static void *rfmod_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rfmod_class ,s ,ac ,av);
}

/* --------------------- div ------------------------------------- */
static t_class *rdivm_class;

static void rdivm_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_divm(x->f2 ,x->f1));
}

static void *rdivm_new(t_symbol *s ,int ac ,t_atom *av) {
	return bop_new(rdivm_class ,s ,ac ,av);
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
	return x;
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
	const struct
	{	t_class **cls;
		const char *name;
		void (*bang)(t_bop*);
		void *(*new)(t_symbol* ,int ,t_atom*);  }
	objs[] =
	{	 { &rminus_class ,"@-"    ,rminus_bang ,rminus_new }
		,{ &rdiv_class   ,"@/"    ,rdiv_bang   ,rdiv_new   }
		,{ &rlog_class   ,"@log"  ,rlog_bang   ,rlog_new   }
		,{ &rpow_class   ,"@pow"  ,rpow_bang   ,rpow_new   }
		,{ &rls_class    ,"@<<"   ,rls_bang    ,rls_new    }
		,{ &rrs_class    ,"@>>"   ,rrs_bang    ,rrs_new    }
		,{ &rpc_class    ,"@%"    ,rpc_bang    ,rpc_new    }
		,{ &rfpc_class   ,"@f%"   ,rfpc_bang   ,rfpc_new   }
		,{ &rmod_class   ,"@mod"  ,rmod_bang   ,rmod_new   }
		,{ &rfmod_class  ,"@fmod" ,rfmod_bang  ,rfmod_new  }
		,{ &rdivm_class  ,"@div"  ,rdivm_bang  ,rdivm_new  }
		,{ NULL ,NULL ,NULL ,NULL }  } ,*obj = objs;

	t_symbol *s_rev = gensym("revbinops");
	for (; obj->cls; obj++)
	{	*obj->cls = class_bop(gensym(obj->name)
			,(t_newmethod)obj->new ,(t_method)obj->bang);
		class_sethelpsymbol(*obj->cls ,s_rev);  }

	rmoses_setup();
}


#ifdef _WIN32 // MSYS2 cannot find this function in <string.h>
char *stpcpy(char *dest ,const char *src) {
	size_t len = strlen(src);
	return memcpy(dest ,src ,len + 1) + len;
}
#endif

/* --------------------------------------------------------------- */
/*                       hot-inlet arithmetics                     */
/* --------------------------------------------------------------- */

typedef struct {
	t_object obj;
	t_bop *x;
} t_hot_pxy;

typedef struct {
	t_bop x;
	t_hot_pxy *p;
} t_hot;

static void hot_pxy_f1(t_hot_pxy *p ,t_float f) {
	bop_f1(p->x ,f);
}

static void hot_pxy_f2(t_hot_pxy *p ,t_float f) {
	bop_f2(p->x ,f);
}

static inline void hot_pxy_set(t_hot_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	if (ac > 1 && av[1].a_type == A_FLOAT) p->x->f1 = av[1].a_w.w_float;
	if (ac     && av[0].a_type == A_FLOAT) p->x->f2 = av[0].a_w.w_float;
}

static void hot_pxy_bang(t_hot_pxy *p) {
	pd_bang((t_pd*)p->x);
}

static void hot_pxy_float(t_hot_pxy *p ,t_float f) {
	bop_f2(p->x ,f);
	pd_bang((t_pd*)p->x);
}

static void hot_pxy_list(t_hot_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	hot_pxy_set(p ,s ,ac ,av);
	pd_bang((t_pd*)p->x);
}

static void hot_pxy_anything(t_hot_pxy *p ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	if (ac && av->a_type == A_FLOAT)
		p->x->f1 = av->a_w.w_float;
	pd_bang((t_pd*)p->x);
}

static t_hot *hot_new(t_class *cz ,t_class *cp ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	t_hot *z = (t_hot*)pd_new(cz);
	t_hot_pxy *p = (t_hot_pxy*)pd_new(cp);
	t_bop *x = &z->x;
	z->p = p;
	p->x = x;
	bop_init(x ,ac ,av);
	inlet_new(&x->bl.obj ,(t_pd*)p ,0 ,0);
	return z;
}

static t_class *class_hot_pxy(const char *name) {
	char alt[11] = "_";
	strcpy(stpcpy(alt+1 ,name) ,"_pxy");

	t_class *c = class_new(gensym(alt) ,0 ,0
		,sizeof(t_hot_pxy) ,CLASS_PD | CLASS_NOINLET ,0);
	class_addbang     (c ,hot_pxy_bang);
	class_addfloat    (c ,hot_pxy_float);
	class_addlist     (c ,hot_pxy_list);
	class_addanything (c ,hot_pxy_anything);
	class_addmethod(c ,(t_method)hot_pxy_f1  ,gensym("f1")  ,A_FLOAT ,0);
	class_addmethod(c ,(t_method)hot_pxy_f2  ,gensym("f2")  ,A_FLOAT ,0);
	class_addmethod(c ,(t_method)hot_pxy_set ,gensym("set") ,A_GIMME ,0);
	return c;
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
	return hot_new(hplus_class ,hplus_proxy ,s ,ac ,av);
}

/* --------------------- subtraction ----------------------------- */
static t_class *hminus_class;
static t_class *hminus_proxy;

static void hminus_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_minus(x->f1 ,x->f2));
}

static void *hminus_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hminus_class ,hminus_proxy ,s ,ac ,av);
}

/* --------------------- multiplication -------------------------- */
static t_class *htimes_class;
static t_class *htimes_proxy;

static void htimes_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_times(x->f1 ,x->f2));
}

static void *htimes_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(htimes_class ,htimes_proxy ,s ,ac ,av);
}

/* --------------------- division -------------------------------- */
static t_class *hdiv_class;
static t_class *hdiv_proxy;

static void hdiv_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_div(x->f1 ,x->f2));
}

static void *hdiv_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hdiv_class ,hdiv_proxy ,s ,ac ,av);
}

/* --------------------- log ------------------------------------- */
static t_class *hlog_class;
static t_class *hlog_proxy;

static void hlog_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_log(x->f1 ,x->f2));
}

static void *hlog_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hlog_class ,hlog_proxy ,s ,ac ,av);
}

/* --------------------- pow ------------------------------------- */
static t_class *hpow_class;
static t_class *hpow_proxy;

static void hpow_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pow(x->f1 ,x->f2));
}

static void *hpow_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hpow_class ,hpow_proxy ,s ,ac ,av);
}

/* --------------------- max ------------------------------------- */
static t_class *hmax_class;
static t_class *hmax_proxy;

static void hmax_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_max(x->f1 ,x->f2));
}

static void *hmax_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hmax_class ,hmax_proxy ,s ,ac ,av);
}

/* --------------------- min ------------------------------------- */
static t_class *hmin_class;
static t_class *hmin_proxy;

static void hmin_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_min(x->f1 ,x->f2));
}

static void *hmin_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hmin_class ,hmin_proxy ,s ,ac ,av);
}

/* --------------- binop2: == ,!= ,> ,< ,>= ,<=. ----------------- */

/* --------------------- == -------------------------------------- */
static t_class *hee_class;
static t_class *hee_proxy;

static void hee_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ee(x->f1 ,x->f2));
}

static void *hee_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hee_class ,hee_proxy ,s ,ac ,av);
}

/* --------------------- != -------------------------------------- */
static t_class *hne_class;
static t_class *hne_proxy;

static void hne_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ne(x->f1 ,x->f2));
}

static void *hne_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hne_class ,hne_proxy ,s ,ac ,av);
}

/* --------------------- > --------------------------------------- */
static t_class *hgt_class;
static t_class *hgt_proxy;

static void hgt_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_gt(x->f1 ,x->f2));
}

static void *hgt_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hgt_class ,hgt_proxy ,s ,ac ,av);
}

/* --------------------- < --------------------------------------- */
static t_class *hlt_class;
static t_class *hlt_proxy;

static void hlt_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_lt(x->f1 ,x->f2));
}

static void *hlt_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hlt_class ,hlt_proxy ,s ,ac ,av);
}

/* --------------------- >= -------------------------------------- */
static t_class *hge_class;
static t_class *hge_proxy;

static void hge_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ge(x->f1 ,x->f2));
}

static void *hge_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hge_class ,hge_proxy ,s ,ac ,av);
}

/* --------------------- <= -------------------------------------- */
static t_class *hle_class;
static t_class *hle_proxy;

static void hle_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_le(x->f1 ,x->f2));
}

static void *hle_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hle_class ,hle_proxy ,s ,ac ,av);
}

/* ------- binop3: & ,| ,&& ,|| ,<< ,>> ,^ ,% ,mod ,div ------------- */

/* --------------------- & --------------------------------------- */
static t_class *hba_class;
static t_class *hba_proxy;

static void hba_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ba(x->f1 ,x->f2));
}

static void *hba_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hba_class ,hba_proxy ,s ,ac ,av);
}

/* --------------------- && -------------------------------------- */
static t_class *hla_class;
static t_class *hla_proxy;

static void hla_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_la(x->f1 ,x->f2));
}

static void *hla_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hla_class ,hla_proxy ,s ,ac ,av);
}

/* --------------------- | --------------------------------------- */
static t_class *hbo_class;
static t_class *hbo_proxy;

static void hbo_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_bo(x->f1 ,x->f2));
}

static void *hbo_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hbo_class ,hbo_proxy ,s ,ac ,av);
}

/* --------------------- || -------------------------------------- */
static t_class *hlo_class;
static t_class *hlo_proxy;

static void hlo_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_lo(x->f1 ,x->f2));
}

static void *hlo_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hlo_class ,hlo_proxy ,s ,ac ,av);
}

/* --------------------- << -------------------------------------- */
static t_class *hls_class;
static t_class *hls_proxy;

static void hls_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_ls(x->f1 ,x->f2));
}

static void *hls_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hls_class ,hls_proxy ,s ,ac ,av);
}

/* --------------------- >> -------------------------------------- */
static t_class *hrs_class;
static t_class *hrs_proxy;

static void hrs_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_rs(x->f1 ,x->f2));
}

static void *hrs_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hrs_class ,hrs_proxy ,s ,ac ,av);
}

/* --------------------- ^ --------------------------------------- */
static t_class *hxor_class;
static t_class *hxor_proxy;

static void hxor_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_xor(x->f1 ,x->f2));
}

static void *hxor_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hxor_class ,hxor_proxy ,s ,ac ,av);
}

/* --------------------- % --------------------------------------- */
static t_class *hpc_class;
static t_class *hpc_proxy;

static void hpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_pc(x->f1 ,x->f2));
}

static void *hpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hpc_class ,hpc_proxy ,s ,ac ,av);
}

/* --------------------- f% --------------------------------------- */
static t_class *hfpc_class;
static t_class *hfpc_proxy;

static void hfpc_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fpc(x->f1 ,x->f2));
}

static void *hfpc_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hfpc_class ,hfpc_proxy ,s ,ac ,av);
}

/* --------------------- mod ------------------------------------- */
static t_class *hmod_class;
static t_class *hmod_proxy;

static void hmod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_mod(x->f1 ,x->f2));
}

static void *hmod_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hmod_class ,hmod_proxy ,s ,ac ,av);
}

/* --------------------- fmod ------------------------------------ */
static t_class *hfmod_class;
static t_class *hfmod_proxy;

static void hfmod_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_fmod(x->f1 ,x->f2));
}

static void *hfmod_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hfmod_class ,hfmod_proxy ,s ,ac ,av);
}

/* --------------------- div ------------------------------------- */
static t_class *hdivm_class;
static t_class *hdivm_proxy;

static void hdivm_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet ,blunt_divm(x->f1 ,x->f2));
}

static void *hdivm_new(t_symbol *s ,int ac ,t_atom *av) {
	return hot_new(hdivm_class ,hdivm_proxy ,s ,ac ,av);
}

void hotop_setup(void) {
	const struct
	{	t_class **cls;
		t_class **pxy;
		const char *name;
		void (*bang)(t_bop*);
		void *(*new)(t_symbol* ,int ,t_atom*);  }
	objs[] =
	{	 { &hplus_class  ,&hplus_proxy  ,"#+"    ,hplus_bang  ,hplus_new  }
		,{ &hminus_class ,&hminus_proxy ,"#-"    ,hminus_bang ,hminus_new }
		,{ &htimes_class ,&htimes_proxy ,"#*"    ,htimes_bang ,htimes_new }
		,{ &hdiv_class   ,&hdiv_proxy   ,"#/"    ,hdiv_bang   ,hdiv_new   }
		,{ &hlog_class   ,&hlog_proxy   ,"#log"  ,hlog_bang   ,hlog_new   }
		,{ &hpow_class   ,&hpow_proxy   ,"#pow"  ,hpow_bang   ,hpow_new   }
		,{ &hmax_class   ,&hmax_proxy   ,"#max"  ,hmax_bang   ,hmax_new   }
		,{ &hmin_class   ,&hmin_proxy   ,"#min"  ,hmin_bang   ,hmin_new   }
		,{ NULL ,NULL ,NULL ,NULL ,NULL }
		,{ &hee_class    ,&hee_proxy    ,"#=="   ,hee_bang    ,hee_new    }
		,{ &hne_class    ,&hne_proxy    ,"#!="   ,hne_bang    ,hne_new    }
		,{ &hgt_class    ,&hgt_proxy    ,"#>"    ,hgt_bang    ,hgt_new    }
		,{ &hlt_class    ,&hlt_proxy    ,"#<"    ,hlt_bang    ,hlt_new    }
		,{ &hge_class    ,&hge_proxy    ,"#>="   ,hge_bang    ,hge_new    }
		,{ &hle_class    ,&hle_proxy    ,"#<="   ,hle_bang    ,hle_new    }
		,{ NULL ,NULL ,NULL ,NULL ,NULL }
		,{ &hba_class    ,&hba_proxy    ,"#&"    ,hba_bang    ,hba_new    }
		,{ &hla_class    ,&hla_proxy    ,"#&&"   ,hla_bang    ,hla_new    }
		,{ &hbo_class    ,&hbo_proxy    ,"#|"    ,hbo_bang    ,hbo_new    }
		,{ &hlo_class    ,&hlo_proxy    ,"#||"   ,hlo_bang    ,hlo_new    }
		,{ &hls_class    ,&hls_proxy    ,"#<<"   ,hls_bang    ,hls_new    }
		,{ &hrs_class    ,&hrs_proxy    ,"#>>"   ,hrs_bang    ,hrs_new    }
		,{ &hpc_class    ,&hpc_proxy    ,"#%"    ,hpc_bang    ,hpc_new    }
		,{ &hfpc_class   ,&hfpc_proxy   ,"#f%"   ,hfpc_bang   ,hfpc_new   }
		,{ &hmod_class   ,&hmod_proxy   ,"#mod"  ,hmod_bang   ,hmod_new   }
		,{ &hfmod_class  ,&hfmod_proxy  ,"#fmod" ,hfmod_bang  ,hfmod_new  }
		,{ &hdivm_class  ,&hdivm_proxy  ,"#div"  ,hdivm_bang  ,hdivm_new  }
		,{ NULL ,NULL ,NULL ,NULL ,NULL }
		,{ &hxor_class   ,&hxor_proxy   ,"#^"    ,hxor_bang   ,hxor_new   }
		,{ NULL ,NULL ,NULL ,NULL ,NULL }  } ,*obj = objs;

	t_symbol *syms[] =
	{	 gensym("hotbinops1") ,gensym("hotbinops2") ,gensym("hotbinops3")
		,gensym("0x5e") ,NULL  } ,**sym = syms;

	for (; *sym; sym++ ,obj++) for (; obj->cls; obj++)
	{	*obj->pxy = class_hot_pxy(obj->name);
		*obj->cls = class_new(gensym(obj->name)
			,(t_newmethod)obj->new ,(t_method)hot_free
			,sizeof(t_hot) ,0 ,A_GIMME ,0);

		bop_addmethods(*obj->cls ,(t_method)obj->bang);
		class_sethelpsymbol(*obj->cls ,*sym);  }
}


void blunt_setup(void) {

	post("\nBlunt! version " VERSION "\ncompiled " DATE " " TIME " UTC");

	t_symbol *s_blunt = gensym("blunt");
	s_load  = gensym("!");
	s_init  = gensym("$");
	s_close = gensym("&");
	char alt[6] = "`";

	/* ---------------- connectives --------------------- */

	const struct
	{	t_class **cls;
		const char *name;
		void (*bang)(t_num*);
		void (*send)(t_num* ,t_symbol*);
		void *(*new)(t_symbol* ,int ,t_atom*);  }
	nums[] =
	{	 { &i_class ,"i" ,i_bang ,i_send ,i_new }
		,{ &f_class ,"f" ,f_bang ,f_send ,f_new }
		,{ NULL ,NULL ,NULL ,NULL ,NULL }  } ,*num = nums;

	for (; num->cls; num++)
	{	*num->cls = class_num(gensym(num->name)
			,(t_newmethod)num->new ,(t_method)num->bang ,(t_method)num->send);
		strcpy(alt+1 ,num->name);
		class_addcreator((t_newmethod)num->new ,gensym(alt) ,A_GIMME ,0);  }


	/* ---------------- unops --------------------- */

	t_symbol *usyms[] =
		{ gensym("negation") ,gensym("rounding") ,gensym("factorial") ,NULL }
		,**usym = usyms;
	const struct
	{	t_class **cls;
		const char *name;
		void (*flt)(t_object* ,t_float);
		void *(*new)(t_symbol* ,int ,t_atom*);  }
	uops[] =
	{	 { &lnot_class  ,"!"     ,lnot_float  ,lnot_new  }
		,{ &bnot_class  ,"~"     ,bnot_float  ,bnot_new  }
		,{ NULL ,NULL ,NULL ,NULL }
		,{ &floor_class ,"floor" ,floor_float ,floor_new }
		,{ &ceil_class  ,"ceil"  ,ceil_float  ,ceil_new  }
		,{ NULL ,NULL ,NULL ,NULL }
		,{ &fact_class  ,"n!"    ,fact_float  ,fact_new  }
		,{ NULL ,NULL ,NULL ,NULL }  } ,*uop = uops;

	for (; *usym; usym++ ,uop++) for (; uop->cls; uop++)
	{	*uop->cls = class_new(gensym(uop->name) ,(t_newmethod)uop->new ,0
			,sizeof(t_object) ,0 ,A_NULL);
		class_addfloat(*uop->cls ,uop->flt);
		class_sethelpsymbol(*uop->cls ,*usym);  }


	/* ---------------- binops --------------------- */

	t_symbol *bsyms[] = { s_blunt ,gensym("0x5e") ,NULL } ,**bsym = bsyms;
	const struct
	{	t_class **cls;
		const char *name;
		void (*bang)(t_bop*);
		void *(*new)(t_symbol* ,int ,t_atom*);  }
	bops[] =
	{	 { &b1_plus_class  ,"+"    ,b1_plus_bang  ,b1_plus_new  }
		,{ &b1_minus_class ,"-"    ,b1_minus_bang ,b1_minus_new }
		,{ &b1_times_class ,"*"    ,b1_times_bang ,b1_times_new }
		,{ &b1_div_class   ,"/"    ,b1_div_bang   ,b1_div_new   }
		,{ &b1_log_class   ,"log"  ,b1_log_bang   ,b1_log_new   }
		,{ &b1_pow_class   ,"pow"  ,b1_pow_bang   ,b1_pow_new   }
		,{ &b1_max_class   ,"max"  ,b1_max_bang   ,b1_max_new   }
		,{ &b1_min_class   ,"min"  ,b1_min_bang   ,b1_min_new   }
		,{ &b2_ee_class    ,"=="   ,b2_ee_bang    ,b2_ee_new    }
		,{ &b2_ne_class    ,"!="   ,b2_ne_bang    ,b2_ne_new    }
		,{ &b2_gt_class    ,">"    ,b2_gt_bang    ,b2_gt_new    }
		,{ &b2_lt_class    ,"<"    ,b2_lt_bang    ,b2_lt_new    }
		,{ &b2_ge_class    ,">="   ,b2_ge_bang    ,b2_ge_new    }
		,{ &b2_le_class    ,"<="   ,b2_le_bang    ,b2_le_new    }
		,{ &b3_ba_class    ,"&"    ,b3_ba_bang    ,b3_ba_new    }
		,{ &b3_la_class    ,"&&"   ,b3_la_bang    ,b3_la_new    }
		,{ &b3_bo_class    ,"|"    ,b3_bo_bang    ,b3_bo_new    }
		,{ &b3_lo_class    ,"||"   ,b3_lo_bang    ,b3_lo_new    }
		,{ &b3_ls_class    ,"<<"   ,b3_ls_bang    ,b3_ls_new    }
		,{ &b3_rs_class    ,">>"   ,b3_rs_bang    ,b3_rs_new    }
		,{ &b3_pc_class    ,"%"    ,b3_pc_bang    ,b3_pc_new    }
		,{ &b3_fpc_class   ,"f%"   ,b3_fpc_bang   ,b3_fpc_new   }
		,{ &b3_mod_class   ,"mod"  ,b3_mod_bang   ,b3_mod_new   }
		,{ &b3_fmod_class  ,"fmod" ,b3_fmod_bang  ,b3_fmod_new  }
		,{ &b3_div_class   ,"div"  ,b3_div_bang   ,b3_div_new   }
		,{ NULL ,NULL ,NULL ,NULL }
		,{ &b3_xor_class   ,"^"    ,b3_xor_bang   ,b3_xor_new   }
		,{ NULL ,NULL ,NULL ,NULL }  } ,*bop = bops;

	for (; *bsym; bsym++ ,bop++) for (; bop->cls; bop++)
	{	*bop->cls = class_bop(gensym(bop->name)
			,(t_newmethod)bop->new ,(t_method)bop->bang);
		strcpy(alt+1 ,bop->name);
		class_addcreator((t_newmethod)bop->new ,gensym(alt) ,A_GIMME ,0);
		class_sethelpsymbol(*bop->cls ,*bsym);  }

	/* hot & reverse binops */
	hotop_setup();
	revop_setup();
	bng_setup();
	sym_setup();
}
