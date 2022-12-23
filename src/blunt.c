#include "blunt.h"

struct _obj { // we'll use this in setup functions for convenience
	t_class **cls;
	const char *name;
	void *(*new)(t_symbol *, int, t_atom *);
};

/* ---------------------------------------------------------------- */
/*                           connectives                            */
/* ---------------------------------------------------------------- */

typedef t_float(*t_uopfn)(t_float);

typedef struct {
	t_blunt bl;
	t_uopfn fn;
	t_float f;
} t_num;

static void num_print(t_num *x, t_symbol *s) {
	if (*s->s_name) {
		startpost("%s: ", s->s_name);
	}
	startpost("%g", x->f);
	endpost();
}

static void num_send(t_num *x, t_symbol *s) {
	if (s->s_thing) {
		pd_float(s->s_thing, x->fn(x->f));
	} else {
		pd_error(x, "%s: no such object", s->s_name);
	}
}

static inline void num_set(t_num *x, t_float f) {
	x->f = f;
}

static inline void num_bang(t_num *x) {
	outlet_float(x->bl.obj.ob_outlet, x->fn(x->f));
}

static inline void num_float(t_num *x, t_float f) {
	num_set(x, f);
	num_bang(x);
}

static void num_symbol(t_num *x, t_symbol *s) {
	t_float f = 0.;
	char *str_end = NULL;
	f = strtof(s->s_name, &str_end);
	if (f == 0 && s->s_name == str_end) {
		pd_error(x, "Couldn't convert %s to float.", s->s_name);
	} else {
		num_float(x, f);
	}
}

static t_num *num_new(t_class *cl, t_uopfn fn, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_num *x = (t_num *)pd_new(cl);
	blunt_init(&x->bl, &ac, av);
	outlet_new(&x->bl.obj, &s_float);
	floatinlet_new(&x->bl.obj, &x->f);
	x->f = atom_getfloatarg(0, ac, av);
	x->fn = fn;
	return x;
}

static t_class *class_num(t_symbol *s, t_newmethod n) {
	t_class *c = class_new(s, n, 0, sizeof(t_bop), 0, A_GIMME, 0);
	class_addbang(c, num_bang);
	class_addfloat(c, num_float);
	class_addsymbol(c, num_symbol);

	blunt_addmethod(c);
	class_addmethod(c, (t_method)num_print, gensym("print"), A_DEFSYM, 0);
	class_addmethod(c, (t_method)num_set, gensym("set"), A_FLOAT, 0);
	class_addmethod(c, (t_method)num_send, gensym("send"), A_SYMBOL, 0);
	class_sethelpsymbol(c, gensym("blunt"));
	return c;
}

static t_class *i_class; /* ------------------- int ------------------------- */
static void *i_new(t_symbol *s, int ac, t_atom *av) {
	return num_new(i_class, fn_int, s, ac, av);
}

static t_class *f_class; /* ------------------- float ----------------------- */
static void *f_new(t_symbol *s, int ac, t_atom *av) {
	t_num *x = num_new(f_class, fn_float, s, ac, av);
	pd_this->pd_newest = &x->bl.obj.ob_pd;
	return x;
}


/* --------------------- bang ------------------------------------- */
static t_class *bng_class;

typedef struct {
	t_blunt bl;
} t_bng;

static void b_bang(t_bng *x) {
	outlet_bang(x->bl.obj.ob_outlet);
}

static void *b_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_bng *x = (t_bng *)pd_new(bng_class);
	blunt_init(&x->bl, &ac, av);
	outlet_new(&x->bl.obj, &s_bang);
	pd_this->pd_newest = &x->bl.obj.ob_pd;
	return x;
}

static void bng_setup(void) {
	bng_class = class_new(gensym("b"), (t_newmethod)b_new, 0
	, sizeof(t_bng), 0, A_GIMME, 0);
	class_addcreator((t_newmethod)b_new, gensym("`b"), A_GIMME, 0);
	class_addbang(bng_class, b_bang);
	class_addfloat(bng_class, b_bang);
	class_addsymbol(bng_class, b_bang);
	class_addlist(bng_class, b_bang);
	class_addanything(bng_class, b_bang);

	blunt_addmethod(bng_class);
	class_sethelpsymbol(bng_class, gensym("blunt"));
}

/* --------------------- symbol ----------------------------------- */
static t_class *sym_class;

typedef struct {
	t_blunt bl;
	t_symbol *sym;
} t_sym;

static void sym_print(t_sym *x, t_symbol *s) {
	if (*s->s_name) {
		startpost("%s: ", s->s_name);
	}
	startpost("%s", x->sym->s_name);
	endpost();
}

static void sym_bang(t_sym *x) {
	outlet_symbol(x->bl.obj.ob_outlet, x->sym);
}

static void sym_symbol(t_sym *x, t_symbol *s) {
	outlet_symbol(x->bl.obj.ob_outlet, x->sym = s);
}

static void sym_anything(t_sym *x, t_symbol *s, int ac, t_atom *av) {
	(void)ac;
	(void)av;
	outlet_symbol(x->bl.obj.ob_outlet, x->sym = s);
}

static void sym_list(t_sym *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!ac) {
		sym_bang(x);
	} else if (av->a_type == A_SYMBOL) {
		sym_symbol(x, av->a_w.w_symbol);
	} else {
		sym_anything(x, s, ac, av);
	}
}

static void *sym_new(t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_sym *x = (t_sym *)pd_new(sym_class);
	blunt_init(&x->bl, &ac, av);
	x->sym = atom_getsymbolarg(0, ac, av);
	outlet_new(&x->bl.obj, &s_symbol);
	symbolinlet_new(&x->bl.obj, &x->sym);
	pd_this->pd_newest = &x->bl.obj.ob_pd;
	return x;
}

void sym_setup(void) {
	sym_class = class_new(gensym("sym")
	, (t_newmethod)sym_new, 0
	, sizeof(t_sym), 0
	, A_GIMME, 0);
	class_addbang(sym_class, sym_bang);
	class_addlist(sym_class, sym_list);
	class_addsymbol(sym_class, sym_symbol);
	class_addanything(sym_class, sym_anything);

	blunt_addmethod(sym_class);
	class_addmethod(sym_class, (t_method)sym_print, gensym("print"), A_DEFSYM, 0);
	class_sethelpsymbol(sym_class, gensym("blunt"));
}


/* ---------------------------------------------------------------- */
/*                           arithmetics                            */
/* ---------------------------------------------------------------- */

/* ------------- unop:  !  ~  floor  ceil  factorial  ------------- */
typedef struct {
	t_object obj;
	t_uopfn fn;
} t_uop;

static void uop_float(t_uop *x, t_float f) {
	outlet_float(x->obj.ob_outlet, x->fn(f));
}

static t_uop *uop_new(t_class *cl, t_uopfn fn) {
	t_uop *x = (t_uop *)pd_new(cl);
	outlet_new(&x->obj, &s_float);
	x->fn = fn;
	return x;
}

static t_class *lnot_class; /* ---------------- logical negation ------------ */
static void *lnot_new() {
	return uop_new(lnot_class, fn_lnot);
}

static t_class *bnot_class; /* ---------------- bitwise negation ------------ */
static void *bnot_new() {
	return uop_new(bnot_class, fn_bnot);
}

static t_class *floor_class; /* --------------- floor ----------------------- */
static void *floor_new() {
	return uop_new(floor_class, FLOOR);
}

static t_class *ceil_class; /* ---------------- ceiling --------------------- */
static void *ceil_new() {
	return uop_new(ceil_class, CEIL);
}

static t_class *fact_class; /* ---------------- factorial ------------------- */
static void *fact_new() {
	return uop_new(fact_class, fn_factorial);
}


/* --------------------- binop1:  +  -  *  /  --------------------- */

static t_class *b1_plus_class; /* ------------- addition -------------------- */
static void *b1_plus_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_plus_class, fn_plus, s, ac, av);
}

static t_class *b1_minus_class; /* ------------ subtraction ----------------- */
static void *b1_minus_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_minus_class, fn_minus, s, ac, av);
}

static t_class *b1_times_class; /* ------------ multiplication -------------- */
static void *b1_times_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_times_class, fn_times, s, ac, av);
}

static t_class *b1_div_class; /* -------------- division -------------------- */
static void *b1_div_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_div_class, fn_div, s, ac, av);
}

static t_class *b1_log_class; /* -------------- log ------------------------- */
static void *b1_log_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_log_class, fn_log, s, ac, av);
}

static t_class *b1_pow_class; /* -------------- pow ------------------------- */
static void *b1_pow_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_pow_class, fn_pow, s, ac, av);
}

static t_class *b1_max_class; /* -------------- max ------------------------- */
static void *b1_max_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_max_class, fn_max, s, ac, av);
}

static t_class *b1_min_class; /* -------------- min ------------------------- */
static void *b1_min_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b1_min_class, fn_min, s, ac, av);
}


/* ---------------- binop2:  ==  !=  >  <  >=  <=  ---------------- */

static t_class *b2_ee_class; /* --------------- == -------------------------- */
static void *b2_ee_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b2_ee_class, fn_ee, s, ac, av);
}

static t_class *b2_ne_class; /* --------------- != -------------------------- */
static void *b2_ne_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b2_ne_class, fn_ne, s, ac, av);
}

static t_class *b2_gt_class; /* --------------- > --------------------------- */
static void *b2_gt_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b2_gt_class, fn_gt, s, ac, av);
}

static t_class *b2_lt_class; /* --------------- < --------------------------- */
static void *b2_lt_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b2_lt_class, fn_lt, s, ac, av);
}

static t_class *b2_ge_class; /* --------------- >= -------------------------- */
static void *b2_ge_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b2_ge_class, fn_ge, s, ac, av);
}

static t_class *b2_le_class; /* --------------- <= -------------------------- */
static void *b2_le_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b2_le_class, fn_le, s, ac, av);
}


/* -------- binop3:  &  |  &&  ||  <<  >>  ^  %  mod  div  -------- */

static t_class *b3_ba_class; /* --------------- & --------------------------- */
static void *b3_ba_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_ba_class, fn_ba, s, ac, av);
}

static t_class *b3_la_class; /* --------------- && -------------------------- */
static void *b3_la_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_la_class, fn_la, s, ac, av);
}

static t_class *b3_bo_class; /* --------------- | --------------------------- */
static void *b3_bo_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_bo_class, fn_bo, s, ac, av);
}

static t_class *b3_lo_class; /* --------------- || -------------------------- */
static void *b3_lo_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_lo_class, fn_lo, s, ac, av);
}

static t_class *b3_ls_class; /* --------------- << -------------------------- */
static void *b3_ls_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_ls_class, fn_ls, s, ac, av);
}

static t_class *b3_rs_class; /* --------------- >> -------------------------- */
static void *b3_rs_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_rs_class, fn_rs, s, ac, av);
}

static t_class *b3_pc_class; /* --------------- % --------------------------- */
static void *b3_pc_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_pc_class, fn_pc, s, ac, av);
}

static t_class *b3_fpc_class; /* -------------- f% -------------------------- */
static void *b3_fpc_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_fpc_class, fn_fpc, s, ac, av);
}

static t_class *b3_mod_class; /* -------------- mod ------------------------- */
static void *b3_mod_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_mod_class, fn_mod, s, ac, av);
}

static t_class *b3_fmod_class; /* ------------- fmod ------------------------ */
static void *b3_fmod_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_fmod_class, fn_fmod, s, ac, av);
}

static t_class *b3_div_class; /* -------------- div ------------------------- */
static void *b3_div_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_div_class, fn_divm, s, ac, av);
}

static t_class *b3_xor_class; /* -------------- ^ --------------------------- */
static void *b3_xor_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(b3_xor_class, fn_xor, s, ac, av);
}


/* ---------------------------------------------------------------- */
/*                       reverse arithmetics                        */
/* ---------------------------------------------------------------- */

static inline void rev_bang(t_bop *x) {
	outlet_float(x->bl.obj.ob_outlet, x->fn(x->f2, x->f1));
}

static void rev_float(t_bop *x, t_float f) {
	bop_f1(x, f);
	rev_bang(x);
}

static void rev_list(t_bop *x, t_symbol *s, int ac, t_atom *av) {
	bop_set(x, s, ac, av);
	rev_bang(x);
}

static void rev_anything(t_bop *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (ac && av->a_type == A_FLOAT) {
		x->f2 = av->a_w.w_float;
	}
	rev_bang(x);
}

static t_class *rminus_class; /* -------------- subtraction ----------------- */
static void *rminus_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rminus_class, fn_minus, s, ac, av);
}

static t_class *rdiv_class; /* ---------------- division -------------------- */
static void *rdiv_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rdiv_class, fn_div, s, ac, av);
}

static t_class *rlog_class; /* ---------------- log ------------------------- */
static void *rlog_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rlog_class, fn_log, s, ac, av);
}

static t_class *rpow_class; /* ---------------- pow ------------------------- */
static void *rpow_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rpow_class, fn_pow, s, ac, av);
}

static t_class *rls_class; /* ----------------- << -------------------------- */
static void *rls_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rls_class, fn_ls, s, ac, av);
}

static t_class *rrs_class; /* ----------------- >> -------------------------- */
static void *rrs_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rrs_class, fn_rs, s, ac, av);
}

static t_class *rpc_class; /* ----------------- % --------------------------- */
static void *rpc_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rpc_class, fn_pc, s, ac, av);
}

static t_class *rfpc_class; /* ---------------- f% -------------------------- */
static void *rfpc_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rfpc_class, fn_fpc, s, ac, av);
}

static t_class *rmod_class; /* ---------------- mod ------------------------- */
static void *rmod_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rmod_class, fn_mod, s, ac, av);
}

static t_class *rfmod_class; /* --------------- fmod ------------------------ */
static void *rfmod_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rfmod_class, fn_fmod, s, ac, av);
}

static t_class *rdivm_class; /* --------------- div ------------------------- */
static void *rdivm_new(t_symbol *s, int ac, t_atom *av) {
	return bop_new(rdivm_class, fn_divm, s, ac, av);
}


/* --------------------- reverse moses ---------------------------- */
static t_class *rmoses_class;

typedef struct {
	t_object obj;
	t_outlet *out2;
	t_float y;
} t_rmoses;

static void *rmoses_new(t_float f) {
	t_rmoses *x = (t_rmoses *)pd_new(rmoses_class);
	floatinlet_new(&x->obj, &x->y);
	outlet_new(&x->obj, &s_float);
	x->out2 = outlet_new(&x->obj, &s_float);
	x->y = f;
	return x;
}

static void rmoses_float(t_rmoses *x, t_float f) {
	if (f > x->y) {
		outlet_float(x->obj.ob_outlet, f);
	} else {
		outlet_float(x->out2, f);
	}
}

static void rmoses_setup(void) {
	rmoses_class = class_new(gensym("@moses")
	, (t_newmethod)rmoses_new, 0
	, sizeof(t_rmoses), 0
	, A_DEFFLOAT, 0);
	class_addfloat(rmoses_class, rmoses_float);
	class_sethelpsymbol(rmoses_class, gensym("revbinops"));
}


/* --------------------- revop setup ------------------------------ */
void revop_setup(void) {
	const struct _obj objs[] = {
	  { &rminus_class, "@-"   , rminus_new }
	, { &rdiv_class  , "@/"   , rdiv_new   }
	, { &rlog_class  , "@log" , rlog_new   }
	, { &rpow_class  , "@pow" , rpow_new   }
	, { &rls_class   , "@<<"  , rls_new    }
	, { &rrs_class   , "@>>"  , rrs_new    }
	, { &rpc_class   , "@%"   , rpc_new    }
	, { &rfpc_class  , "@f%"  , rfpc_new   }
	, { &rmod_class  , "@mod" , rmod_new   }
	, { &rfmod_class , "@fmod", rfmod_new  }
	, { &rdivm_class , "@div" , rdivm_new  }
	, { NULL         , NULL   , NULL       }
	}, *obj = objs;

	t_symbol *s_rev = gensym("revbinops");
	for (; obj->cls; obj++) {
		*obj->cls = class_bop(gensym(obj->name), (t_newmethod)obj->new);
		class_addbang(*obj->cls, rev_bang);
		class_addfloat(*obj->cls, rev_float);
		class_addlist(*obj->cls, rev_list);
		class_addanything(*obj->cls, rev_anything);
		class_sethelpsymbol(*obj->cls, s_rev);
	}

	rmoses_setup();
}


/* ---------------------------------------------------------------- */
/*                      hot-inlet arithmetics                       */
/* ---------------------------------------------------------------- */

typedef struct {
	t_object obj;
	t_bop *x;
} t_hot_pxy;

typedef struct {
	t_bop x;
	t_hot_pxy *p;
} t_hot;

static void hot_pxy_f1(t_hot_pxy *p, t_float f) {
	bop_f1(p->x, f);
}

static void hot_pxy_f2(t_hot_pxy *p, t_float f) {
	bop_f2(p->x, f);
}

static inline void hot_pxy_set(t_hot_pxy *p, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (ac > 1 && av[1].a_type == A_FLOAT) {
		p->x->f1 = av[1].a_w.w_float;
	}
	if (ac && av[0].a_type == A_FLOAT) {
		p->x->f2 = av[0].a_w.w_float;
	}
}

static void hot_pxy_bang(t_hot_pxy *p) {
	bop_bang(p->x);
}

static void hot_pxy_float(t_hot_pxy *p, t_float f) {
	bop_f2(p->x, f);
	bop_bang(p->x);
}

static void hot_pxy_list(t_hot_pxy *p, t_symbol *s, int ac, t_atom *av) {
	hot_pxy_set(p, s, ac, av);
	bop_bang(p->x);
}

static void hot_pxy_anything(t_hot_pxy *p, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (ac && av->a_type == A_FLOAT) {
		p->x->f1 = av->a_w.w_float;
	}
	bop_bang(p->x);
}

static t_hot *hot_new
(t_class *cz, t_class *cp, t_bopfn fn, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	t_hot *z = (t_hot *)pd_new(cz);
	t_hot_pxy *p = (t_hot_pxy *)pd_new(cp);
	t_bop *x = &z->x;
	z->p = p;
	p->x = x;
	bop_init(x, ac, av);
	inlet_new(&x->bl.obj, (t_pd *)p, 0, 0);
	x->fn = fn;
	return z;
}

#ifdef _WIN32 // MSYS2 cannot find this function in <string.h>
char *stpcpy(char *dest, const char *src) {
	size_t len = strlen(src);
	return memcpy(dest, src, len + 1) + len;
}
#endif

static t_class *class_hot_pxy(const char *name) {
	char alt[11] = "_";
	strcpy(stpcpy(alt + 1, name), "_pxy");

	t_class *c = class_new(gensym(alt)
	, 0, 0
	, sizeof(t_hot_pxy), CLASS_PD | CLASS_NOINLET
	, 0);
	class_addbang(c, hot_pxy_bang);
	class_addlist(c, hot_pxy_list);
	class_addfloat(c, hot_pxy_float);
	class_addanything(c, hot_pxy_anything);
	class_addmethod(c, (t_method)hot_pxy_f1, gensym("f1"), A_FLOAT, 0);
	class_addmethod(c, (t_method)hot_pxy_f2, gensym("f2"), A_FLOAT, 0);
	class_addmethod(c, (t_method)hot_pxy_set, gensym("set"), A_GIMME, 0);
	return c;
}

static void hot_free(t_hot *z) {
	pd_free((t_pd *)z->p);
}


/* --------------------- binop1:  +  -  *  /  --------------------- */

static t_class *hplus_class; /* --------------- addition -------------------- */
static t_class *hplus_proxy;
static void *hplus_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hplus_class, hplus_proxy, fn_plus, s, ac, av);
}

static t_class *hminus_class; /* -------------- subtraction ----------------- */
static t_class *hminus_proxy;
static void *hminus_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hminus_class, hminus_proxy, fn_minus, s, ac, av);
}

static t_class *htimes_class; /* -------------- multiplication -------------- */
static t_class *htimes_proxy;
static void *htimes_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(htimes_class, htimes_proxy, fn_times, s, ac, av);
}

static t_class *hdiv_class; /* ---------------- division -------------------- */
static t_class *hdiv_proxy;
static void *hdiv_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hdiv_class, hdiv_proxy, fn_div, s, ac, av);
}

static t_class *hlog_class; /* ---------------- log ------------------------- */
static t_class *hlog_proxy;
static void *hlog_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hlog_class, hlog_proxy, fn_log, s, ac, av);
}

static t_class *hpow_class; /* ---------------- pow ------------------------- */
static t_class *hpow_proxy;
static void *hpow_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hpow_class, hpow_proxy, fn_pow, s, ac, av);
}

static t_class *hmax_class; /* ---------------- max ------------------------- */
static t_class *hmax_proxy;
static void *hmax_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hmax_class, hmax_proxy, fn_max, s, ac, av);
}

static t_class *hmin_class; /* ---------------- min ------------------------- */
static t_class *hmin_proxy;
static void *hmin_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hmin_class, hmin_proxy, fn_min, s, ac, av);
}

/* ---------------- binop2:  ==  !=  >  <  >=  <=  ---------------- */

static t_class *hee_class; /* ----------------- == -------------------------- */
static t_class *hee_proxy;
static void *hee_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hee_class, hee_proxy, fn_ee, s, ac, av);
}

static t_class *hne_class; /* ----------------- != -------------------------- */
static t_class *hne_proxy;
static void *hne_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hne_class, hne_proxy, fn_ne, s, ac, av);
}

static t_class *hgt_class; /* ----------------- > --------------------------- */
static t_class *hgt_proxy;
static void *hgt_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hgt_class, hgt_proxy, fn_gt, s, ac, av);
}

static t_class *hlt_class; /* ----------------- < --------------------------- */
static t_class *hlt_proxy;
static void *hlt_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hlt_class, hlt_proxy, fn_lt, s, ac, av);
}

static t_class *hge_class; /* ----------------- >= -------------------------- */
static t_class *hge_proxy;
static void *hge_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hge_class, hge_proxy, fn_ge, s, ac, av);
}

static t_class *hle_class; /* ----------------- <= -------------------------- */
static t_class *hle_proxy;
static void *hle_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hle_class, hle_proxy, fn_le, s, ac, av);
}

/* -------- binop3:  &  |  &&  ||  <<  >>  ^  %  mod  div  -------- */

static t_class *hba_class; /* ----------------- & --------------------------- */
static t_class *hba_proxy;
static void *hba_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hba_class, hba_proxy, fn_ba, s, ac, av);
}

static t_class *hla_class; /* ----------------- && -------------------------- */
static t_class *hla_proxy;
static void *hla_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hla_class, hla_proxy, fn_la, s, ac, av);
}

static t_class *hbo_class; /* ----------------- | --------------------------- */
static t_class *hbo_proxy;
static void *hbo_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hbo_class, hbo_proxy, fn_bo, s, ac, av);
}

static t_class *hlo_class; /* ----------------- || -------------------------- */
static t_class *hlo_proxy;
static void *hlo_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hlo_class, hlo_proxy, fn_lo, s, ac, av);
}

static t_class *hls_class; /* ----------------- << -------------------------- */
static t_class *hls_proxy;
static void *hls_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hls_class, hls_proxy, fn_ls, s, ac, av);
}

static t_class *hrs_class; /* ----------------- >> -------------------------- */
static t_class *hrs_proxy;
static void *hrs_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hrs_class, hrs_proxy, fn_rs, s, ac, av);
}

static t_class *hxor_class; /* ---------------- ^ --------------------------- */
static t_class *hxor_proxy;
static void *hxor_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hxor_class, hxor_proxy, fn_xor, s, ac, av);
}

static t_class *hpc_class; /* ----------------- % --------------------------- */
static t_class *hpc_proxy;
static void *hpc_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hpc_class, hpc_proxy, fn_pc, s, ac, av);
}

static t_class *hfpc_class; /* ---------------- f% -------------------------- */
static t_class *hfpc_proxy;
static void *hfpc_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hfpc_class, hfpc_proxy, fn_fpc, s, ac, av);
}

static t_class *hmod_class; /* ---------------- mod ------------------------- */
static t_class *hmod_proxy;
static void *hmod_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hmod_class, hmod_proxy, fn_mod, s, ac, av);
}

static t_class *hfmod_class; /* --------------- fmod ------------------------ */
static t_class *hfmod_proxy;
static void *hfmod_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hfmod_class, hfmod_proxy, fn_fmod, s, ac, av);
}

static t_class *hdivm_class; /* --------------- div ------------------------- */
static t_class *hdivm_proxy;
static void *hdivm_new(t_symbol *s, int ac, t_atom *av) {
	return hot_new(hdivm_class, hdivm_proxy, fn_divm, s, ac, av);
}


/* --------------------- hotop setup ------------------------------ */
void hotop_setup(void) {
	t_symbol *syms[] = {
	  gensym("hotbinops1"), gensym("hotbinops2"), gensym("hotbinops3")
	, gensym("0x5e"), NULL
	}, **sym = syms;

	const struct {
		t_class **cls;
		t_class **pxy;
		const char *name;
		void *(*new)(t_symbol *, int, t_atom *);
	} objs[] = {
	  { &hplus_class , &hplus_proxy , "#+"   , hplus_new  }
	, { &hminus_class, &hminus_proxy, "#-"   , hminus_new }
	, { &htimes_class, &htimes_proxy, "#*"   , htimes_new }
	, { &hdiv_class  , &hdiv_proxy  , "#/"   , hdiv_new   }
	, { &hlog_class  , &hlog_proxy  , "#log" , hlog_new   }
	, { &hpow_class  , &hpow_proxy  , "#pow" , hpow_new   }
	, { &hmax_class  , &hmax_proxy  , "#max" , hmax_new   }
	, { &hmin_class  , &hmin_proxy  , "#min" , hmin_new   }
	, { NULL         , NULL         , NULL   , NULL       }
	, { &hee_class   , &hee_proxy   , "#=="  , hee_new    }
	, { &hne_class   , &hne_proxy   , "#!="  , hne_new    }
	, { &hgt_class   , &hgt_proxy   , "#>"   , hgt_new    }
	, { &hlt_class   , &hlt_proxy   , "#<"   , hlt_new    }
	, { &hge_class   , &hge_proxy   , "#>="  , hge_new    }
	, { &hle_class   , &hle_proxy   , "#<="  , hle_new    }
	, { NULL         , NULL         , NULL   , NULL       }
	, { &hba_class   , &hba_proxy   , "#&"   , hba_new    }
	, { &hla_class   , &hla_proxy   , "#&&"  , hla_new    }
	, { &hbo_class   , &hbo_proxy   , "#|"   , hbo_new    }
	, { &hlo_class   , &hlo_proxy   , "#||"  , hlo_new    }
	, { &hls_class   , &hls_proxy   , "#<<"  , hls_new    }
	, { &hrs_class   , &hrs_proxy   , "#>>"  , hrs_new    }
	, { &hpc_class   , &hpc_proxy   , "#%"   , hpc_new    }
	, { &hfpc_class  , &hfpc_proxy  , "#f%"  , hfpc_new   }
	, { &hmod_class  , &hmod_proxy  , "#mod" , hmod_new   }
	, { &hfmod_class , &hfmod_proxy , "#fmod", hfmod_new  }
	, { &hdivm_class , &hdivm_proxy , "#div" , hdivm_new  }
	, { NULL         , NULL         , NULL   , NULL       }
	, { &hxor_class  , &hxor_proxy  , "#^"   , hxor_new   }
	, { NULL         , NULL         , NULL   , NULL       }
	}, *obj = objs;

	for (; *sym; sym++, obj++) {
		for (; obj->cls; obj++) {
			*obj->pxy = class_hot_pxy(obj->name);
			*obj->cls = class_new(gensym(obj->name)
			, (t_newmethod)obj->new, (t_method)hot_free
			, sizeof(t_hot), 0
			, A_GIMME, 0);

			bop_addmethods(*obj->cls);
			class_sethelpsymbol(*obj->cls, *sym);
		}
	}
}


/* --------------------- blunt setup ------------------------------ */
void blunt_setup(void) {

	startpost("\nBlunt! version 0.8.2\n");
#ifdef BLUNT
	startpost("compiled " DATE " " TIME " UTC\n");
#endif
	endpost();

	t_symbol *s_blunt = gensym("blunt");
	s_load = gensym("!");
	s_init = gensym("$");
	s_close = gensym("&");
	char alt[6] = "`";

	/* --------------- connectives ----------------------- */

	const struct _obj nums[] = {
	  { &i_class, "i" , i_new }
	, { &f_class, "f" , f_new }
	, { NULL    , NULL, NULL  }
	}, *num = nums;

	for (; num->cls; num++) {
		*num->cls = class_num(gensym(num->name), (t_newmethod)num->new);
		strcpy(alt + 1, num->name);
		class_addcreator((t_newmethod)num->new, gensym(alt), A_GIMME, 0);
	}


	/* --------------- unops ----------------------------- */

	t_symbol *usyms[] = {
		gensym("negation"), gensym("rounding"), gensym("factorial"), NULL
	}, **usym = usyms;

	const struct _obj uops[] = {
	  { &lnot_class , "!"    , lnot_new  }
	, { &bnot_class , "~"    , bnot_new  }
	, { NULL        , NULL   , NULL      }
	, { &floor_class, "floor", floor_new }
	, { &ceil_class , "ceil" , ceil_new  }
	, { NULL        , NULL   , NULL      }
	, { &fact_class , "n!"   , fact_new  }
	, { NULL        , NULL   , NULL      }
	}, *uop = uops;

	for (; *usym; usym++, uop++) {
		for (; uop->cls; uop++) {
			*uop->cls = class_new(gensym(uop->name)
			, (t_newmethod)uop->new, 0
			, sizeof(t_object), 0
			, 0);
			class_addfloat(*uop->cls, uop_float);
			class_sethelpsymbol(*uop->cls, *usym);
		}
	}


	/* --------------- binops ---------------------------- */

	t_symbol *bsyms[] = { s_blunt, gensym("0x5e"), NULL }, **bsym = bsyms;
	const struct _obj bops[] = {
	  { &b1_plus_class , "+"   , b1_plus_new  }
	, { &b1_minus_class, "-"   , b1_minus_new }
	, { &b1_times_class, "*"   , b1_times_new }
	, { &b1_div_class  , "/"   , b1_div_new   }
	, { &b1_log_class  , "log" , b1_log_new   }
	, { &b1_pow_class  , "pow" , b1_pow_new   }
	, { &b1_max_class  , "max" , b1_max_new   }
	, { &b1_min_class  , "min" , b1_min_new   }
	, { &b2_ee_class   , "=="  , b2_ee_new    }
	, { &b2_ne_class   , "!="  , b2_ne_new    }
	, { &b2_gt_class   , ">"   , b2_gt_new    }
	, { &b2_lt_class   , "<"   , b2_lt_new    }
	, { &b2_ge_class   , ">="  , b2_ge_new    }
	, { &b2_le_class   , "<="  , b2_le_new    }
	, { &b3_ba_class   , "&"   , b3_ba_new    }
	, { &b3_la_class   , "&&"  , b3_la_new    }
	, { &b3_bo_class   , "|"   , b3_bo_new    }
	, { &b3_lo_class   , "||"  , b3_lo_new    }
	, { &b3_ls_class   , "<<"  , b3_ls_new    }
	, { &b3_rs_class   , ">>"  , b3_rs_new    }
	, { &b3_pc_class   , "%"   , b3_pc_new    }
	, { &b3_fpc_class  , "f%"  , b3_fpc_new   }
	, { &b3_mod_class  , "mod" , b3_mod_new   }
	, { &b3_fmod_class , "fmod", b3_fmod_new  }
	, { &b3_div_class  , "div" , b3_div_new   }
	, { NULL           , NULL  , NULL         }
	, { &b3_xor_class  , "^"   , b3_xor_new   }
	, { NULL           , NULL  , NULL         }
	}, *bop = bops;

	for (; *bsym; bsym++, bop++) {
		for (; bop->cls; bop++) {
			*bop->cls = class_bop(gensym(bop->name), (t_newmethod)bop->new);
			strcpy(alt + 1, bop->name);
			class_addcreator((t_newmethod)bop->new, gensym(alt), A_GIMME, 0);
			class_sethelpsymbol(*bop->cls, *bsym);
		}
	}

	/* hot & reverse binops */
	hotop_setup();
	revop_setup();
	bng_setup();
	sym_setup();
}
