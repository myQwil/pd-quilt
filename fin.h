#include "m_pd.h"

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	t_float *i_floatslot;
};

typedef struct _fin {
	t_object x_obj;
	t_float *x_fp;  /* number list */
	int x_in;       /* number of inlets */
	int x_p;        /* pointer size */
} t_fin;

#define fin x->x_fin
#define NMAX 1024

static int fin_resize(t_fin *x, int n, int isindex) {
	n += isindex;
	if      (n < 1)    n = 1;
	else if (n > NMAX) n = NMAX;
	if (x->x_p < n)
	{	int d = 2;
		while (d < n) d *= 2;
		x->x_fp = (t_float *)resizebytes(x->x_fp,
			x->x_p * sizeof(t_float), d * sizeof(t_float));
		x->x_p = d;
		t_float *fp = x->x_fp;
		t_inlet *ip = ((t_object *)x)->ob_inlet;
		for (int i=x->x_in; i--; fp++, ip=ip->i_next)
			ip->i_floatslot = fp;   }
	return (n - isindex);
}

static void fin_free(t_fin *x) {
	freebytes(x->x_fp, x->x_p * sizeof(t_float));
}
