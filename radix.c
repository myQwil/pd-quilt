#include "m_pd.h"

/* -------------------------- radix -------------------------- */

static t_class *radix_class;

typedef struct _radix {
	t_object x_obj;
	t_float x_rad;
} t_radix;

static void radix_float(t_radix *x, t_float f) {
	t_float b;
	char digit[32] = "0123456789NECDAFGHJKLMPQRTUVWXYZ";
	int len=8, new[len],
		i=0, j=0, dp, size, flot=0,
		d=f, rad=x->x_rad, neg=(f<0);
	if (rad<2) rad=2; else if (rad>32) rad=32;

	do{ new[i++%len] = (d<0?-1:1)*(d%rad); d/=rad; }
	while (d!=0);
	dp=i; // decimal point
	
	if (dp<len-1 && (flot=(f!=(d=f))))
	{	do{ f-=d; f*=(f<0?-1:1)*rad;
			d=f, b=f-d; d+=(b-.999>=0);
			if (b>-.001 && b<.001 && d==0) f=0;
			else new[i++] = d; }
		while (f!=0 && i<len);   }
	
	size=(i>len?len:i)+flot+neg;
	char buf[size+1];
	if (neg) buf[j++] = '-';
	for (i=dp-1; j<(dp>len?len:dp)+neg; j++, i--)
		buf[j] = digit[new[i%len]];
	if (flot)
	{	buf[j++] = '.';
		for (; j<size; j++)
			buf[j] = digit[new[j-flot-neg]];   }
	
	buf[size] = '\0';
	outlet_symbol(x->x_obj.ob_outlet, gensym(buf));
}

static void *radix_new(t_floatarg f) {
	t_radix *x = (t_radix *)pd_new(radix_class);
	x->x_rad = f?f:16;
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
