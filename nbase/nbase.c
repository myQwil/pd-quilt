#include "../m_pd.h"

/* -------------------------- nbase -------------------------- */

static t_class *nbase_class;

typedef struct _nbase {
	t_object x_obj;
	t_float x_base;
} t_nbase;

static void nbase_float(t_nbase *x, t_float f) {
	char digit[32] = "0123456789NECDAFGHJKMPQRSTUVWXYZ";
	int len = 8;
	int newd[len], newf[len];
	
	int size=0, i=0, j, dp, flot, d=f, base=x->x_base;
	if (base<1||base>32) base = 16;
	
	do
	{	newd[i] = (d<0?-1:1)*(d%base);
		d/=base; i++;   }
	while (d!=0 && i<len);
	size+=(dp=i); // decimal point
	
	d=f;
	if ((flot=(f!=d)))
	{	t_float b; j=len-dp; i=0;
		do
		{	f-=d; f*=(f<0?-1:1)*base;
			d=f; b=f-d; d+=(b-.999>=0);
			if (b>-.005 && b<.005 && d==0) f=0;
			else newf[i++] = d;   }
		while (f!=0 && i<j);
		size+=i;   }
	char buf[size+1+flot];
	for (j=0, i=dp-1; j<dp; j++, i--)
		buf[j] = digit[newd[i]];
	
	if (flot)
	{	buf[j++] = '.';
		for (i=0; j<size+flot; j++, i++)
			buf[j] = digit[newf[i]];   }
	
	buf[size+flot] = '\0';
	outlet_symbol(x->x_obj.ob_outlet, gensym(buf));
}

static void *nbase_new(t_floatarg f) {
	t_nbase *x = (t_nbase *)pd_new(nbase_class);
	x->x_base = f;
	floatinlet_new(&x->x_obj, &x->x_base);
	outlet_new(&x->x_obj, &s_symbol);
	return (x);
}

void nbase_setup(void) {
	nbase_class = class_new(gensym("nbase"),
		(t_newmethod)nbase_new, 0,
		sizeof(t_nbase), 0,
		A_DEFFLOAT, 0);
	
	class_addfloat(nbase_class, nbase_float);
}
