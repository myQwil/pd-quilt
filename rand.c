#include "flin.h"
#include <time.h>
#include <stdlib.h> // strtof
#include <string.h> // memcpy

/* -------------------------- rand -------------------------- */
static t_class *rand_class;

typedef struct {
	t_object obj;
	t_flin flin;
	t_float prev;     /* previous random number */
	int repc;         /* repeat count */
	int repmax;       /* repeat max */
	uint16_t siz;     /* list size */
	uint16_t argc;    /* arg count */
	unsigned state;   /* random state */
	unsigned swap;    /* no-repeat state */
	unsigned norep:1; /* no-repeat toggle */
} t_rand;

static unsigned rand_time(void) {
	unsigned thym = (time(0) * 2) % 0x100000000;
	return (thym|1); // odd numbers only
}

static unsigned rand_makeseed(void) {
	static unsigned rand_next = 1489853723;
	rand_next = rand_next * rand_time() + 938284287;
	return rand_next;
}

static void rand_seed(t_rand *x ,t_symbol *s ,int ac ,t_atom *av) {
	x->state = x->swap = ac ? (unsigned)atom_getfloat(av) : rand_time();
}

static void rand_state(t_rand *x ,t_symbol *s) {
	startpost("%s%s%u" ,s->s_name ,*s->s_name?": ":"" ,x->state);
	if (x->norep) startpost(" %u" ,x->swap);
	endpost();
}

static void rand_ptr(t_rand *x ,t_symbol *s) {
	post("%s%s%d" ,s->s_name ,*s->s_name?": ":"" ,x->flin.siz);
}

static void rand_peek(t_rand *x ,t_symbol *s) {
	int c=x->argc;
	t_float *fp = x->flin.fp;
	if (*s->s_name) startpost("%s: " ,s->s_name);
	if (c<3) startpost("%g <=> %g" ,fp[0] ,fp[1]);
	else for (int n=x->siz; n--; fp++)
	{	startpost("%g" ,*fp);
		if (n) startpost(" | ");   }
	endpost();
}

static void rand_size(t_rand *x ,t_floatarg f) {
	int res = flin_resize(&x->flin ,&x->obj ,f);
	switch(res)
	{	case -2: x->siz = 1;
		case -1: break;
		default: x->siz = f;   }
}

static void rand_count(t_rand *x ,t_floatarg f) {
	x->argc = f;
}

static void rand_nop(t_rand *x ,t_floatarg f) {
	x->norep = f;
}

static void rand_max(t_rand *x ,t_floatarg f) {
	x->repmax = f;
}

static double rand_next(t_rand *x ,double range ,int swap) {
	unsigned *sp = swap ? &x->swap : &x->state;
	*sp = *sp * 472940017 + 832416023;
	return *sp * range / 0x100000000;
}

static t_float rand_swap(t_rand *x ,int i ,int range ,int min) {
	int rc = x->repc ,rmax = x->repmax;
	if (i == x->prev) // same as previous value
	{	if (rc >= rmax) // count reached max
		{	rc=1;
			if (range < 0)
			{	min += range;
				range *= -1;   }
			i += 1 + rand_next(x ,range-1 ,1) - min;
			i = i % (range ? range : 1) + min;   }
		else rc++;   }
	else rc = 1;

	x->repc = rc;
	x->prev = i;
	return i;
}

static void rand_bang(t_rand *x) {
	t_float *fp = x->flin.fp;
	int c = x->argc;
	int i;
	if (c<3) // range method
	{	double min=fp[1] ,rng=fp[0]-min;
		double d = rand_next(x ,rng ,0) + min;
		i = d - (d<0); // floor negative values
		if (x->norep) i = rand_swap(x ,i ,rng ,min);
		outlet_float(x->obj.ob_outlet ,i);   }
	else     // list method
	{	c = x->siz;
		i = rand_next(x ,c ,0);
		if (x->norep) i = rand_swap(x ,i ,c ,0);
		outlet_float(x->obj.ob_outlet ,fp[i]);   }
}

static void rand_float(t_rand *x ,t_float f) {
	t_float *fp = x->flin.fp;
	int c = x->argc;
	if (c<3) // range method
	{	double min=fp[1] ,rng=fp[0]-min;
		f = rand_swap(x ,f ,rng ,min);
		outlet_float(x->obj.ob_outlet ,f);   }
	else     // list method
	{	int i = f;
		c = x->siz;
		i = rand_swap(x ,i ,c ,0);
		outlet_float(x->obj.ob_outlet ,fp[i]);   }
}

static int rand_z(t_rand *x ,int i ,int ac ,t_atom *av) {
	if (i < 0)
	{	i %= x->siz;
		if (i < 0) i += x->siz;   }
	int n = flin_resize(&x->flin ,&x->obj ,i+ac);
	if (n < 0) // resize error
	{	n = (n == -2) ? 1 : x->siz;
		return n;   }
	t_float *fp = x->flin.fp + i;
	for (;ac--; av++ ,fp++)
		if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
	return n;
}

static void rand_list(t_rand *x ,t_symbol *s ,int ac ,t_atom *av) {
	x->siz = rand_z(x ,0 ,ac ,av);
}

static void rand_anything(t_rand *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (!ac) return;
	if (*s->s_name == '#')
		rand_z(x ,atoi(s->s_name+1) ,ac ,av);
	else
	{	t_atom atoms[ac+1];
		atoms[0] = (t_atom){A_SYMBOL ,{.w_symbol = s}};
		memcpy(atoms+1 ,av ,ac * sizeof(t_atom));
		rand_z(x ,0 ,ac+1 ,atoms);   }
}

static void *rand_new(t_symbol *s ,int ac ,t_atom *av) {
	t_rand *x = (t_rand *)pd_new(rand_class);
	outlet_new(&x->obj ,&s_float);
	int c = x->argc = !ac ? 2 : ac;

	// 3 args with a string in the middle creates a small list (ex: 7 or 9)
	if (ac==3 && av[1].a_type != A_FLOAT)
	{	av[1] = av[2];
		c = 2;   }
	x->siz = x->flin.ins = c;

	// always have a pointer size of at least 2 numbers for min and max
	flin_alloc(&x->flin ,c<2 ? 2 : c);
	t_float *fp = x->flin.fp;
	for (;c--; av++ ,fp++)
	{	floatinlet_new(&x->obj ,fp);
		*fp = atom_getfloat(av);   }
	x->state = x->swap = rand_makeseed();
	return (x);
}

static void rand_free(t_rand *x) {
	freebytes(x->flin.fp ,x->flin.siz * sizeof(t_float));
}

void rand_setup(void) {
	rand_class = class_new(gensym("rand")
		,(t_newmethod)rand_new ,(t_method)rand_free
		,sizeof(t_rand) ,0
		,A_GIMME ,0);
	class_addbang    (rand_class ,rand_bang);
	class_addfloat   (rand_class ,rand_float);
	class_addlist    (rand_class ,rand_list);
	class_addanything(rand_class ,rand_anything);

	class_addmethod(rand_class ,(t_method)rand_seed
		,gensym("seed")  ,A_GIMME  ,0);
	class_addmethod(rand_class ,(t_method)rand_state
		,gensym("state") ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_ptr
		,gensym("ptr")   ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_peek
		,gensym("peek")  ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_size
		,gensym("n")     ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_count
		,gensym("c")     ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_nop
		,gensym("nop")   ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_max
		,gensym("max")   ,A_FLOAT  ,0);
}
