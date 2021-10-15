/* musl as a whole is licensed under the following standard MIT license:

----------------------------------------------------------------------
Copyright © 2005-2014 Rich Felker, et al.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
----------------------------------------------------------------------
*/

#include <stdlib.h> // atof
#include <limits.h> // ULONG_MAX
#include <string.h>
#include <float.h>
#include <math.h>

#include "ufloat.h"
#include "g_canvas.h"
#include "g_all_guis.h"

#define FLT_EXP_DIG 8
#define DBL_EXP_DIG 11

#if PD_FLOATSIZE == 32
#define BUFSIZE FLT_MANT_DIG + FLT_EXP_DIG + 5 // 5 = -.^±\0
#elif PD_FLOATSIZE == 64
#define BUFSIZE DBL_MANT_DIG + DBL_EXP_DIG + 5
#endif

#define MINDIGITS 0
#define MINFONT   4

#define MAX(a,b) ((a)>(b) ? (a):(b))
#define MIN(a,b) ((a)<(b) ? (a):(b))

#define LEAD 2

#undef PD_COLOR_FG
#undef PD_COLOR_BG
#undef PD_COLOR_SELECT
#undef PD_COLOR_EDIT

// dark theme
#define PD_COLOR_FG           0xFCFCFC
#define PD_COLOR_BG           0xBBBBBB
#define PD_COLOR_SELECT       0x00FFFF
#define PD_COLOR_EDIT         0xFF9999

// regular theme
// #define PD_COLOR_FG           0x000000
// #define PD_COLOR_BG           0x444444
// #define PD_COLOR_SELECT       0x0000FF
// #define PD_COLOR_EDIT         0xFF0000

typedef struct {
	t_iemgui x_gui;
	t_clock  *x_clock_reset;
	t_clock  *x_clock_wait;
	double   x_val;
	double   x_tog;
	double   x_min;
	double   x_max;
	double   x_k;
	char     x_buf[BUFSIZE];
	int      x_buflen;
	int      x_numwidth;
	int      x_log_height;
	int      x_base;     // radix
	int      x_prec;     // precision
	int      x_e;        // e-notation radix
	int      x_bexp;     // base exponent
	int      x_texp;     // power of 2 exponent
	unsigned x_pwr;      // largest base power inside of 32 bits
	unsigned x_resize:1; // 1 if the border width needs to be resized
	unsigned x_lilo:1;   // 0 for lin, 1 for log
} t_radix;

#ifndef PDL2ORK
#define x_change x_fsf.x_change
#endif

static const char dgt[] = {
	"0123456789abcdef"
	"ghijkmnopqrstuvw"
	"xyzACDEFGHJKLMNP"
	"QRTUVWXYZ?!@#$%&"
};

/*------------------ global functions -------------------------*/

static void radix_key(void *z ,t_float fkey);
static void radix_draw_update(t_gobj *client ,t_glist *glist);

/*------------------ radix functions --------------------------*/

static void radix_tick_wait(t_radix *x) {
	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
}

static void radix_tick_reset(t_radix *x) {
	if (x->x_gui.x_change && x->x_gui.x_glist)
	{	x->x_gui.x_change = 0;
		sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);   }
}

static void radix_clip(t_radix *x) {
	if (x->x_min || x->x_max)
	{	if      (x->x_val < x->x_min) x->x_val = x->x_min;
		else if (x->x_val > x->x_max) x->x_val = x->x_max;   }
}

static void radix_precision(t_radix *x ,t_float f) {
	int m = FLT_MANT_DIG / log2(x->x_base) + 1;
	if      (f < 1) f = 1;
	else if (f > m) f = m;
	x->x_prec = f;
}

static int radix_bounds(t_float base) {
	int m = sizeof(dgt) / sizeof*(dgt);
	if      (base < 2) base = 2;
	else if (base > m) base = m;
	return base;
}

static void radix_dobase(t_radix *x ,t_float f) {
	unsigned base = radix_bounds(f);
	if (base > x->x_base) radix_precision(x ,x->x_prec);
	x->x_base = base;
	unsigned umax = -1 ,pwr = 1;
	int bx = x->x_bexp = log(umax) / log(base) ,tx = 32;
	for (;bx; base *= base)
	{	if (bx & 1) pwr *= base;
		bx >>= 1;   }
	while (umax > pwr) { tx--; umax >>= 1; }
	x->x_pwr = pwr;
	x->x_texp = tx;
}

static void radix_base(t_radix *x ,t_float f) {
	radix_dobase(x ,f);
	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
}

static void radix_ebase(t_radix *x ,t_float base) {
	x->x_e = radix_bounds(base);
	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
}

static void radix_be(t_radix *x ,t_float base) {
	radix_dobase(x ,base);
	x->x_e = x->x_base;
	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
}

static void out(char num[] ,int *i ,const char *s ,int l) {
	for (; l--; s++) num[(*i)++] = *s;
}

static char *fmt_u(uintmax_t u ,char *s ,int radx) {
	unsigned long v;
	for (   ; u>ULONG_MAX; u/=radx) *--s = dgt[u%radx];
	for (v=u;           v; v/=radx) *--s = dgt[v%radx];
	return s;
}

static void radix_ftoa(t_radix *x) {
	ufloat uf = {.f = x->x_val};
	int len=0;
	if (uf.ex == 0xFF)
	{	int neg = uf.sg;
		if (uf.mt != 0) strcpy(x->x_buf ,(neg?"-nan":"nan"));
		else strcpy(x->x_buf ,(neg?"-inf":"inf"));
		len = 3+neg;
		if (x->x_buflen != len) x->x_resize = 1 ,x->x_buflen = len;
		else x->x_resize = 0;
		return;   }

	long double y = x->x_val;
	int radx = x->x_base;
	unsigned pwr = x->x_pwr;
	int bx=x->x_bexp ,tx=x->x_texp;
	int xb=bx-1 ,xt=tx-1;
	int neg=0 ,t='g';

	/* based on: musl-libc /src/stdio/vfprintf.c */
	unsigned size = (LDBL_MANT_DIG+xt)/tx + 1    // mantissa expansion
		+ (LDBL_MAX_EXP+LDBL_MANT_DIG+xt+xb)/bx; // exponent expansion
	uint32_t big[size];
	uint32_t *a ,*d ,*r ,*z;
	int e2=0 ,e ,i ,j ,l;
	char buf[bx+LDBL_MANT_DIG/4];
	char ebuf0[3*sizeof(int)] ,*ebuf=&ebuf0[3*sizeof(int)] ,*estr;

	if (signbit(y)) y=-y ,neg=1;
	int p = (x->x_numwidth && x->x_prec >= x->x_numwidth)
		  ? x->x_numwidth-neg : x->x_prec;

	y = frexpl(y ,&e2) * 2;
	if (y) y *= (1<<xt) ,e2-=tx;

	if (e2<0) a=r=z=big;
	else a=r=z=big+sizeof(big)/sizeof(*big) - LDBL_MANT_DIG - 1;

	do
	{	*z = y;
		y = pwr*(y-*z++);   }
	while (y && --size);

	while (e2>0)
	{	uint32_t carry=0;
		int sh=MIN(tx,e2);
		for (d=z-1; d>=a; d--)
		{	uint64_t u = ((uint64_t)*d<<sh)+carry;
			*d = u % pwr;
			carry = u / pwr;   }
		if (carry) *--a = carry;
		while (z>a && !z[-1]) z--;
		e2-=sh;   }

	while (e2<0)
	{	uint32_t carry=0 ,*b;
		int sh=MIN(bx,-e2) ,need=1+(p+LDBL_MANT_DIG/3U+xb)/bx;
		for (d=a; d<z; d++)
		{	uint32_t rm = *d & ((1<<sh)-1);
			*d = (*d>>sh) + carry;
			carry = (pwr>>sh) * rm;   }
		if (!*a) a++;
		if (carry) *z++ = carry;
		/* Avoid (slow!) computation past requested precision */
		b = a;
		if (z-b > need) z = b+need;
		e2+=sh;   }

	if (a<z) for (i=radx ,e=bx*(r-a); *a>=i; i*=radx ,e++);
	else e=0;

	/* Perform rounding: j is precision after the radix (possibly neg) */
	j = p-e-1;
	if (j < bx*(z-r-1))
	{	uint32_t u;
		/* We avoid C's broken division of negative numbers */
		d = r + 1 + ((j+bx*LDBL_MAX_EXP)/bx - LDBL_MAX_EXP);
		j += bx*LDBL_MAX_EXP;
		j %= bx;
		for (i=radx ,j++; j<bx; i*=radx ,j++);
		u = *d % i;
		/* Are there any significant digits past j? */
		if (u || d+1!=z)
		{	long double round = 2/LDBL_EPSILON;
			long double small;
			if ((*d/i & 1) || (i==pwr && d>a && (d[-1]&1)))
				round += 2;
			if      (u< i/2)           small=0x0.8p0;
			else if (u==i/2 && d+1==z) small=0x1.0p0;
			else                       small=0x1.8p0;
			if (neg) round*=-1 ,small*=-1;
			*d -= u;
			/* Decide whether to round by probing round+small */
			if (round+small != round)
			{	*d = *d + i;
				while (*d > pwr-1)
				{	*d--=0;
					if (d<a) *--a=0;
					(*d)++;   }
				for (i=radx ,e=bx*(r-a); *a>=i; i*=radx ,e++);   }   }
		if (z>d+1) z=d+1;   }

	for (; z>a && !z[-1]; z--);

	if (!p) p++;
	if (p>e && e>=-4)
	{	t--; p-=e+1;   }
	else
	{	t-=2; p--;   }

	/* Count trailing zeros in last place */
	if (z>a && z[-1]) for (i=radx ,j=0; z[-1]%i==0; i*=radx ,j++);
	else j=bx;
	if ((t|32)=='f')
		p = MIN(p,MAX(0,bx*(z-r-1)-j));
	else
		p = MIN(p,MAX(0,bx*(z-r-1)+e-j));

	l = 1 + p + (p>0);
	if ((t|32)=='f')
	{	if (e>0) l+=e;   }
	else
	{	int erad = x->x_e;
		estr=fmt_u(e<0 ? -e : e ,ebuf ,erad);
		while(ebuf-estr<LEAD) *--estr='0';
		*--estr = (e<0 ? '-' : '+');
		*--estr = '^';
		l += ebuf-estr;   }

	char *num = x->x_buf ,*dec=0 ,*nxt=0;
	int ni=0;
	out(num ,&ni ,"-" ,neg);

	if ((t|32)=='f')
	{	if (a>r) a=r;
		for (d=a; d<=r; d++)
		{	char *s = fmt_u(*d ,buf+bx ,radx);
			if (d!=a) while (s>buf) *--s='0';
			else if (s==buf+bx) *--s='0';
			out(num ,&ni ,s ,buf+bx-s);   }
		if (p)
		{	dec = num+ni;
			out(num ,&ni ,"." ,1);   }
		for (; d<z && p>0; d++ ,p-=bx)
		{	char *s = fmt_u(*d ,buf+bx ,radx);
			while (s>buf) *--s='0';
			out(num ,&ni ,s ,MIN(bx,p));   }   }
	else
	{	if (z<=a) z=a+1;
		for (d=a; d<z && p>=0; d++)
		{	char *s = fmt_u(*d ,buf+bx ,radx);
			if (s==buf+bx) *--s='0';
			if (d!=a) while (s>buf) *--s='0';
			else
			{	out(num ,&ni ,s++ ,1);
				if (p>0)
				{	dec = num+ni;
					out(num ,&ni ,"." ,1);   }   }
			out(num ,&ni ,s ,MIN(buf+bx-s ,p));
			p -= buf+bx-s;   }
		nxt = num+ni;
		out(num ,&ni ,estr ,ebuf-estr);   }
	num[ni] = '\0';
	len = ni;

	// reduce if too big for number box width
	if (x->x_numwidth > 0 && ni > x->x_numwidth)
	{	if (!dec) dec = num+ni;
		if (!nxt) nxt = num+ni;
		int reduce = ni - x->x_numwidth;
		if (nxt-dec >= reduce)
		{	char *s1 = nxt-reduce;
			ebuf = num+ni;
			for (;nxt < ebuf; s1++ ,nxt++) *s1 = *nxt;
			*s1 = '\0';
			len = s1-num;   }
		else
		{	num[0] = (neg?'-':'+');
			num[1] = '\0';   }   }
	if (len < 3) len = 3;
	if (x->x_buflen != len) x->x_resize = 1 ,x->x_buflen = len;
	else x->x_resize = 0;
}

static int radix_check_minmax(t_radix *x ,double min ,double max) {
	int ret = 0;
	double fine = 1. / (x->x_base * x->x_base);
	if (x->x_lilo)
	{	if (min==0. && max==0.) max = 1.;
		if (max > 0.)
		{	if (min <= 0.) min = fine * max;   }
		else
		{	if (min >  0.) max = fine * min;   }   }
	x->x_min = min;
	x->x_max = max;
	if (!x->x_lilo && min==0. && max==0.)
		return (ret);
	if (x->x_val < x->x_min)
	{	x->x_val = x->x_min;
		ret = 1;   }
	else
	if (x->x_val > x->x_max)
	{	x->x_val = x->x_max;
		ret = 1;   }
	if (x->x_lilo)
		x->x_k = exp(log(x->x_max/x->x_min) / x->x_log_height);
	else x->x_k = 1.;
	return(ret);
}

static void radix_set(t_radix *x ,t_float f) {
	ufloat uf = {.f = f} ,vf = {.f = x->x_val};
	if (uf.u != vf.u)
	{	x->x_val = f;
		radix_clip(x);
		sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);   }
}

static void radix_log_height(t_radix *x ,t_float lh) {
	if (lh < 10.) lh = 10.;
	x->x_log_height = lh;
	if (x->x_lilo)
		x->x_k = exp(log(x->x_max/x->x_min) / x->x_log_height);
	else x->x_k = 1.;
}

static void radix_log(t_radix *x) {
	x->x_lilo = 1;
	if (radix_check_minmax(x ,x->x_min ,x->x_max))
	{	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
		/*radix_bang(x);*/   }
}

static void radix_lin(t_radix *x) {
	x->x_lilo = 0;
}

static void radix_list(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (!ac) pd_bang((t_pd *)x);
	else if (IS_A_FLOAT(av ,0))
	{	radix_set(x ,atom_getfloatarg(0 ,ac ,av));
		pd_bang((t_pd *)x);   }
}
