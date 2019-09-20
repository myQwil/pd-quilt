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
	t_float *x_fp;      /* number list */
	t_float x_prv;      /* previous random number */
	int x_n;            /* list size */
	int x_c;            /* arg count */
	int x_in;           /* number of inlets */
	int x_p;            /* pointer size */
	int x_rc;           /* repeat count */
	int x_rx;           /* repeat max */
	int x_nop;          /* no-repeat toggle */
	unsigned x_state;   /* random state */
	unsigned x_swap;    /* no-repeat state */
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
	x->x_state = x->x_swap = (ac ? atom_getfloat(av) : rand_time());
}

static void rand_state(t_rand *x, t_symbol *s) {
	startpost("%s%s%u", s->s_name, *s->s_name?": ":"", x->x_state);
	if (x->x_nop) startpost(" %u", x->x_swap);
	endpost();
}

static void rand_ptr(t_rand *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name?": ":"", x->x_p);
}

static void rand_peek(t_rand *x, t_symbol *s) {
	int i, c=x->x_c, n=x->x_n;
	t_float *fp = x->x_fp;
	if (*s->s_name) startpost("%s: ", s->s_name);
	if (c<3) startpost("%g <-> %g", fp[0], fp[1]);
	else for (; n--; fp++)
	{	startpost("%g", *fp);
		if (n) startpost(" | ");   }
	endpost();
}

static int rand_resize(t_rand *x, int n, int l) {
	n += l;
	if (n<1) n=1; else if (n>MAX) n=MAX;
	if (x->x_p<n)
	{	int d=2, i;
		while (d<MAX && d<n) d*=2;
		x->x_fp = (t_float *)resizebytes(x->x_fp,
			x->x_p * sizeof(t_float), d * sizeof(t_float));
		x->x_p = d;
		t_float *fp = x->x_fp;
		t_inlet *ip = ((t_object *)x)->ob_inlet;
		for (i=x->x_in; i--; fp++, ip=ip->i_next)
			ip->i_floatslot = fp;   }
	return (n-l);
}

static void rand_at(t_rand *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = rand_resize(x, av->a_w.w_float, 1);
		if ((av+1)->a_type == A_FLOAT)
			x->x_fp[i] = (av+1)->a_w.w_float;   }
	else pd_error(x, "rand_at: bad arguments");
}

static void rand_size(t_rand *x, t_floatarg n) {
	x->x_n = rand_resize(x, n, 0);
}

static void rand_count(t_rand *x, t_floatarg f) {
	x->x_c = f;
}

static void rand_nop(t_rand *x, t_floatarg f) {
	x->x_nop = f;
}

static void rand_max(t_rand *x, t_floatarg f) {
	x->x_rx = f;
}

double nextr(t_rand *x, double range, int swap) {
	unsigned *sp = (swap ? &x->x_swap : &x->x_state), state=*sp;
	*sp = state = state * 472940017 + 832416023;
	return (1./4294967296) * range * state;
}

static t_float swapr(t_rand *x, int i, int rng, int min) {
	int rc=x->x_rc, rx=x->x_rx;
	if (i==x->x_prv) // same as previous value
	{	if (rc>=rx) // count reached max
		{	rc=1;
			if (rng<0) min += rng, rng *= -1;
			i += 1 + nextr(x, rng-1, 1) - min;
			i = i % rng + min;   }
		else rc++;   }
	else rc = 1;

	x->x_rc = rc;
	x->x_prv = i;
	return i;
}

static void rand_bang(t_rand *x) {
	t_float *fp = x->x_fp;
	int c = x->x_c;
	int i;
	if (c<3) // range method
	{	double min=fp[1], rng=fp[0]-min;
		double d = nextr(x, rng, 0) + min;
		i = d - (d<0); // floor negative values
		if (x->x_nop) i = swapr(x, i, rng, min);
		outlet_float(x->x_obj.ob_outlet, i);   }
	else     // list method
	{	c = x->x_n;
		i = nextr(x, c, 0);
		if (x->x_nop) i = swapr(x, i, c, 0);
		outlet_float(x->x_obj.ob_outlet, fp[i]);   }
}

static void rand_float(t_rand *x, t_float f) {
	t_float *fp = x->x_fp;
	int c = x->x_c;
	if (c<3) // range method
	{	int max=fp[0], min=fp[1], rng=max-min;
		f = swapr(x, f, rng, min);
		outlet_float(x->x_obj.ob_outlet, f);   }
	else     // list method
	{	int i = f;
		c = x->x_n;
		i = swapr(x, i, c, 0);
		outlet_float(x->x_obj.ob_outlet, fp[i]);   }
}

static void rand_list(t_rand *x, t_symbol *s, int ac, t_atom *av) {
	x->x_n = ac = rand_resize(x, ac, 0);
	t_float *fp = x->x_fp;
	for (; ac--; av++, fp++)
		if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
}

static void *rand_new(t_symbol *s, int ac, t_atom *av) {
	t_rand *x = (t_rand *)pd_new(rand_class);
	outlet_new(&x->x_obj, &s_float);
	
	int c = x->x_c = !ac ? 2 : ac;
	// 3 args with a string in the middle creates a small list (ex: 7 or 9)
	if (ac==3 && av[1].a_type != A_FLOAT)
		c = 2, av[1] = av[2];
	x->x_n = x->x_in = c;

	// always have a pointer size of at least 2 numbers for min and max
	x->x_p = c<2 ? 2 : c;

	x->x_fp = (t_float *)getbytes(x->x_p * sizeof(t_float));
	t_float *fp = x->x_fp;
	for (; c--; av++, fp++)
	{	floatinlet_new(&x->x_obj, fp);
		*fp = atom_getfloat(av);   }
	x->x_state = x->x_swap = rand_makeseed();
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
	class_addlist(rand_class, rand_list);
	class_addmethod(rand_class, (t_method)rand_seed,
		gensym("seed"), A_GIMME, 0);
	class_addmethod(rand_class, (t_method)rand_state,
		gensym("state"), A_DEFSYM, 0);
	class_addmethod(rand_class, (t_method)rand_ptr,
		gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(rand_class, (t_method)rand_peek,
		gensym("peek"), A_DEFSYM, 0);
	class_addmethod(rand_class, (t_method)rand_at,
		gensym("@"), A_GIMME, 0);
	class_addmethod(rand_class, (t_method)rand_size,
		gensym("n"), A_FLOAT, 0);
	class_addmethod(rand_class, (t_method)rand_count,
		gensym("c"), A_FLOAT, 0);
	class_addmethod(rand_class, (t_method)rand_nop,
		gensym("nop"), A_FLOAT, 0);
	class_addmethod(rand_class, (t_method)rand_max,
		gensym("max"), A_FLOAT, 0);
}
