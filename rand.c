#include "rng.h"
#include "flin.h"
#include <stdlib.h> // atoi
#include <string.h> // memcpy
#include <math.h>   // trunc, floor

static inline double mod(double x ,double y) {
	return x - y * trunc(x / y);
}

/* -------------------------- rand -------------------------- */
static t_class *rand_class;

typedef enum { M_RANGE ,M_LIST } t_mode;

typedef struct {
	t_rng z;
	t_flin flin;
	unsigned siz;  /* list size */
	unsigned nop;  /* no-repeat toggle & max */
	unsigned reps; /* repeat count */
	unsigned prev; /* previous index */
	t_mode mode;   /* toggle for range or list behavior */
} t_rand;

static void rand_peek(t_rand *x ,t_symbol *s) {
	t_float *fp = x->flin.fp;
	if (*s->s_name) startpost("%s: " ,s->s_name);
	if (x->mode == M_LIST) for (int n = x->siz; n--; fp++)
	{	startpost("%g" ,*fp);
		if (n) startpost(" | ");  }
	else startpost("%g <=> %g" ,fp[0] ,fp[1]);
	endpost();
}

static void rand_ptr(t_rand *x ,t_symbol *s) {
	post("%s%s%d" ,s->s_name ,*s->s_name?": ":"" ,x->flin.siz);
}

static void rand_nop(t_rand *x ,t_float f) {
	x->nop = f;
}

static void rand_mode(t_rand *x ,t_float f) {
	x->mode = f;
}

static void rand_size(t_rand *x ,t_float f) {
	switch (flin_resize(&x->flin ,&x->z.obj ,f))
	{	case -2: x->siz = 0;
		case -1: break;
		default: x->siz = f;  }
}

static void rand_bang(t_rand *x) {
	int neg;
	double min ,range;
	t_mode mode = x->mode;
	t_float *fp = x->flin.fp;

	if (mode == M_LIST)
		range = x->siz;
	else // mode = M_RANGE
	{	min = fp[1];
		range = fp[0] - min;
		neg = (range < 0 ? -1 : 1); // make range an absolute value
		range *= neg;  }

	double d ,next = rng_next(&x->z);
	unsigned nop=x->nop ,reps=x->reps ,prev=x->prev;
	if (nop && reps >= nop)
	     d = mod(next * (range-1) + (prev+1) ,range ? range : 1);
	else d = next * range;

	int i = d;
	x->reps = (i == prev ? reps+1 : 1);
	x->prev = i;

	outlet_float(x->z.obj.ob_outlet ,mode == M_LIST ? fp[i] : floor(d * neg + min));
}

static int rand_z(t_rand *x ,int i ,int ac ,t_atom *av) {
	if (i < 0)
	{	i %= x->siz;
		if (i < 0) i += x->siz;  }
	int n = i + ac;
	switch (flin_resize(&x->flin ,&x->z.obj ,n))
	{	case -2: n = 0; break;
		case -1: n = x->siz;  }
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
	switch (*s->s_name)
	{	case '#': rand_z(x ,atoi(s->s_name+1) ,ac ,av);          break;
		case '@': x->siz = rand_z(x ,atoi(s->s_name+1) ,ac ,av); break;
		default:
		{	t_atom atoms[ac+1];
			atoms[0] = (t_atom){.a_type=A_SYMBOL ,.a_w={.w_symbol = s}};
			memcpy(atoms+1 ,av ,ac * sizeof(t_atom));
			x->siz = rand_z(x ,0 ,ac+1 ,atoms);  }  }
}

static void *rand_new(t_symbol *s ,int ac ,t_atom *av) {
	t_rand *y = (t_rand*)pd_new(rand_class);
	t_rng *x = &y->z;
	outlet_new(&x->obj ,&s_float);
	int c = !ac ? 2 : ac;
	y->mode = c > 2 ? M_LIST : M_RANGE;

	// 3 args with a symbol in the middle creates a small list (ex: 7 or 9)
	if (ac==3 && av[1].a_type != A_FLOAT)
	{	av[1] = av[2];
		c = 2;  }
	y->siz = c;

	// always have a pointer size of at least 2 numbers for min and max
	flin_alloc(&y->flin ,c<2 ? 2 : c);
	t_float *fp = y->flin.fp;
	for (;c--; av++ ,fp++)
	{	floatinlet_new(&x->obj ,fp);
		*fp = atom_getfloat(av);  }
	y->nop = y->reps = y->prev = 0;
	rng_makeseed(x);
	return (y);
}

static void rand_free(t_rand *x) {
	flin_free(&x->flin);
}

void rand_setup(void) {
	seed = 1489853723;
	rand_class = class_new(gensym("rand")
		,(t_newmethod)rand_new ,(t_method)rand_free
		,sizeof(t_rand) ,0
		,A_GIMME ,0);
	class_addbang    (rand_class ,rand_bang);
	class_addlist    (rand_class ,rand_list);
	class_addanything(rand_class ,rand_anything);

	class_addrng(rand_class);
	class_addmethod(rand_class ,(t_method)rand_peek ,gensym("peek")  ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_ptr  ,gensym("ptr")   ,A_DEFSYM ,0);
	class_addmethod(rand_class ,(t_method)rand_nop  ,gensym("nop")   ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_mode ,gensym("mode")  ,A_FLOAT  ,0);
	class_addmethod(rand_class ,(t_method)rand_size ,gensym("size")  ,A_FLOAT  ,0);
}
