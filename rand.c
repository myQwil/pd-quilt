#include "flin.h"
#include <time.h>

/* -------------------------- rand -------------------------- */
static t_class *rand_class;

typedef struct _rand {
	t_flin flin;
	t_float prev;     /* previous random number */
	int siz;          /* list size */
	int argc;         /* arg count */
	int repc;         /* repeat count */
	int repmax;       /* repeat max */
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
	post("%s%s%d" ,s->s_name ,*s->s_name?": ":"" ,x->flin.ptrsiz);
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

static void rand_at(t_rand *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac==2 && av->a_type == A_FLOAT)
	{	int i = flin_resize(&x->flin ,av->a_w.w_float ,1);
		if ((av+1)->a_type == A_FLOAT)
			x->flin.fp[i] = (av+1)->a_w.w_float;   }
	else pd_error(x ,"rand_at: bad arguments");
}

static void rand_size(t_rand *x ,t_floatarg n) {
	x->siz = flin_resize(&x->flin ,n ,0);
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
		outlet_float(x->flin.x_obj.ob_outlet ,i);   }
	else     // list method
	{	c = x->siz;
		i = rand_next(x ,c ,0);
		if (x->norep) i = rand_swap(x ,i ,c ,0);
		outlet_float(x->flin.x_obj.ob_outlet ,fp[i]);   }
}

static void rand_float(t_rand *x ,t_float f) {
	t_float *fp = x->flin.fp;
	int c = x->argc;
	if (c<3) // range method
	{	double min=fp[1] ,rng=fp[0]-min;
		f = rand_swap(x ,f ,rng ,min);
		outlet_float(x->flin.x_obj.ob_outlet ,f);   }
	else     // list method
	{	int i = f;
		c = x->siz;
		i = rand_swap(x ,i ,c ,0);
		outlet_float(x->flin.x_obj.ob_outlet ,fp[i]);   }
}

static void rand_list(t_rand *x ,t_symbol *s ,int ac ,t_atom *av) {
	x->siz = ac = flin_resize(&x->flin ,ac ,0);
	t_float *fp = x->flin.fp;
	for (;ac--; av++ ,fp++)
		if (av->a_type == A_FLOAT) *fp = av->a_w.w_float;
}

static void *rand_new(t_symbol *s ,int ac ,t_atom *av) {
	t_rand *x = (t_rand *)pd_new(rand_class);
	outlet_new(&x->flin.x_obj ,&s_float);

	int c = x->argc = !ac ? 2 : ac;
	// 3 args with a string in the middle creates a small list (ex: 7 or 9)
	if (ac==3 && av[1].a_type != A_FLOAT)
	{	av[1] = av[2];
		c = 2;   }
	x->siz = x->flin.ninlets = c;

	// always have a pointer size of at least 2 numbers for min and max
	x->flin.ptrsiz = c<2 ? 2 : c;
	x->flin.fp = (t_float *)getbytes(x->flin.ptrsiz * sizeof(t_float));
	t_float *fp = x->flin.fp;
	for (;c--; av++ ,fp++)
	{	floatinlet_new(&x->flin.x_obj ,fp);
		*fp = atom_getfloat(av);   }
	x->state = x->swap = rand_makeseed();
	return (x);
}

static void rand_free(t_rand *x) {
	freebytes(x->flin.fp ,x->flin.ptrsiz * sizeof(t_float));
}

void rand_setup(void) {
	rand_class = class_new(gensym("rand")
		,(t_newmethod)rand_new ,(t_method)rand_free
		,sizeof(t_rand) ,0
		,A_GIMME ,0);
	class_addbang (rand_class ,rand_bang);
	class_addfloat(rand_class ,rand_float);
	class_addlist (rand_class ,rand_list);

	class_addmethod(rand_class ,(t_method)rand_seed
		,gensym("seed")  ,A_GIMME  ,0);
	class_addmethod(rand_class ,(t_method)rand_state
		,gensym("state") ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_ptr
		,gensym("ptr")   ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_peek
		,gensym("peek")  ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_at
		,gensym("@")     ,A_GIMME  ,0);
	class_addmethod(rand_class ,(t_method)rand_size
		,gensym("n")     ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_count
		,gensym("c")     ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_nop
		,gensym("nop")   ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_max
		,gensym("max")   ,A_FLOAT  ,0);
}
