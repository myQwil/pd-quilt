#include "m_pd.h"
#include <math.h>
#include <float.h>
#include <limits.h>

typedef union {
	float f;
	struct { unsigned mnt:23,exp:8,sgn:1; } u;
} ufloat;
#define mnt u.mnt
#define exp u.exp
#define sgn u.sgn

#define MAX(a,b) ((a)>(b) ? (a) : (b))
#define MIN(a,b) ((a)<(b) ? (a) : (b))

/* -------------------------- radx -------------------------- */

static t_class *radx_class;

typedef struct _radx {
	t_object x_obj;
	t_float x_radx;
} t_radx;

/* based on: musl-libc /src/stdio/vfprintf.c */

static void out(char *num, int *nl, const char *s, int l) {
	for (; l--; s++) num[(*nl)++] = *s;
}

static const char dgt[64] = {
	"0123456789abcdef"
	"ghijkmnopqrstuvw"
	"xyzACDEFGHJKLMNP"
	"QRTUVWXYZ?!@#%^&"
};

static char *fmt_u(uintmax_t x, char *s, int radx) {
	unsigned y;
	for (   ; x>UINT_MAX; x/=radx) *--s = dgt[x%radx];
	for (y=x;          y; y/=radx) *--s = dgt[y%radx];
	return s;
}

// LDBL_MANT_DIG=64
// LDBL_MAX_EXP=16384
// LDBL_EPSILON=1.0842e-019
static void fmt_fp(t_radx *f, long double y) {
	int radx = f->x_radx;
	if (radx<2) radx=2; else if (radx>64) radx=64;
	
	int up=28, px=9, neg=0, p=6, t='g';
	unsigned big[(LDBL_MANT_DIG+up)/(up+1) + 1		// mantissa expansion
		+ (LDBL_MAX_EXP+LDBL_MANT_DIG+up+8)/px];	// exponent expansion 
	// big[1835]
	unsigned *a, *d, *r, *z;
	int e2=0, e, i, j, l;
	char buf[px+LDBL_MANT_DIG/4]; // buf[25]
	char ebuf0[3*sizeof(int)], *ebuf=&ebuf0[3*sizeof(int)], *estr;
	uint64_t pwr = pow(radx, px);
	
	if (signbit(y)) y=-y, neg=1;
	y = frexpl(y, &e2) * 2;
	if (y) y *= (1<<up), e2-=(up+1);
	
	if (e2<0) a=r=z=big;
	else a=r=z=big+sizeof(big)/sizeof(*big) - LDBL_MANT_DIG - 1;

	do {
		*z = y;
		y = pwr*(y-*z++);
	} while (y);

	while (e2>0) {
		unsigned carry=0;
		int sh=MIN(up+1,e2);
		for (d=z-1; d>=a; d--) {
			uint64_t x = ((uint64_t)*d<<sh)+carry;
			*d = x % pwr;
			carry = x / pwr;
		}
		if (carry) *--a = carry;
		while (z>a && !z[-1]) z--;
		e2-=sh;
	}
	while (e2<0) {
		unsigned carry=0, *b;
		int sh=MIN(px,-e2), need=1+(p+LDBL_MANT_DIG/3U+8)/px;
		for (d=a; d<z; d++) {
			unsigned rm = *d & ((1<<sh)-1);
			*d = (*d>>sh) + carry;
			carry = (pwr>>sh) * rm;
		}
		if (!*a) a++;
		if (carry) *z++ = carry;
		/* Avoid (slow!) computation past requested precision */
		b = a;
		if (z-b > need) z = b+need;
		e2+=sh;
	}

	if (a<z) for (i=radx, e=px*(r-a); *a>=i; i*=radx, e++);
	else e=0;

	/* Perform rounding: j is precision after the radix (possibly neg) */
	j = p-e-1;
	if (j < px*(z-r-1)) {
		unsigned x;
		/* We avoid C's broken division of negative numbers */
		d = r + 1 + ((j+px*LDBL_MAX_EXP)/px - LDBL_MAX_EXP);
		j += px*LDBL_MAX_EXP;
		j %= px;
		for (i=radx, j++; j<px; i*=radx, j++);
		x = *d % i;
		/* Are there any significant digits past j? */
		if (x || d+1!=z) {
			long double round = 2/LDBL_EPSILON;
			long double small;
			if ((*d/i & 1) || (i==pwr && d>a && (d[-1]&1)))
				round += 2;
			if (x<i/2) small=0x0.8p0;
			else if (x==i/2 && d+1==z) small=0x1.0p0;
			else small=0x1.8p0;
			if (neg) round*=-1, small*=-1;
			*d -= x;
			/* Decide whether to round by probing round+small */
			if (round+small != round) {
				*d = *d + i;
				while (*d > (pwr-1)) {
					*d--=0;
					if (d<a) *--a=0;
					(*d)++;
				}
				for (i=radx, e=px*(r-a); *a>=i; i*=radx, e++);
			}
		}
		if (z>d+1) z=d+1;
	}
	for (; z>a && !z[-1]; z--);

	if (!p) p++;
	if (p>e && e>=-4) {
		t--;
		p-=e+1;
	} else {
		t-=2;
		p--;
	}
	
	/* Count trailing zeros in last place */
	if (z>a && z[-1]) for (i=radx, j=0; z[-1]%i==0; i*=radx, j++);
	else j=px;
	if ((t|32)=='f')
		p = MIN(p,MAX(0,px*(z-r-1)-j));
	else
		p = MIN(p,MAX(0,px*(z-r-1)+e-j));
	
	l = 1 + p + (p>0);
	if ((t|32)=='f') {
		if (e>0) l+=e;
	} else {
		estr=fmt_u(e<0 ? -e : e, ebuf, radx);
		while(ebuf-estr<3) *--estr='0';
		*--estr = (e<0 ? '-' : '+');
		*--estr = t;
		l += ebuf-estr;
	}

	char num[14]; // -1.23456e+123\0
	int nl=0;
	out(&num[0], &nl, "-", neg);
	
	if ((t|32)=='f') {
		if (a>r) a=r;
		for (d=a; d<=r; d++) {
			char *s = fmt_u(*d, buf+px, radx);
			if (d!=a) while (s>buf) *--s='0';
			else if (s==buf+px) *--s='0';
			out(&num[0], &nl, s, buf+px-s);
		}
		if (p) out(&num[0], &nl, ".", 1);
		for (; d<z && p>0; d++, p-=px) {
			char *s = fmt_u(*d, buf+px, radx);
			while (s>buf) *--s='0';
			out(&num[0], &nl, s, MIN(px,p));
		}
	} else {
		if (z<=a) z=a+1;
		for (d=a; d<z && p>=0; d++) {
			char *s = fmt_u(*d, buf+px, radx);
			if (s==buf+px) *--s='0';
			if (d!=a) while (s>buf) *--s='0';
			else {
				out(&num[0], &nl, s++, 1);
				if (p>0) out(&num[0], &nl, ".", 1);
			}
			out(&num[0], &nl, s, MIN(buf+px-s, p));
			p -= buf+px-s;
		}
		out(&num[0], &nl, estr, ebuf-estr);
	}
	
	num[nl] = '\0';
	outlet_symbol(f->x_obj.ob_outlet, gensym(num));
}

static void radx_float(t_radx *x, t_float f) {
	ufloat uf = {.f=f};
	int mt=uf.mnt, neg=uf.sgn;
	
	if (!isfinite(f))
	{	const char *s;
		if (f!=f)
		{	if (mt==0x400000 && neg) s="-1.#IND";
			else s=(neg?"-1.#QNAN":"1.#QNAN");   }
		else s=(neg?"-1.#INF":"1.#INF");
		outlet_symbol(x->x_obj.ob_outlet, gensym(s));
		return;   }
	
	fmt_fp(x, f);
}

static void *radx_new(t_float f) {
	t_radx *x = (t_radx *)pd_new(radx_class);
	outlet_new(&x->x_obj, &s_symbol);
	floatinlet_new(&x->x_obj, &x->x_radx);
	x->x_radx = f?f:16;
	return (x);
}

void radx_setup(void) {
	radx_class = class_new(gensym("radx"),
		(t_newmethod)radx_new, 0,
		sizeof(t_radx), 0,
		A_DEFFLOAT, 0);
	class_addfloat(radx_class, radx_float);
}
