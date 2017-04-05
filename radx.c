#include "m_pd.h"

typedef union {
	float f;
	struct { unsigned mant:23,expo:8,sign:1; } u;
} ufloat;

/* -------------------------- radx -------------------------- */

static t_class *radx_class;

typedef struct _radx {
	t_object x_obj;
	t_float x_radx;
} t_radx;

#define max 64
#define len 8

static void radx_float(t_radx *x, t_float f) {
	char digit[max] = "0123456789abcdef"
					  "ghijkmnopqrstuvw"
					  "xyzACDEFGHJKLMNP"
					  "QRSTUVWXYZ?!@#$%";
					 
	int radx = x->x_radx,
		neg = (f<0),
		i=0, dp,
		res[len];
	
	if (radx<2) radx=2; else if (radx>max) radx=max;
	if (neg) f=-f;
	
	unsigned d=f;
	do{ res[i++%len] = d%radx; d/=radx; }
	while (d>0);
	dp=i; // decimal point
	
	int flot = (f != (d=f));
	if (flot && dp<len-1)
	{	t_float b;
		do{ f = (f-d)*radx;
			d=f, b=f-d; d+=(b-.99>0);
			if (d==0 && b<.05) f=0;
			else res[i++] = d; }
		while (f!=0 && i<len);   }
	
	int size = (i>len?len:i)+flot+neg,
		dlen = (dp>len?len:dp)+neg,
		j=0;
	char buf[size+1];
	if (neg) buf[j++] = '-';
	for (i=dp-1; j<dlen; j++, i--)
		buf[j] = digit[res[i%len]];
	if (flot)
	{	buf[j++] = '.';
		for (; j<size; j++)
			buf[j] = digit[res[j-flot-neg]];   }
	
	buf[size] = '\0';
	outlet_symbol(x->x_obj.ob_outlet, gensym(buf));
}

static void *radx_new(t_floatarg f) {
	t_radx *x = (t_radx *)pd_new(radx_class);
	x->x_radx = f?f:16;
	floatinlet_new(&x->x_obj, &x->x_radx);
	outlet_new(&x->x_obj, &s_symbol);
	return (x);
}

void radx_setup(void) {
	radx_class = class_new(gensym("radx"),
		(t_newmethod)radx_new, 0,
		sizeof(t_radx), 0,
		A_DEFFLOAT, 0);
	
	class_addfloat(radx_class, radx_float);
}
