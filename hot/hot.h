#include "m_pd.h"
#include <string.h>
#include <stdlib.h>

#ifdef _MSC_VER
#define strtof(a,b) _atoldbl(a,*b)
#endif

/* -------------------------- hot binops -------------------------- */

typedef struct _hot t_hot;
typedef void (*t_hotmethod)(t_hot *x);

struct _hot {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
	t_pd *x_proxy;
	t_hotmethod x_bang;
	int x_lb;
};

typedef struct _hot_proxy {
	t_object p_obj;
	t_hot *p_x;
} t_hot_proxy;

static void hot_float(t_hot *x, t_float f) {
	x->x_f1 = f;
	x->x_bang(x);
}

static void hot_proxy_bang(t_hot_proxy *p) {
	t_hot *x = p->p_x;
	x->x_bang(x);
}

static void hot_proxy_float(t_hot_proxy *p, t_float f) {
	t_hot *x = p->p_x;
	x->x_f2 = f;
	x->x_bang(x);
}

static void hot_loadbang(t_hot *x, t_floatarg action) {
	if (!action && x->x_lb) x->x_bang(x);
}

static void *hot_new
(t_class *fltclass, t_class *pxyclass,
 t_hotmethod fn, t_symbol *s, int ac, t_atom *av) {
	t_hot *x = (t_hot *)pd_new(fltclass);
	t_pd *proxy = pd_new(pxyclass);
	x->x_proxy = proxy;
	((t_hot_proxy *)proxy)->p_x = x;
	outlet_new(&x->x_obj, &s_float);
	inlet_new(&x->x_obj, proxy, 0, 0);
	x->x_bang = fn;

	if (ac>1 && av->a_type == A_FLOAT)
	{	x->x_f1 = av->a_w.w_float;
		av++;   }
	else x->x_f1 = 0;

	if (ac)
	{	if (av->a_type == A_FLOAT)
			x->x_f2 = av->a_w.w_float;
		else if (av->a_type == A_SYMBOL)
		{	const char *c = av->a_w.w_symbol->s_name;
			if (c[strlen(c)-1] != '!') return 0;
			x->x_f2 = strtof(c, NULL);
			x->x_lb = 1;   }   }

	return (x);
}

static void hot_free(t_hot *x) {
	pd_free(x->x_proxy);
}
