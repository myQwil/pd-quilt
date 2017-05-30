#include "m_pd.h"
#include <time.h>

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	t_float *i_floatslot;
};

/* -------------------------- rand -------------------------- */

static t_class *rand_class;

typedef struct _rand {
	t_object x_obj;
	t_float *x_fp, x_pr;	/* previous number */
	int x_c, x_in, x_p,		/* count notes, inlets, pointer */
		x_rc, x_rx,	x_nop;	/* repeat count, max, and toggle */
	unsigned x_state, x_swat;
} t_rand;

#define MAX 1024

static int rand_time(void) {
	int thym = time(0) % 31536000; // seconds in a year
	return (thym|1); // odd numbers only
}

static int rand_makeseed(void) {
	static unsigned rand_next = 1489853723;
	rand_next = rand_next * rand_time() + 938284287;
	return (rand_next & 0x7fffffff);
}

static void rand_seed(t_rand *x, t_symbol *s, int ac, t_atom *av) {
	x->x_state = x->x_swat = (ac ? atom_getfloat(av) : rand_time());
}

static void rand_state(t_rand *x, t_symbol *s) {
	post("%s%s%u %u", s->s_name, *s->s_name?": ":"", x->x_state, x->x_swat);
}

static void rand_ptr(t_rand *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->x_p);
}

static void rand_peek(t_rand *x, t_symbol *s) {
	int i;
	t_float *fp = x->x_fp;
	if (*s->s_name) startpost("%s: ", s->s_name);
	for (i=x->x_c; i--; fp++) startpost("%g ", *fp);
	endpost();
}

static void rand_resize(t_rand *x, int d) {
	int n=2, i;
	while (n<MAX && n<d) n*=2;
	x->x_fp = (t_float *)resizebytes(x->x_fp,
		x->x_p * sizeof(t_float), n * sizeof(t_float));
	x->x_p = n;
	t_float *fp = x->x_fp;
	t_inlet *ip = ((t_object *)x)->ob_inlet;
	for (i=x->x_in; i--; fp++, ip=ip->i_next)
		ip->i_floatslot = fp;
}

int limtr(t_rand *x, int n, int i) {
	i=!i; // index/size toggle
	int mx=MAX+i; n+=i;
	if (n<1) n=1; else if (n>mx) n=mx;
	if (x->x_p<n) rand_resize(x,n);
	return (n-i);
}

static void rand_set(t_rand *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = limtr(x, av->a_w.w_float, 0);
		t_atomtype typ = (av+1)->a_type;
		if (typ == A_FLOAT) x->x_fp[i] = (av+1)->a_w.w_float;   }
	else pd_error(x, "rand_set: bad arguments");
}

static void rand_size(t_rand *x, t_floatarg n) {
	x->x_c = limtr(x,n,1);
}

static void rand_nop(t_rand *x, t_floatarg f) {
	x->x_nop = f;
}

static void rand_max(t_rand *x, t_floatarg f) {
	x->x_rx = f;
}

double nextr(t_rand *x, int n, int swap) {
	unsigned *sp = (swap ? &x->x_swat : &x->x_state), state=*sp;
	*sp = state = state * 472940017 + 832416023;
	return (1./4294967296) * n * state;
}

static void swapr(t_rand *x, int *i, t_float fi, int n, int d, int mn, int b) {
	t_float pr=x->x_pr;
	int rc=x->x_rc, rx=x->x_rx;
	if (fi==pr) // same as previous value
	{	if (rc>=rx) // count reached max
		{	rc=1;
			double f = *i-mn+d+nextr(x,n-d,1);
			*i = (int)f%n + mn+b-(f<0);   }
		else rc++;   }
	else rc=1;
	x->x_rc=rc;
}

static void rand_bang(t_rand *x) {
	int c=x->x_c, i;
	t_float *fp = x->x_fp;
	if (c<3)
	{	int mx=fp[0], mn=fp[1], n=mx-mn, b=n<0, d=b?-1:1;
		if (c>1) n+=d; else n=n?n:1;
		double f = nextr(x,n,0) + mn+b;
		i = f-(f<0);
		if (x->x_nop)
		{	swapr(x,&i,i,n,d,mn,b);
			x->x_pr=i;   }
		outlet_float(x->x_obj.ob_outlet, i);   }
	else
	{	i = nextr(x,c,0);
		if (x->x_nop)
		{	swapr(x,&i,fp[i],c,1,0,0);
			x->x_pr=fp[i];   }
		outlet_float(x->x_obj.ob_outlet, fp[i]);   }
}

static void rand_float(t_rand *x, t_float f) {
	int c=x->x_c, i=f;
	t_float *fp = x->x_fp;
	if (x->x_nop)
	{	if (c<3)
		{	int mx=fp[0], mn=fp[1], n=mx-mn, b=n<0, d=b?-1:1;
			if (c>1) n+=d; else n=n?n:1;
			swapr(x,&i,i,n,d,mn,b);
			x->x_pr=i;
			outlet_float(x->x_obj.ob_outlet, i);   }
		else
		{	swapr(x,&i,fp[i],c,1,0,0);
			x->x_pr=fp[i];   
			outlet_float(x->x_obj.ob_outlet, fp[i]);   }   }
}

static void *rand_new(t_symbol *s, int ac, t_atom *av) {
	t_rand *x = (t_rand *)pd_new(rand_class);
	outlet_new(&x->x_obj, &s_float);
	int n = x->x_c = x->x_in = x->x_p = ac<1?2:ac;
	x->x_fp = (t_float *)getbytes(n * sizeof(t_float));
	t_float *fp = x->x_fp;
	for (; n--; fp++)
	{	floatinlet_new(&x->x_obj, fp);
		*fp = atom_getfloat(av++);   }
	x->x_nop=0, x->x_rx=1,
	x->x_state = x->x_swat = rand_makeseed();
	return (x);
}

static void rand_free(t_rand *x) {
	freebytes(x->x_fp, x->x_p * sizeof(t_float));
}

void rand_setup(void) {
	rand_class = class_new(gensym("rand"),
		(t_newmethod)rand_new, (t_method)rand_free,
		sizeof(t_rand), 0,
		A_GIMME, 0);
	class_addbang(rand_class, rand_bang);
	class_addfloat(rand_class, rand_float);
	class_addmethod(rand_class, (t_method)rand_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(rand_class, (t_method)rand_state,
		gensym("state"), A_DEFSYM, 0);
	class_addmethod(rand_class, (t_method)rand_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(rand_class, (t_method)rand_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(rand_class, (t_method)rand_set,
		gensym("set"), A_GIMME, 0);
	class_addmethod(rand_class, (t_method)rand_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(rand_class, (t_method)rand_nop,
		gensym("nop"), A_FLOAT, 0);
	class_addmethod(rand_class, (t_method)rand_max,
		gensym("max"), A_FLOAT, 0);
}
