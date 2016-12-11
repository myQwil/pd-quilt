#include "../m_pd.h"

/* -------------------------- radix -------------------------- */

static t_class *radix_class;

typedef struct _radix {
	t_object x_obj;
	t_float x_rad;
} t_radix;

static void radix_float(t_radix *x, t_float f) {
	char digit[32] = "0123456789NECDAFGHJKMPQRSTUVWXYZ";
	int len = 8;
	int newd[len], newf[len];
	
	int size=0, i=0, j, dp, flot, d=f, rad=x->x_rad;
	if (rad<1||rad>32) rad = 16;
	
	do
	{	newd[i] = (d<0?-1:1)*(d%rad);
		d/=rad; i++;   }
	while (d!=0 && i<len);
	size+=(dp=i); // decimal point
	
	d=f;
	if ((flot=(f!=d)))
	{	t_float b; j=len-dp; i=0;
		do
		{	f-=d; f*=(f<0?-1:1)*rad;
			d=f, b=f-d; d+=(b-.999>=0);
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

static void *radix_new(t_floatarg f) {
	t_radix *x = (t_radix *)pd_new(radix_class);
	x->x_rad = f;
	floatinlet_new(&x->x_obj, &x->x_rad);
	outlet_new(&x->x_obj, &s_symbol);
	return (x);
}

void radix_setup(void) {
	radix_class = class_new(gensym("radix"),
		(t_newmethod)radix_new, 0,
		sizeof(t_radix), 0,
		A_DEFFLOAT, 0);
	
	class_addfloat(radix_class, radix_float);
}