#include "fin.h"
#include <time.h>

/* -------------------------- rand -------------------------- */
static t_class *rand_class;

typedef struct _rand {
	t_fin x_fin;
	t_float x_prev;     /* previous random number */
	int x_n;            /* list size */
	int x_c;            /* arg count */
	int x_repc;         /* repeat count */
	int x_repmax;       /* repeat max */
	unsigned x_state;   /* random state */
	unsigned x_swap;    /* no-repeat state */
	unsigned x_nop:1;   /* no-repeat toggle */
} t_rand;

static unsigned rand_time(void) {
	unsigned thym = time(0) * 2;
	return (thym|1); // odd numbers only
}

static unsigned rand_makeseed(void) {
	static unsigned rand_next = 1489853723;
	rand_next = rand_next * rand_time() + 938284287;
	return rand_next;
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
	post("%s%s%d", s->s_name, *s->s_name?": ":"", fin.x_p);
}

static void rand_peek(t_rand *x, t_symbol *s) {
	int c=x->x_c;
	t_float *fp = fin.x_fp;
	if (*s->s_name) startpost("%s: ", s->s_name);
	if (c<3) startpost("%g <=> %g", fp[0], fp[1]);
	else for (int n=x->x_n; n--; fp++)
	{	startpost("%g", *fp);
		if (n) startpost(" | ");   }
	endpost();
}

static void rand_at(t_rand *x, t_symbol *s, int ac, t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = fin_resize(&fin, av->a_w.w_float, 1);
		if ((av+1)->a_type == A_FLOAT)
			fin.x_fp[i] = (av+1)->a_w.w_float;   }
	else pd_error(x, "rand_at: bad arguments");
}

static void rand_size(t_rand *x, t_floatarg n) {
	x->x_n = fin_resize(&fin, n, 0);
}

static void rand_count(t_rand *x, t_floatarg f) {
	x->x_c = f;
}

static void rand_nop(t_rand *x, t_floatarg f) {
	x->x_nop = f;
}

static void rand_max(t_rand *x, t_floatarg f) {
	x->x_repmax = f;
}

static double rand_next(t_rand *x, double range, int swap) {
	unsigned *sp = swap ? &x->x_swap : &x->x_state;
	*sp = *sp * 472940017 + 832416023;
	return *sp * range / 4294967296;
}

static t_float rand_swap(t_rand *x, int i, int range, int min) {
	int rc = x->x_repc, rmax = x->x_repmax;
	if (i == x->x_prev) // same as previous value
	{	if (rc >= rmax) // count reached max
		{	rc=1;
			if (range < 0)
			{	min += range;
				range *= -1;   }
			i += 1 + rand_next(x, range-1, 1) - min;
			i = i % (range ? range : 1) + min;   }
		else rc++;   }
	else rc = 1;

	x->x_repc = rc;
	x->x_prev = i;
	return i;
}

static void rand_bang(t_rand *x) {
	t_float *fp = fin.x_fp;
	int c = x->x_c;
	int i;
	if (c<3) // range method
	{	double min=fp[1], rng=fp[0]-min;
		double d = rand_next(x, rng, 0) + min;
		i = d - (d<0); // floor negative values
		if (x->x_nop) i = rand_swap(x, i, rng, min);
		outlet_float(fin.x_obj.ob_outlet, i);   }
	else     // list method
	{	c = x->x_n;
		i = rand_next(x, c, 0);
		if (x->x_nop) i = rand_swap(x, i, c, 0);
		outlet_float(fin.x_obj.ob_outlet, fp[i]);   }
}

static void rand_float(t_rand *x, t_float f) {
	t_float *fp = fin.x_fp;
	int c = x->x_c;
	if (c<3) // range method
	{	double min=fp[1], rng=fp[0]-min;
		f = rand_swap(x, f, rng, min);
		outlet_float(fin.x_obj.ob_outlet, f);   }
	else     // list method
	{	int i = f;
		c = x->x_n;
		i = rand_swap(x, i, c, 0);
		outlet_float(fin.x_obj.ob_outlet, fp[i]);   }
}

static void rand_list(t_rand *x, t_symbol *s, int ac, t_atom *av) {
	x->x_n = ac = fin_resize(&fin, ac, 0);
	t_float *fp = fin.x_fp;
	for (;ac--; av++, fp++)
		if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
}

static void *rand_new(t_symbol *s, int ac, t_atom *av) {
	t_rand *x = (t_rand *)pd_new(rand_class);
	outlet_new(&fin.x_obj, &s_float);

	int c = x->x_c = !ac ? 2 : ac;
	// 3 args with a string in the middle creates a small list (ex: 7 or 9)
	if (ac==3 && av[1].a_type != A_FLOAT)
	{	av[1] = av[2];
		c = 2;   }
	x->x_n = fin.x_in = c;

	// always have a pointer size of at least 2 numbers for min and max
	fin.x_p = c<2 ? 2 : c;
	fin.x_fp = (t_float *)getbytes(fin.x_p * sizeof(t_float));
	t_float *fp = fin.x_fp;
	for (;c--; av++, fp++)
	{	floatinlet_new(&fin.x_obj, fp);
		*fp = atom_getfloat(av);   }
	x->x_state = x->x_swap = rand_makeseed();
	return (x);
}

static void rand_free(t_rand *x) {
	freebytes(fin.x_fp, fin.x_p * sizeof(t_float));
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
