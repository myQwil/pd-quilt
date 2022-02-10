#include "m_pd.h"

static const int max = 0x400;

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	t_float *i_floatslot;
};

typedef struct {
	t_float *fp;  /* array pointer */
	unsigned siz; /* array size */
} t_flin;

static void flin_alloc(t_flin *x ,int n) {
	// initial size can be anything, but resizing has a cap.
	x->fp = (t_float*)getbytes(n * sizeof(t_float));
	x->siz = n;
}

static void flin_free(t_flin *x) {
	freebytes(x->fp ,x->siz * sizeof(t_float));
}

// return 0 on success, -1 on too large, and -2 on memory shortage
static int flin_resize(t_flin *x ,t_object *obj ,int n) {
	if (n > x->siz)
	{	if (n > max)
			return -1;
		int d = 2 << ilog2(n-1); // smallest power of 2 that can accommodate n
		x->fp = (t_float*)resizebytes(x->fp
			,x->siz * sizeof(t_float) ,d * sizeof(t_float));
		if (!x->fp)
			return -2;
		x->siz = d;
		// re-associate inlets with float slots
		t_float *fp = x->fp;
		t_inlet *ip = obj->ob_inlet;
		for (int i = x->siz; i-- && ip; fp++ ,ip = ip->i_next)
			ip->i_floatslot = fp;  }
	return 0;
}
