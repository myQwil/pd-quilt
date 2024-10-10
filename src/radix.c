/* Copyright (c) 1997-1999 Miller Puckette.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution. */

 /* my_numbox.c written by Thomas Musil (c) IEM KUG Graz Austria 2000-2001 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "ufloat.h"

#include "g_all_guis.h"
#include <limits.h>
#include <float.h>
#include <math.h>

#undef PD_COLOR_EDIT
#undef PD_COLOR_SELECT

// dark theme
// #define PD_COLOR_EDIT         0xff9999
// #define PD_COLOR_SELECT       0x00ffff

// regular theme
#define PD_COLOR_EDIT         0xff0000
#define PD_COLOR_SELECT       0x0000ff

#define MINDIGITS 0
#define MINFONT   4

#define LEAD 2

#define MAX(a,b) ((a)>(b) ? (a):(b))
#define MIN(a,b) ((a)<(b) ? (a):(b))

#ifndef M_LN2
# define M_LN2 0.69314718055994530942  /* log_e 2 */
#endif

#define BASE_MAX 64
static const char dgt[BASE_MAX] = {
	"0123456789abcdef"
	"ghijkmnopqrstuvw" // l looks like 1
	"xyzABCDEFGHJKLMN" // I looks like 1, O looks like 0
	"PQRTUVWXYZ?!@#$%" // S looks like 5
};

static int dgt_lookup(char c) {
	switch (c) {
	case '0': case '1': case '2': case '3': case '4':
	case '5': case '6': case '7': case '8': case '9':
		return c - '0';
	case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
	case 'g': case 'h': case 'i': case 'j': case 'k':
		return c - 'a' + 10;
	case 'm': case 'n': case 'o': case 'p': case 'q': case 'r': case 's':
	case 't': case 'u': case 'v': case 'w': case 'x': case 'y': case 'z':
		return c - 'm' + 21;
	case 'A': case 'B': case 'C': case 'D': case 'E': case 'F': case 'G': case 'H':
		return c - 'A' + 35;
	case 'J': case 'K': case 'L': case 'M': case 'N':
		return c - 'J' + 43;
	case 'P': case 'Q': case 'R':
		return c - 'P' + 48;
	case 'T': case 'U': case 'V': case 'W': case 'X': case 'Y': case 'Z':
		return c - 'T' + 51;
	case '#': case '$': case '%':
		return c - '#' + 61;
	case '?': return 58;
	case '!': return 59;
	case '@': return 60;
	default: return -1;
	}
}

#if PD_FLOATSIZE == 32
# define POW powf
#else
# define POW pow
#endif

typedef struct _radix {
	t_iemgui x_gui;
	t_clock *x_clock_wait;
	t_float  x_val;
	t_float  x_tog;
	double   x_min;
	double   x_max;
	double   x_k;
	double   x_fontwidth;
	char     x_buf[PD_FLOATSIZE + 4];
	int      x_log_height;
	int      x_bexp;     // base exponent
	int      x_texp;     // power of 2 exponent
	unsigned x_base;     // radix
	unsigned x_prec;     // precision
	unsigned x_e;        // e-notation radix
	unsigned x_pwr;      // largest base power inside of 32 bits
	unsigned x_buflen;
	unsigned x_numwidth;
	unsigned x_zh;          // un-zoomed height
	unsigned char x_resize; // 1 if the border width needs to be resized
	unsigned char x_islog;  // 0 for lin, 1 for log
} t_radix;

/*------------------ global functions -------------------------*/

static void radix_key(void *z, t_symbol *keysym, t_floatarg fkey);
static void radix_draw_update(t_gobj *client, t_glist *glist);

static void radix_clip(t_radix *x) {
	if (x->x_min || x->x_max) {
		x->x_val = x->x_val < x->x_min ? x->x_min
			: (x->x_val > x->x_max ? x->x_max : x->x_val);
	}
}

static void radix_calc_fontwidth(t_radix *x) {
	double fwid = x->x_gui.x_fontsize;
	switch (x->x_gui.x_fsf.x_font_style) {
#if defined(_WIN32)
	case 2:  fwid *= 0.8;    break; // times
	case 1:  fwid *= 0.85;   break; // helvetica
	default: fwid *= 0.6021;        // dejavu
#elif defined(__APPLE__)
	case 2:  fwid *= 0.7813; break; // times
	case 1:  fwid *= 0.85;   break; // helvetica
	default: fwid *= 0.606;         // menlo
#else
	case 0:  fwid *= 0.6999;        // dejavu
	default: break;
#endif
	}
	x->x_fontwidth = fwid;
}

static void radix_borderwidth(t_radix *x, t_float zoom) {
	int n = x->x_numwidth ? x->x_numwidth : x->x_buflen;
	if (x->x_gui.x_fsf.x_font_style == 0) {
		x->x_gui.x_w = n * round(x->x_fontwidth * zoom);
	} else {
		x->x_gui.x_w = n * x->x_fontwidth * zoom;
	}
	x->x_gui.x_w += (x->x_zh / 2 + 3) * zoom;
}

static void radix_precision(t_radix *x, t_float f) {
	int m = ceil(MANT_DIG / log2(x->x_base));
	x->x_prec = f < 1 ? 1 : (f > m ? m : f);
}

static inline unsigned int radix_bounds(t_float base) {
	return base < 2 ? 2 : (base > BASE_MAX ? BASE_MAX : base);
}

static void radix_dobase(t_radix *x, t_float f) {
	unsigned base = radix_bounds(f);
	if (base > x->x_base) {
		radix_precision(x, x->x_prec);
	}
	x->x_base = base;
	unsigned umax = -1, pwr = 1;
	int bx = x->x_bexp = log(umax) / log(base), tx = 32;
	for (;bx; base *= base) {
		if (bx & 1) {
			pwr *= base;
		}
		bx >>= 1;
	}
	while (umax > pwr) {
		tx--; umax >>= 1;
	}
	x->x_pwr = pwr;
	x->x_texp = tx;
}

static void radix_base(t_radix *x, t_float f) {
	radix_dobase(x, f);
	sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
}

static void radix_ebase(t_radix *x, t_float base) {
	x->x_e = radix_bounds(base);
	sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
}

static void radix_be(t_radix *x, t_float base) {
	radix_dobase(x, base);
	x->x_e = x->x_base;
	sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
}

static void out(char num[], unsigned *i, const char *s, int l) {
	for (; l--; s++) {
		num[(*i)++] = *s;
	}
}

static char *fmt_u(uintmax_t u, char *s, int radx) {
	unsigned long v;
	for (; u > ULONG_MAX; u /= radx) {
		*--s = dgt[u % radx];
	}
	for (v = u; v; v /= radx) {
		*--s = dgt[v % radx];
	}
	return s;
}

static void radix_ftoa(t_radix *x) {
	ufloat uf = { .f = x->x_val };
	unsigned len = 0;
	if (uf.exponent == 0xFF) {
		int neg = uf.sign;
		if (uf.mantissa != 0) {
			strcpy(x->x_buf, (neg ? "-nan" : "nan"));
		} else {
			strcpy(x->x_buf, (neg ? "-inf" : "inf"));
		}
		len = 3 + neg;
		if (x->x_buflen != len) {
			x->x_resize = 1, x->x_buflen = len;
		} else {
			x->x_resize = 0;
		}
		return;
	}

	long double y = x->x_val;
	int radx = x->x_base;
	unsigned pwr = x->x_pwr;
	int bx = x->x_bexp, tx = x->x_texp;
	int xb = bx - 1, xt = tx - 1;
	int neg = 0, t = 'g';

	/* based on: musl-libc /src/stdio/vfprintf.c */
	unsigned size = (LDBL_MANT_DIG + xt) / tx + 1    // mantissa expansion
		+ (LDBL_MAX_EXP + LDBL_MANT_DIG + xt + xb) / bx; // exponent expansion
	uint32_t big[size];
	uint32_t *a, *d, *r, *z;
	long i;
	int e2 = 0, e, j;
	char buf[bx + LDBL_MANT_DIG / 4];
	char ebuf0[3 * sizeof(int)], *ebuf = &ebuf0[3 * sizeof(int)], *estr;

	if (signbit(y)) {
		y = -y, neg = 1;
	}
	int p = (x->x_numwidth && x->x_prec >= x->x_numwidth)
		? x->x_numwidth - neg : x->x_prec;

	y = frexpl(y, &e2) * 2;
	if (y) {
		y *= (1 << xt), e2 -= tx;
	}

	if (e2 < 0) {
		a = r = z = big;
	} else {
		a = r = z = big + sizeof(big) / sizeof(*big) - LDBL_MANT_DIG - 1;
	}

	do {
		*z = y;
		y = pwr * (y - *z++);
	} while (y && --size);

	while (e2 > 0) {
		uint32_t carry = 0;
		int sh = MIN(tx, e2);
		for (d = z - 1; d >= a; d--) {
			uint64_t u = ((uint64_t)*d << sh) + carry;
			*d = u % pwr;
			carry = u / pwr;
		}
		if (carry) {
			*--a = carry;
		}
		while (z > a && !z[-1]) {
			z--;
		}
		e2 -= sh;
	}

	while (e2 < 0) {
		uint32_t carry = 0, *b;
		int sh = MIN(bx, -e2), need = 1 + (p + LDBL_MANT_DIG / 3U + xb) / bx;
		for (d = a; d < z; d++) {
			uint32_t rm = *d & ((1 << sh) - 1);
			*d = (*d >> sh) + carry;
			carry = (pwr >> sh) * rm;
		}
		if (!*a) {
			a++;
		}
		if (carry) {
			*z++ = carry;
		}
		/* Avoid (slow!) computation past requested precision */
		b = a;
		if (z - b > need) {
			z = b + need;
		}
		e2 += sh;
	}

	if (a < z) {
		for (i = radx, e = bx * (r - a); *a >= (uint32_t)i; i *= radx, e++);
	} else {
		e = 0;
	}

	/* Perform rounding: j is precision after the radix (possibly neg) */
	j = p - e - 1;
	if (j < bx * (z - r - 1)) {
		uint32_t u;
		/* We avoid C's broken division of negative numbers */
		d = r + 1 + ((j + bx * LDBL_MAX_EXP) / bx - LDBL_MAX_EXP);
		j += bx * LDBL_MAX_EXP;
		j %= bx;
		for (i = radx, j++; j < bx; i *= radx, j++);
		u = *d % i;
		/* Are there any significant digits past j? */
		if (u || d + 1 != z) {
			long double round = 2 / LDBL_EPSILON;
			long double small;
			if ((*d / i & 1) || (i == (int)pwr && d > a && (d[-1] & 1))) {
				round += 2;
			}
			if ((int)u < i / 2) {
				small = 0x0.8p0;
			} else if ((int)u == i / 2 && d + 1 == z) {
				small = 0x1.0p0;
			} else {
				small = 0x1.8p0;
			}
			if (neg) {
				round *= -1, small *= -1;
			}
			*d -= u;
			/* Decide whether to round by probing round+small */
			if (round + small != round) {
				*d = *d + i;
				while (*d > pwr - 1) {
					*d-- = 0;
					if (d < a) {
						*--a = 0;
					}
					(*d)++;
				}
				for (i = radx, e = bx * (r - a); (int)*a >= i; i *= radx, e++);
			}
		}
		if (z > d + 1) {
			z = d + 1;
		}
	}

	for (; z > a && !z[-1]; z--);

	if (!p) {
		p++;
	}
	if (p > e && e >= -4) {
		t--;
		p -= e + 1;
	} else {
		t -= 2;
		p--;
	}

	/* Count trailing zeros in last place */
	if (z > a && z[-1]) {
		for (i = radx, j = 0; z[-1] % i == 0; i *= radx, j++);
	} else {
		j = bx;
	}
	if ((t | 32) == 'f') {
		p = MIN(p, MAX(0, bx * (z - r - 1) - j));
	} else {
		p = MIN(p, MAX(0, bx * (z - r - 1) + e - j));
	}

	if ((t | 32) != 'f') {
		int erad = x->x_e;
		estr = fmt_u(e < 0 ? -e : e, ebuf, erad);
		while (ebuf - estr < LEAD) {
			*--estr = '0';
		}
		*--estr = (e < 0 ? '-' : '+');
		*--estr = '^';
	}

	char *num = x->x_buf, *dec = 0, *nxt = 0;
	unsigned ni = 0;
	out(num, &ni, "-", neg);

	if ((t | 32) == 'f') {
		if (a > r) {
			a = r;
		}
		for (d = a; d <= r; d++) {
			char *s = fmt_u(*d, buf + bx, radx);
			if (d != a) {
				while (s > buf) {
					*--s = '0';
				}
			} else if (s == buf + bx) {
				*--s = '0';
			}
			out(num, &ni, s, buf + bx - s);
		}
		if (p) {
			dec = num + ni;
			out(num, &ni, ".", 1);
		}
		for (; d < z && p > 0; d++, p -= bx) {
			char *s = fmt_u(*d, buf + bx, radx);
			while (s > buf) *--s = '0';
			out(num, &ni, s, MIN(bx, p));
		}
	} else {
		if (z <= a) {
			z = a + 1;
		}
		for (d = a; d < z && p >= 0; d++) {
			char *s = fmt_u(*d, buf + bx, radx);
			if (s == buf + bx) {
				*--s = '0';
			}
			if (d != a) {
				while (s > buf) {
					*--s = '0';
				}
			} else {
				out(num, &ni, s++, 1);
				if (p > 0) {
					dec = num + ni;
					out(num, &ni, ".", 1);
				}
			}
			out(num, &ni, s, MIN(buf + bx - s, p));
			p -= buf + bx - s;
		}
		nxt = num + ni;
		out(num, &ni, estr, ebuf - estr);
	}
	num[ni] = '\0';
	len = ni;

	// reduce if too big for number box width
	if (x->x_numwidth > 0 && ni > x->x_numwidth) {
		if (!dec) {
			dec = num + ni;
		}
		if (!nxt) {
			nxt = num + ni;
		}
		int reduce = ni - x->x_numwidth;
		if (nxt - dec >= reduce) {
			char *s1 = nxt - reduce;
			ebuf = num + ni;
			for (;nxt < ebuf; s1++, nxt++) {
				*s1 = *nxt;
			}
			*s1 = '\0';
			len = s1 - num;
		} else {
			num[0] = (neg ? '-' : '+');
			num[1] = '\0';
		}
	}
	if (len < 3) {
		len = 3;
	}
	if (x->x_buflen != len) {
		x->x_resize = 1, x->x_buflen = len;
	} else {
		x->x_resize = 0;
	}
}

/* ------------ radix gui number box ----------------------- */

t_widgetbehavior radix_widgetbehavior;
static t_class *radix_class;

#define radix_draw_io 0

static void radix_zoom(t_radix *x, t_float zoom) {
	t_iemgui *gui = &x->x_gui;
	int oldzoom = gui->x_glist->gl_zoom;
	if (oldzoom < 1) {
		oldzoom = 1;
	}
	gui->x_h = x->x_zh * zoom - (zoom - 1) * 2;
	radix_borderwidth(x, zoom);
}

static void radix_draw_config(t_radix *x, t_glist *glist) {
	radix_ftoa(x);
	radix_calc_fontwidth(x);
	radix_borderwidth(x, IEMGUI_ZOOM(x));

	const int zoom = IEMGUI_ZOOM(x);
	t_canvas *canvas = glist_getcanvas(glist);
	t_iemgui *iemgui = &x->x_gui;
	int xpos = text_xpix(&x->x_gui.x_obj, glist);
	int ypos = text_ypix(&x->x_gui.x_obj, glist);
	int w = x->x_gui.x_w;
	int h = x->x_gui.x_h, half = h / 2;
	int d = zoom + h / (34 * zoom);
	int corner = h / 4;
	int ioh = IEM_GUI_IOHEIGHT * zoom;
	int rad = half - ioh + zoom;
	char tag[128];

	int lcol = x->x_gui.x_lcol;
	int fcol = x->x_gui.x_fcol;
	t_atom fontatoms[] = {
	  { .a_type=A_SYMBOL, .a_w={.w_symbol=gensym(iemgui->x_font)} }
	, { .a_type=A_FLOAT , .a_w={.w_float=-iemgui->x_fontsize * zoom} }
	, { .a_type=A_SYMBOL, .a_w={.w_symbol=gensym(sys_fontweight)} }
	};

	if (x->x_gui.x_fsf.x_selected) {
		fcol = lcol = PD_COLOR_SELECT;
	}
	if (x->x_gui.x_fsf.x_change) {
		fcol = PD_COLOR_EDIT;
	}

	sprintf(tag, "%pBASE1", x);
	pdgui_vmess(0, "crs  ii ii ii ii ii ii", canvas, "coords", tag
	, xpos, ypos
	, xpos + w - corner, ypos
	, xpos + w, ypos + corner
	, xpos + w, ypos + h
	, xpos, ypos + h
	, xpos, ypos);
	pdgui_vmess(0, "crs  ri rk rk", canvas, "itemconfigure", tag
	, "-width", zoom
	, "-outline", x->x_gui.x_fcol
	, "-fill", x->x_gui.x_bcol);


	sprintf(tag, "%pBASE2", x);
	pdgui_vmess(0, "crs  ii ii", canvas, "coords", tag
	, xpos - rad, ypos + ioh
	, xpos + rad, ypos - ioh + h);
	pdgui_vmess(0, "crs  ri rk", canvas, "itemconfigure", tag
	, "-width", zoom
	, "-outline", x->x_gui.x_fcol);

	sprintf(tag, "%pLABEL", x);
	pdgui_vmess(0, "crs  ii", canvas, "coords", tag
	, xpos + x->x_gui.x_ldx * zoom
	, ypos + x->x_gui.x_ldy * zoom);
	pdgui_vmess(0, "crs  rA rk", canvas, "itemconfigure", tag
	, "-font", 3, fontatoms
	, "-fill", lcol);
	iemgui_dolabel(x, &x->x_gui, x->x_gui.x_lab, 1);

	sprintf(tag, "%pNUMBER", x);
	pdgui_vmess(0, "crs  ii", canvas, "coords", tag
	, xpos + half + 2 * zoom, ypos + half + d);
	pdgui_vmess(0, "crs  rs rA rk", canvas, "itemconfigure", tag
	, "-text", x->x_buf
	, "-font", 3, fontatoms
	, "-fill", fcol);
}

static void radix_resize(t_radix *x) {
	radix_borderwidth(x, IEMGUI_ZOOM(x));
	const int zoom = IEMGUI_ZOOM(x);
	t_iemgui *iemgui = &x->x_gui;
	t_glist *glist = iemgui->x_glist;
	t_canvas *canvas = glist_getcanvas(glist);
	int xpos = text_xpix(&x->x_gui.x_obj, glist);
	int ypos = text_ypix(&x->x_gui.x_obj, glist);
	int w = x->x_gui.x_w;
	int h = x->x_gui.x_h;
	int corner = h / 4;
	char tag[128];

	sprintf(tag, "%pBASE1", x);
	pdgui_vmess(0, "crs  ii ii ii ii ii ii", canvas, "coords", tag
	, xpos, ypos
	, xpos + w - corner, ypos
	, xpos + w, ypos + corner
	, xpos + w, ypos + h
	, xpos, ypos + h
	, xpos, ypos);

	t_atom fontatoms[] = {
	  { .a_type=A_SYMBOL, .a_w={.w_symbol=gensym(iemgui->x_font)} }
	, { .a_type=A_FLOAT , .a_w={.w_float=-iemgui->x_fontsize * zoom} }
	, { .a_type=A_SYMBOL, .a_w={.w_symbol=gensym(sys_fontweight)} }
	};
	sprintf(tag, "%pNUMBER", x);
	pdgui_vmess(0, "crs rA", canvas, "itemconfigure", tag
	, "-font", 3, fontatoms);
}

static void radix_fontsize(t_radix *x, t_float f) {
	if (f < 1) {
		f = 1;
	}
	x->x_gui.x_fontsize = f;
	radix_calc_fontwidth(x);
	radix_resize(x);
}

static void radix_fontwidth(t_radix *x, t_float f) {
	x->x_fontwidth = f;
	radix_resize(x);
}

static void radix_draw_new(t_radix *x, t_glist *glist) {
	t_canvas *canvas = glist_getcanvas(glist);
	char tag[128], tag_object[128];
	char *tags[] = { tag_object, tag, "label", "text" };
	sprintf(tag_object, "%pOBJ", x);

	sprintf(tag, "%pBASE1", x);
	pdgui_vmess(0, "crr ii rS", canvas, "create", "polygon"
	, 0, 0, "-tags", 2, tags);

	sprintf(tag, "%pBASE2", x);
	pdgui_vmess(0, "crr iiii ri ri rS", canvas, "create", "arc"
	, 0, 0, 0, 0
	, "-start", 270, "-extent", 180
	, "-tags", 2, tags);

	sprintf(tag, "%pLABEL", x);
	pdgui_vmess(0, "crr ii rs rS", canvas, "create", "text"
	, 0, 0, "-anchor", "w", "-tags", 4, tags);

	sprintf(tag, "%pNUMBER", x);
	pdgui_vmess(0, "crr ii rs rS", canvas, "create", "text"
	, 0, 0, "-anchor", "w", "-tags", 2, tags);

	radix_draw_config(x, glist);
	(*x->x_gui.x_draw)(x, x->x_gui.x_glist, IEM_GUI_DRAW_MODE_IO);
}

static void radix_draw_select(t_radix *x, t_glist *glist) {
	t_canvas *canvas = glist_getcanvas(glist);
	int lcol = x->x_gui.x_lcol, fcol = x->x_gui.x_fcol;
	char tag[128];

	if (x->x_gui.x_fsf.x_selected) {
		if (x->x_gui.x_fsf.x_change) {
			x->x_gui.x_fsf.x_change = 0;
			x->x_buf[0] = 0;
			sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		}
		lcol = fcol = PD_COLOR_SELECT;
	}

	sprintf(tag, "%pBASE1", x);
	pdgui_vmess(0, "crs rk", canvas, "itemconfigure", tag, "-outline", fcol);
	sprintf(tag, "%pBASE2", x);
	pdgui_vmess(0, "crs rk", canvas, "itemconfigure", tag, "-outline", fcol);
	sprintf(tag, "%pLABEL", x);
	pdgui_vmess(0, "crs rk", canvas, "itemconfigure", tag, "-fill", lcol);
	sprintf(tag, "%pNUMBER", x);
	pdgui_vmess(0, "crs rk", canvas, "itemconfigure", tag, "-fill", fcol);
}

static void radix_draw_update(t_gobj *client, t_glist *glist) {
	t_radix *x = (t_radix *)client;
	if (glist_isvisible(glist)) {
		t_canvas *canvas = glist_getcanvas(glist);
		char tag[128];
		sprintf(tag, "%pNUMBER", x);
		if (x->x_gui.x_fsf.x_change) {
			if (x->x_buf[0]) {
				char *cp = x->x_buf;
				unsigned sl = strlen(x->x_buf);

				x->x_buf[sl] = '>';
				x->x_buf[sl + 1] = 0;
				if (sl >= x->x_numwidth) {
					cp += sl - x->x_numwidth + 1;
				}
				pdgui_vmess(0, "crs rk rs", canvas, "itemconfigure", tag
				, "-fill", PD_COLOR_EDIT, "-text", cp);
				x->x_buf[sl] = 0;
			} else {
				radix_ftoa(x);
				if (!x->x_numwidth && x->x_resize) {
					radix_resize(x);
				}
				pdgui_vmess(0, "crs rk rs", canvas, "itemconfigure", tag
				, "-fill", PD_COLOR_EDIT, "-text", x->x_buf);
				x->x_buf[0] = 0;
			}
		} else {
			radix_ftoa(x);
			if (!x->x_numwidth && x->x_resize) {
				radix_resize(x);
			}
			pdgui_vmess(0, "crs rk rs", canvas, "itemconfigure", tag
			, "-fill", (x->x_gui.x_fsf.x_selected ? PD_COLOR_SELECT : x->x_gui.x_fcol)
			, "-text", x->x_buf);
			x->x_buf[0] = 0;
		}
	}
}

/* widget helper functions */

static void radix_tick_wait(t_radix *x) {
	sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
}

/* ------------------------ radix widgetbehaviour----------------------------- */

static void radix_getrect(t_gobj *z, t_glist *glist
, int *xp1, int *yp1, int *xp2, int *yp2) {
	t_radix *x = (t_radix *)z;
	*xp1 = text_xpix(&x->x_gui.x_obj, glist);
	*yp1 = text_ypix(&x->x_gui.x_obj, glist);
	*xp2 = *xp1 + x->x_gui.x_w;
	*yp2 = *yp1 + x->x_gui.x_h;
}

static void radix_save(t_gobj *z, t_binbuf *b) {
	t_radix *x = (t_radix *)z;
	t_symbol *bflcol[3];
	t_symbol *srl[3];

	iemgui_save(&x->x_gui, srl, bflcol);
	if (x->x_gui.x_fsf.x_change) {
		x->x_gui.x_fsf.x_change = 0;
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
	}
	binbuf_addv(b, "ssiisiiffiisssiiiisssiiifi", gensym("#X"), gensym("obj")
	, (int)x->x_gui.x_obj.te_xpix, (int)x->x_gui.x_obj.te_ypix
	, gensym("radix"), x->x_numwidth, x->x_zh
	, (t_float)x->x_min, (t_float)x->x_max
	, x->x_islog, iem_symargstoint(&x->x_gui.x_isa)
	, srl[0], srl[1], srl[2]
	, x->x_gui.x_ldx, x->x_gui.x_ldy
	, iem_fstyletoint(&x->x_gui.x_fsf), x->x_gui.x_fontsize
	, bflcol[0], bflcol[1], bflcol[2]
	, x->x_base, x->x_prec, x->x_e
	, x->x_gui.x_isa.x_loadinit ? x->x_val : 0., x->x_log_height);
	binbuf_addv(b, ";");
}

static int radix_check_minmax(t_radix *x, double min, double max) {
	int ret = 0;

	if (x->x_islog) {
		if ((min == 0.0) && (max == 0.0)) {
			max = 1.0;
		}
		if (max > 0.0) {
			if (min <= 0.0) {
				min = 0.01 * max;
			}
		} else {
			if (min > 0.0) {
				max = 0.01 * min;
			}
		}
		x->x_k = exp(log(max / min) / (double)(x->x_log_height));
	} else {
		x->x_k = 1.0;
		if (min == 0.0 && max == 0.0) {
			return ret;
		}
	}
	x->x_min = min;
	x->x_max = max;
	if (x->x_val < x->x_min) {
		x->x_val = x->x_min;
		ret = 1;
	}
	if (x->x_val > x->x_max) {
		x->x_val = x->x_max;
		ret = 1;
	}
	return ret;
}

static void radix_properties(t_gobj *z, t_glist *owner) {
	(void)owner;
	t_radix *x = (t_radix *)z;

	if (x->x_gui.x_fsf.x_change) {
		x->x_gui.x_fsf.x_change = 0;
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
	}
	iemgui_new_dialog(x, &x->x_gui, "nbx"
	, x->x_numwidth, MINDIGITS
	, x->x_zh, IEM_GUI_MINSIZE
	, x->x_min, x->x_max
	, 0
	, x->x_islog, "linear", "logarithmic"
	, 1, -1, x->x_log_height);
}

static void radix_bang(t_radix *x) {
	outlet_float(x->x_gui.x_obj.ob_outlet, x->x_val);
	if (x->x_gui.x_fsf.x_snd_able && x->x_gui.x_snd->s_thing) {
		pd_float(x->x_gui.x_snd->s_thing, x->x_val);
	}
}

static void radix_dialog(t_radix *x, t_symbol *s, int argc, t_atom *argv) {
	(void)s;
	t_symbol *srl[3];
	int w = (int)atom_getfloatarg(0, argc, argv);
	int h = (int)atom_getfloatarg(1, argc, argv);
	double min = (double)atom_getfloatarg(2, argc, argv);
	double max = (double)atom_getfloatarg(3, argc, argv);
	int lilo = (int)atom_getfloatarg(4, argc, argv);
	int log_height = (int)atom_getfloatarg(6, argc, argv);
	t_atom undo[18];
	iemgui_setdialogatoms(&x->x_gui, 18, undo);
	SETFLOAT(undo + 0, x->x_numwidth);
	SETFLOAT(undo + 2, x->x_min);
	SETFLOAT(undo + 3, x->x_max);
	SETFLOAT(undo + 4, x->x_islog);
	SETFLOAT(undo + 6, x->x_log_height);

	pd_undo_set_objectstate(x->x_gui.x_glist, (t_pd *)x, gensym("dialog")
	, 18, undo, argc, argv);

	if (lilo != 0) lilo = 1;
	x->x_islog = lilo;
	iemgui_dialog(&x->x_gui, srl, argc, argv);
	if (w < MINDIGITS) {
		w = MINDIGITS;
	}
	x->x_numwidth = w;
	if (h < IEM_GUI_MINSIZE) {
		h = IEM_GUI_MINSIZE;
	}
	x->x_zh = h;
	x->x_gui.x_h = h * IEMGUI_ZOOM(x) - (IEMGUI_ZOOM(x) - 1) * 2;
	if (log_height < 10) {
		log_height = 10;
	}
	x->x_log_height = log_height;
	/*if(radix_check_minmax(x, min, max))
	 radix_bang(x);*/
	radix_check_minmax(x, min, max);
	(*x->x_gui.x_draw)(x, x->x_gui.x_glist, IEM_GUI_DRAW_MODE_UPDATE);
	iemgui_size(x, &x->x_gui);
}

static void radix_motion(t_radix *x, t_float dx, t_float dy, t_float up) {
	(void)dx;
	double k2 = 1.0;
	double pwr = x->x_base * x->x_base;
	double fin = 1 / pwr;
	ufloat uf = { .f = x->x_val };
	if (uf.exponent > 150) {
		k2 *= exp(M_LN2 * (uf.exponent - 150));
	}
	if (up != 0) {
		return;
	}
	if (x->x_gui.x_fsf.x_finemoved) {
		k2 *= fin;
	}
	if (x->x_islog) {
		x->x_val *= pow(x->x_k, -k2 * dy);
	} else {
		x->x_val -= k2 * dy;
		double trunc = fin * floor(pwr * x->x_val + 0.5);
		fin *= fin;
		if (trunc < x->x_val + fin && trunc > x->x_val - fin) {
			x->x_val = trunc;
		}
	}
	radix_clip(x);
	sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
	radix_bang(x);
}

static void radix_set(t_radix *x, t_floatarg f) {
	t_float ftocompare = f;
	/* bitwise comparison, suggested by Dan Borstein - to make this work
	ftocompare must be t_float type like x_val. */
	if (memcmp(&ftocompare, &x->x_val, sizeof(ftocompare))) {
		x->x_val = ftocompare;
		if (pd_compatibilitylevel < 53) {
			radix_clip(x);
		}
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
	}
}

static void radix_float(t_radix *x, t_floatarg f) {
	radix_set(x, f);
	if (x->x_gui.x_fsf.x_put_in2out) {
		radix_bang(x);
	}
}

static void radix_click(t_radix *x, t_floatarg xpos, t_floatarg ypos
, t_floatarg shift, t_floatarg ctrl, t_floatarg alt) {
	(void)shift;
	(void)ctrl;
	if (alt) {
		if (x->x_val != 0) {
			x->x_tog = x->x_val;
			radix_float(x, 0);
			return;
		} else {
			radix_float(x, x->x_tog);
		}
	}
	glist_grab(x->x_gui.x_glist, &x->x_gui.x_obj.te_g
	, (t_glistmotionfn)radix_motion, radix_key, xpos, ypos);
}

static int radix_newclick(t_gobj *z, struct _glist *glist
, int xpix, int ypix, int shift, int alt, int dbl, int doit) {
	(void)glist;
	(void)dbl;
	t_radix *x = (t_radix *)z;

	if (doit) {
		radix_click(x, (t_floatarg)xpix, (t_floatarg)ypix
		, (t_floatarg)shift, 0, (t_floatarg)alt);
		if (shift) {
			x->x_gui.x_fsf.x_finemoved = 1;
		} else {
			x->x_gui.x_fsf.x_finemoved = 0;
		}
		if (!x->x_gui.x_fsf.x_change) {
			clock_delay(x->x_clock_wait, 50);
			x->x_gui.x_fsf.x_change = 1;
			x->x_buf[0] = 0;
		} else {
			x->x_gui.x_fsf.x_change = 0;
			x->x_buf[0] = 0;
			sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		}
	}
	return (1);
}

static void radix_log_height(t_radix *x, t_floatarg lh) {
	if (lh < 10.0) {
		lh = 10.0;
	}
	x->x_log_height = (int)lh;
	if (x->x_islog) {
		x->x_k = exp(log(x->x_max / x->x_min) / (double)(x->x_log_height));
	} else {
		x->x_k = 1.0;
	}
}

static void radix_size(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	int h, w;

	w = (int)atom_getfloatarg(0, ac, av);
	if (w < MINDIGITS) {
		w = MINDIGITS;
	}
	x->x_numwidth = w;
	if (ac > 1) {
		h = (int)atom_getfloatarg(1, ac, av);
		if (h < IEM_GUI_MINSIZE) {
			h = IEM_GUI_MINSIZE;
		}
		x->x_gui.x_h = h * IEMGUI_ZOOM(x);
	}
	radix_borderwidth(x, IEMGUI_ZOOM(x));
	iemgui_size((void *)x, &x->x_gui);
	(*x->x_gui.x_draw)(x, x->x_gui.x_glist, IEM_GUI_DRAW_MODE_UPDATE);
}

static void radix_delta(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_delta((void *)x, &x->x_gui, s, ac, av);
}

static void radix_pos(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_pos((void *)x, &x->x_gui, s, ac, av);
}

static void radix_range(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (radix_check_minmax(x, (double)atom_getfloatarg(0, ac, av)
	, (double)atom_getfloatarg(1, ac, av))) {
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		/*radix_bang(x);*/
	}
}

static void radix_color(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_color((void *)x, &x->x_gui, s, ac, av);
}

static void radix_send(t_radix *x, t_symbol *s) {
	iemgui_send(x, &x->x_gui, s);
}

static void radix_receive(t_radix *x, t_symbol *s) {
	iemgui_receive(x, &x->x_gui, s);
}

static void radix_label(t_radix *x, t_symbol *s) {
iemgui_label((void *)x, &x->x_gui, s);
}

static void radix_label_pos(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_label_pos((void *)x, &x->x_gui, s, ac, av);
}

static void radix_label_font(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	int f = (int)atom_getfloatarg(1, ac, av);

	if (f < 4) {
		f = 4;
	}
	x->x_gui.x_fontsize = f;
	f = (int)atom_getfloatarg(0, ac, av);
	if ((f < 0) || (f > 2)) {
		f = 0;
	}
	x->x_gui.x_fsf.x_font_style = f;
	radix_calc_fontwidth(x);
	radix_borderwidth(x, IEMGUI_ZOOM(x));
	iemgui_label_font((void *)x, &x->x_gui, s, ac, av);
}

static void radix_log(t_radix *x) {
	x->x_islog = 1;
	if (radix_check_minmax(x, x->x_min, x->x_max)) {
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		/*radix_bang(x);*/
	}
}

static void radix_lin(t_radix *x) {
	x->x_islog = 0;
}

static void radix_init(t_radix *x, t_floatarg f) {
	x->x_gui.x_isa.x_loadinit = (f == 0.0) ? 0 : 1;
}

static void radix_loadbang(t_radix *x, t_floatarg action) {
	if (action == LB_LOAD && x->x_gui.x_isa.x_loadinit) {
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		radix_bang(x);
	}
}

static void radix_key(void *z, t_symbol *keysym, t_floatarg fkey) {
	(void)keysym;
	t_radix *x = z;
	char c = fkey;
	char buf[3];
	buf[1] = 0;

	if (c == 0) {
		x->x_gui.x_fsf.x_change = 0;
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		return;
	}
	if (((c >= '0') && (c <= '9')) || (c == '.') || (c == '-') ||
		(c == 'e') || (c == '+') || (c == 'E')) {
		if (strlen(x->x_buf) < (IEMGUI_MAX_NUM_LEN - 2)) {
			buf[0] = c;
			strcat(x->x_buf, buf);
			sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		}
	} else if ((c == '\b') || (c == 127)) {
		int sl = (int)strlen(x->x_buf) - 1;

		if (sl < 0) {
			sl = 0;
		}
		x->x_buf[sl] = 0;
		sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
	} else if ((c == '\n') || (c == 13)) {
		if (x->x_buf[0]) {
			x->x_val = atof(x->x_buf);
			x->x_buf[0] = 0;
			if (pd_compatibilitylevel < 53) {
				radix_clip(x);
			}
			sys_queuegui(x, x->x_gui.x_glist, radix_draw_update);
		}
		radix_bang(x);
	}
}

static void radix_list(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	if (!ac) {
		radix_bang(x);
	} else if (IS_A_FLOAT(av, 0)) {
		radix_set(x, atom_getfloatarg(0, ac, av));
		radix_bang(x);
	}
}
	/* string to real number */
static t_float strtor(const char *s, int base)
{
	t_float f;
	int neg, i;
	if (*s == '-') {
		if ( (i = dgt_lookup(s[1])) >= 0) {
			neg = 1, f = i, s += 2;
		} else {
			return 0;
		}
	} else {
		neg = 0, f = 0;
	}
	for (; (i = dgt_lookup(*s)) >= 0; ++s) {
		f = base * f + i;
	}
	if (*s++ == '.') {
		const char *dec = s;
		for (; (i = dgt_lookup(*s)) >= 0; ++s) {
			f = base * f + i;
		}
		f *= POW(base, dec - s);
	}
	return neg ? -f : f;
}

static void radix_anything(t_radix *x, t_symbol *s, int ac, t_atom *av) {
	const char *cp = s->s_name;
	if (*cp == 'b' && ac) {
		int base = radix_bounds(strtor(cp+1, 10));
		char res[32];
		if (av->a_type == A_FLOAT) {
			sprintf(res, "%f", av->a_w.w_float);
			cp = res;
		} else {
			cp = av->a_w.w_symbol->s_name;
		}
		radix_float(x, strtor(cp, base));
	}
}

static void *radix_new(t_symbol *s, int argc, t_atom *argv) {
	(void)s;
	t_radix *x = (t_radix *)iemgui_new(radix_class);
	IEMGUI_SETDRAWFUNCTIONS(x, radix);

	int w = 0, h = 14 * IEM_GUI_DEFAULTSIZE_SCALE;
	int lilo = 0, ldx = 0, ldy = -8 * IEM_GUI_DEFAULTSIZE_SCALE;
	int fs = x->x_gui.x_fontsize;
	int log_height = 256;
	double min = 0, max = 0, v = 0.0;
	int base = 0, prec = 0, e = 0;

	if ((argc >= 20) && IS_A_FLOAT(argv, 0) && IS_A_FLOAT(argv, 1)
	   && IS_A_FLOAT(argv, 2) && IS_A_FLOAT(argv, 3)
	   && IS_A_FLOAT(argv, 4) && IS_A_FLOAT(argv, 5)
	   && (IS_A_SYMBOL(argv, 6) || IS_A_FLOAT(argv, 6))
	   && (IS_A_SYMBOL(argv, 7) || IS_A_FLOAT(argv, 7))
	   && (IS_A_SYMBOL(argv, 8) || IS_A_FLOAT(argv, 8))
	   && IS_A_FLOAT(argv, 9) && IS_A_FLOAT(argv, 10)
	   && IS_A_FLOAT(argv, 11) && IS_A_FLOAT(argv, 12) && IS_A_FLOAT(argv, 16)
	   && IS_A_FLOAT(argv, 17) && IS_A_FLOAT(argv, 18) && IS_A_FLOAT(argv, 19)) {
		w = (int)atom_getfloatarg(0, argc, argv);
		h = (int)atom_getfloatarg(1, argc, argv);
		min = (double)atom_getfloatarg(2, argc, argv);
		max = (double)atom_getfloatarg(3, argc, argv);
		lilo = (int)atom_getfloatarg(4, argc, argv);
		iem_inttosymargs(&x->x_gui.x_isa, atom_getfloatarg(5, argc, argv));
		iemgui_new_getnames(&x->x_gui, 6, argv);
		ldx = (int)atom_getfloatarg(9, argc, argv);
		ldy = (int)atom_getfloatarg(10, argc, argv);
		iem_inttofstyle(&x->x_gui.x_fsf, atom_getfloatarg(11, argc, argv));
		fs = (int)atom_getfloatarg(12, argc, argv);
		iemgui_all_loadcolors(&x->x_gui, argv + 13, argv + 14, argv + 15);
		base = atom_getfloatarg(16, argc, argv);
		prec = atom_getfloatarg(17, argc, argv);
		e = atom_getfloatarg(18, argc, argv);
		v = atom_getfloatarg(19, argc, argv);
		if ((argc == 21) && IS_A_FLOAT(argv, 20)) {
			log_height = (int)atom_getfloatarg(20, argc, argv);
		}
	} else {
		iemgui_new_getnames(&x->x_gui, 6, 0);
		if (1 <= argc && argc <= 3) {
			base = atom_getfloatarg(0, argc, argv);
			prec = atom_getfloatarg(1, argc, argv);
			e = atom_getfloatarg(2, argc, argv);
		}
	}
	radix_dobase(x, base ? base : 16);
	radix_precision(x, prec ? prec : (MANT_DIG / log2(x->x_base)));
	x->x_e = e ? radix_bounds(e) : x->x_base;

	x->x_gui.x_fsf.x_snd_able = (0 != x->x_gui.x_snd);
	x->x_gui.x_fsf.x_rcv_able = (0 != x->x_gui.x_rcv);
	if (x->x_gui.x_isa.x_loadinit) {
		x->x_val = v;
	} else {
		x->x_val = 0.0;
	}
	if (lilo != 0) {
		lilo = 1;
	}
	x->x_islog = lilo;
	if (log_height < 10) {
		log_height = 10;
	}
	x->x_log_height = log_height;
	if (x->x_gui.x_fsf.x_font_style == 1) strcpy(x->x_gui.x_font, "helvetica");
	else if (x->x_gui.x_fsf.x_font_style == 2) strcpy(x->x_gui.x_font, "times");
	else {
		x->x_gui.x_fsf.x_font_style = 0;
		strcpy(x->x_gui.x_font, sys_font);
	}
	if (x->x_gui.x_fsf.x_rcv_able) {
		pd_bind(&x->x_gui.x_obj.ob_pd, x->x_gui.x_rcv);
	}
	x->x_gui.x_ldx = ldx;
	x->x_gui.x_ldy = ldy;
	x->x_gui.x_fontsize = (fs < MINFONT) ? MINFONT : fs;
	if (w < MINDIGITS) {
		w = MINDIGITS;
	}
	x->x_numwidth = w;
	if (h < IEM_GUI_MINSIZE) {
		h = IEM_GUI_MINSIZE;
	}
	x->x_gui.x_h = x->x_zh = h;
	x->x_buf[0] = 0;
	x->x_buflen = 3;
	radix_check_minmax(x, min, max);
	iemgui_verify_snd_ne_rcv(&x->x_gui);
	x->x_clock_wait = clock_new(x, (t_method)radix_tick_wait);
	x->x_gui.x_fsf.x_change = 0;
	iemgui_newzoom(&x->x_gui);
	outlet_new(&x->x_gui.x_obj, &s_float);
	return (x);
}

static void radix_free(t_radix *x) {
	if (x->x_gui.x_fsf.x_rcv_able) {
		pd_unbind(&x->x_gui.x_obj.ob_pd, x->x_gui.x_rcv);
	}
	clock_free(x->x_clock_wait);
	pdgui_stub_deleteforkey(x);
}

void radix_setup(void) {
	radix_class = class_new(gensym("radix"), (t_newmethod)radix_new
	, (t_method)radix_free, sizeof(t_radix), 0, A_GIMME, 0);
	class_addbang(radix_class, radix_bang);
	class_addfloat(radix_class, radix_float);
	class_addlist(radix_class, radix_list);
	class_addanything(radix_class, radix_anything);
	class_addmethod(radix_class, (t_method)radix_click
	, gensym("click"), A_FLOAT, A_FLOAT, A_FLOAT, A_FLOAT, A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_motion
	, gensym("motion"), A_FLOAT, A_FLOAT, A_DEFFLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_dialog
	, gensym("dialog"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_loadbang
	, gensym("loadbang"), A_DEFFLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_set
	, gensym("set"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_size
	, gensym("size"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_delta
	, gensym("delta"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_pos
	, gensym("pos"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_range
	, gensym("range"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_color
	, gensym("color"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_send
	, gensym("send"), A_DEFSYM, 0);
	class_addmethod(radix_class, (t_method)radix_receive
	, gensym("receive"), A_DEFSYM, 0);
	class_addmethod(radix_class, (t_method)radix_label
	, gensym("label"), A_DEFSYM, 0);
	class_addmethod(radix_class, (t_method)radix_label_pos
	, gensym("label_pos"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_label_font
	, gensym("label_font"), A_GIMME, 0);
	class_addmethod(radix_class, (t_method)radix_log
	, gensym("log"), 0);
	class_addmethod(radix_class, (t_method)radix_lin
	, gensym("lin"), 0);
	class_addmethod(radix_class, (t_method)radix_init
	, gensym("init"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_log_height
	, gensym("log_height"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_base
	, gensym("base"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_base
	, gensym("b"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_ebase
	, gensym("e"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_be
	, gensym("be"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_precision
	, gensym("p"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_fontsize
	, gensym("fs"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_fontwidth
	, gensym("fw"), A_FLOAT, 0);
	class_addmethod(radix_class, (t_method)radix_zoom
	, gensym("zoom"), A_CANT, 0);
	radix_widgetbehavior.w_getrectfn = radix_getrect;
	radix_widgetbehavior.w_displacefn = iemgui_displace;
	radix_widgetbehavior.w_selectfn = iemgui_select;
	radix_widgetbehavior.w_activatefn = NULL;
	radix_widgetbehavior.w_deletefn = iemgui_delete;
	radix_widgetbehavior.w_visfn = iemgui_vis;
	radix_widgetbehavior.w_clickfn = radix_newclick;
	class_setwidget(radix_class, &radix_widgetbehavior);
	class_setsavefn(radix_class, radix_save);
	class_setpropertiesfn(radix_class, radix_properties);
}
