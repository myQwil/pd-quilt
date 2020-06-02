/* Copyright (c) 1997-1999 Miller Puckette.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution. */

/* gradix.c written by Thomas Musil (c) IEM KUG Graz Austria 2000-2001 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include "m_pd.h"
#include "g_canvas.h"

#include "g_all_guis.h"
#include <math.h>
#include <float.h>
#include <limits.h>

typedef union {
	float f;
	struct { unsigned mnt:23,ex:8,sgn:1; } u;
	unsigned u32;
} ufloat;
#define mnt u.mnt
#define ex  u.ex
#define sgn u.sgn

#define MAX(a,b) ((a)>(b) ? (a):(b))
#define MIN(a,b) ((a)<(b) ? (a):(b))

#ifdef _WIN32
#define LEAD 3
#else
#define LEAD 2
#endif

#ifdef _WIN32
#include <io.h>
#else
#include <unistd.h>
#endif

#define MINDIGITS 0
#define MINFONT   4

// for a dark theme of pd
#undef PD_COLOR_FG
#undef PD_COLOR_BG
#undef PD_COLOR_SELECT
#undef PD_COLOR_EDIT
#define PD_COLOR_FG           0xFCFCFC
#define PD_COLOR_BG           0x000000
#define PD_COLOR_SELECT       0x00FFFF
#define PD_COLOR_EDIT         0xFF9999

typedef struct _gradix {
	t_iemgui x_gui;
	t_clock  *x_clock_reset;
	t_clock  *x_clock_wait;
	double   x_val;
	double   x_tog;
	double   x_min;
	double   x_max;
	double   x_k;
	char     x_buf[40];
	int      x_bufsize;
	int      x_newsize;
	int      x_numwidth;
	int      x_lin0_log1;
	int      x_log_height;
	int      x_zh;       // un-zoomed height
	int      x_base;     // radix
	int      x_prec;     // precision
	int      x_e;        // e-notation radix
	int      x_bexp;     // base exponent
	int      x_texp;     // power of 2 exponent
	unsigned x_pwr;      // largest base power inside of 32 bits
} t_gradix;

static const char dgt[] = {
	"0123456789abcdef"
	"ghijkmnopqrstuvw"
	"xyzACDEFGHJKLMNP"
	"QRTUVWXYZ?!@#$%&"
};

/*------------------ global functions -------------------------*/

static void gradix_key(void *z, t_floatarg fkey);
static void gradix_draw_update(t_gobj *client, t_glist *glist);

/* ------------ gradix gui-my number box ----------------------- */

t_widgetbehavior gradix_widgetbehavior;
static t_class *gradix_class;

/* widget helper functions */

static void gradix_tick_reset(t_gradix *x) {
	if (x->x_gui.x_fsf.x_change && x->x_gui.x_glist)
	{	x->x_gui.x_fsf.x_change = 0;
		sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }
}

static void gradix_tick_wait(t_gradix *x) {
	sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);
}

static void gradix_clip(t_gradix *x) {
	if (x->x_min || x->x_max)
	{	if      (x->x_val < x->x_min) x->x_val = x->x_min;
		else if (x->x_val > x->x_max) x->x_val = x->x_max;   }
}

static void gradix_calc_fontwidth(t_gradix *x) {
	int rad = x->x_zh * IEMGUI_ZOOM(x) * 0.6667;
	int w = x->x_numwidth;
	if (!w)
	{	w = x->x_bufsize;
		if (w < 3) w = 3;   }
	x->x_gui.x_w = w * glist_fontwidth(x->x_gui.x_glist) + rad;
}

static void gradix_precision(t_gradix *x, t_floatarg f) {
	int m = ceil(FLT_MANT_DIG / log2(x->x_base));
	if      (f < 1) f = 1;
	else if (f > m) f = m;
	x->x_prec = f;
}

static int gradix_bounds(t_float base) {
	int m = sizeof(dgt) / sizeof*(dgt);
	if      (base < 2) base = 2;
	else if (base > m) base = m;
	return base;
}

static void gradix_base(t_gradix *x, t_floatarg f) {
	unsigned base = x->x_base = gradix_bounds(f);
	unsigned umax = -1, pwr = 1;
	int bx = x->x_bexp = log(umax) / log(base), tx = 32;
	for (;bx; base *= base)
	{	if (bx & 1) pwr *= base;
		bx >>= 1;   }
	while (umax > pwr) { tx--; umax >>= 1; }
	x->x_pwr = pwr;
	x->x_texp = tx;
}

static void gradix_ebase(t_gradix *x, t_floatarg base) {
	x->x_e = gradix_bounds(base);
}

static void gradix_be(t_gradix *x, t_floatarg base) {
	gradix_base(x, base);
	x->x_e = x->x_base;
}

static void out(char num[], int *i, const char *s, int l) {
	for (; l--; s++) num[(*i)++] = *s;
}

static char *fmt_u(uintmax_t u, char *s, int radx) {
	unsigned long v;
	for (   ; u>ULONG_MAX; u/=radx) *--s = dgt[u%radx];
	for (v=u;           v; v/=radx) *--s = dgt[v%radx];
	return s;
}

static void gradix_ftoa(t_gradix *x) {
	ufloat uf = {.f=x->x_val};
	int size=0;
	if (uf.ex == 0xFF)
	{	int neg = uf.sgn;
		#ifdef _WIN32
			if (uf.mnt != 0)
			{	if (uf.mnt == 0x400000 && neg)
					size = 7, strcpy(x->x_buf, "-1.#IND");
				else size = 7+neg,
					 strcpy(x->x_buf, (neg ? "-1.#QNAN" : "1.#QNAN"));   }
			else size = 6+neg,
				 strcpy(x->x_buf, (neg ? "-1.#INF" : "1.#INF"));
		#else
			if (uf.mnt != 0) strcpy(x->x_buf, (neg?"-nan":"nan"));
			else strcpy(x->x_buf, (neg?"-inf":"inf"));
			size = 3+neg;
		#endif
		x->x_newsize = (x->x_bufsize != size);
		if (x->x_newsize) x->x_bufsize = size;
		return;   }

	long double y = x->x_val;
	int radx = x->x_base;
	unsigned pwr = x->x_pwr;
	int bx=x->x_bexp, tx=x->x_texp;
	int xb=bx-1, xt=tx-1;
	int neg=0, t='g';

	/* based on: musl-libc /src/stdio/vfprintf.c */
	unsigned bigsize = (LDBL_MANT_DIG+xt)/tx + 1    // mantissa expansion
		+ (LDBL_MAX_EXP+LDBL_MANT_DIG+xt+xb)/bx;    // exponent expansion
	uint32_t big[bigsize];
	uint32_t *a, *d, *r, *z;
	int e2=0, e, i, j, l;
	char buf[bx+LDBL_MANT_DIG/4];
	char ebuf0[3*sizeof(int)], *ebuf=&ebuf0[3*sizeof(int)], *estr;

	if (signbit(y)) y=-y, neg=1;
	int p = (x->x_numwidth && x->x_prec >= x->x_numwidth)
		  ? x->x_numwidth-neg : x->x_prec;

	y = frexpl(y, &e2) * 2;
	if (y) y *= (1<<xt), e2-=tx;

	if (e2<0) a=r=z=big;
	else a=r=z=big+sizeof(big)/sizeof(*big) - LDBL_MANT_DIG - 1;

	do
	{	*z = y;
		y = pwr*(y-*z++);   }
	while (y && --bigsize);

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
	{	uint32_t carry=0, *b;
		int sh=MIN(bx,-e2), need=1+(p+LDBL_MANT_DIG/3U+xb)/bx;
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

	if (a<z) for (i=radx, e=bx*(r-a); *a>=i; i*=radx, e++);
	else e=0;

	/* Perform rounding: j is precision after the radix (possibly neg) */
	j = p-e-1;
	if (j < bx*(z-r-1))
	{	uint32_t u;
		/* We avoid C's broken division of negative numbers */
		d = r + 1 + ((j+bx*LDBL_MAX_EXP)/bx - LDBL_MAX_EXP);
		j += bx*LDBL_MAX_EXP;
		j %= bx;
		for (i=radx, j++; j<bx; i*=radx, j++);
		u = *d % i;
		/* Are there any significant digits past j? */
		if (u || d+1!=z)
		{	long double round = 2/LDBL_EPSILON;
			long double small;
			if ((*d/i & 1) || (i==pwr && d>a && (d[-1]&1)))
				round += 2;
			if (u<i/2) small=0x0.8p0;
			else if (u==i/2 && d+1==z) small=0x1.0p0;
			else small=0x1.8p0;
			if (neg) round*=-1, small*=-1;
			*d -= u;
			/* Decide whether to round by probing round+small */
			if (round+small != round)
			{	*d = *d + i;
				while (*d > pwr-1)
				{	*d--=0;
					if (d<a) *--a=0;
					(*d)++;   }
				for (i=radx, e=bx*(r-a); *a>=i; i*=radx, e++);   }   }
		if (z>d+1) z=d+1;   }

	for (; z>a && !z[-1]; z--);

	if (!p) p++;
	if (p>e && e>=-4)
	{	t--; p-=e+1;   }
	else
	{	t-=2; p--;   }

	/* Count trailing zeros in last place */
	if (z>a && z[-1]) for (i=radx, j=0; z[-1]%i==0; i*=radx, j++);
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
		estr=fmt_u(e<0 ? -e : e, ebuf, erad);
		while(ebuf-estr<LEAD) *--estr='0';
		*--estr = (e<0 ? '-' : '+');
		*--estr = '^';
		l += ebuf-estr;   }

	char *num = x->x_buf, *dec=0, *nxt=0;
	int ni=0;
	out(num, &ni, "-", neg);

	if ((t|32)=='f')
	{	if (a>r) a=r;
		for (d=a; d<=r; d++)
		{	char *s = fmt_u(*d, buf+bx, radx);
			if (d!=a) while (s>buf) *--s='0';
			else if (s==buf+bx) *--s='0';
			out(num, &ni, s, buf+bx-s);   }
		if (p)
		{	dec = num+ni;
			out(num, &ni, ".", 1);   }
		for (; d<z && p>0; d++, p-=bx)
		{	char *s = fmt_u(*d, buf+bx, radx);
			while (s>buf) *--s='0';
			out(num, &ni, s, MIN(bx,p));   }   }
	else
	{	if (z<=a) z=a+1;
		for (d=a; d<z && p>=0; d++)
		{	char *s = fmt_u(*d, buf+bx, radx);
			if (s==buf+bx) *--s='0';
			if (d!=a) while (s>buf) *--s='0';
			else
			{	out(num, &ni, s++, 1);
				if (p>0)
				{	dec = num+ni;
					out(num, &ni, ".", 1);   }   }
			out(num, &ni, s, MIN(buf+bx-s, p));
			p -= buf+bx-s;   }
		nxt = num+ni;
		out(num, &ni, estr, ebuf-estr);   }
	num[ni] = '\0';
	size = ni;

	if (x->x_numwidth > 0 && ni > x->x_numwidth)
	{	if (!dec) dec = num+ni;
		if (!nxt) nxt = num+ni;
		int reduce = ni - x->x_numwidth;
		if (nxt-dec >= reduce)
		{	char *s1 = nxt-reduce;
			ebuf = num+ni;
			for (;nxt < ebuf; s1++, nxt++) *s1 = *nxt;
			*s1 = '\0';
			size = s1-num;   }
		else
		{	num[0] = (neg?'-':'+');
			num[1] = '\0';   }   }
	x->x_newsize = (x->x_bufsize != size);
	if (x->x_newsize) x->x_bufsize = size;
}

static void gradix_zoom(t_gradix *x, t_floatarg zoom) {
	t_iemgui *gui = &x->x_gui;
	int oldzoom = gui->x_glist->gl_zoom;
	if (oldzoom < 1) oldzoom = 1;
	gui->x_w = (int)(gui->x_w)/oldzoom*(int)zoom;
	gui->x_h = x->x_zh * (int)zoom - (zoom-1)*2;
}

static void gradix_border(t_gradix *x) {
	gradix_calc_fontwidth(x);
	t_glist *glist = x->x_gui.x_glist;
	int xpos = text_xpix(&x->x_gui.x_obj, glist);
	int ypos = text_ypix(&x->x_gui.x_obj, glist);
	int w = x->x_gui.x_w, h = x->x_gui.x_h, corner = h/4;
	t_canvas *canvas = glist_getcanvas(glist);

	sys_vgui(".x%lx.c coords %lxBASE1 %d %d %d %d %d %d %d %d %d %d %d %d\n",
		canvas, x,
		xpos, ypos,
		xpos + w - corner, ypos,
		xpos + w, ypos + corner,
		xpos + w, ypos + h,
		xpos, ypos + h,
		xpos, ypos);
}

static void gradix_draw_update(t_gobj *client, t_glist *glist) {
	t_gradix *x = (t_gradix *)client;
	if (glist_isvisible(glist))
	{	if (x->x_gui.x_fsf.x_change)
		{	if (x->x_buf[0])
			{	char *cp = x->x_buf;
				int sl = (int)strlen(x->x_buf);
				x->x_buf[sl] = '>';
				x->x_buf[sl+1] = 0;
				if (sl >= x->x_numwidth)
					cp += sl - x->x_numwidth + 1;
				sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x -text {%s} \n",
					glist_getcanvas(glist), x,
					PD_COLOR_EDIT, cp);
				x->x_buf[sl] = 0;   }
			else
			{	gradix_ftoa(x);
				if (!x->x_numwidth && x->x_newsize)
					gradix_border(x);
				sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x -text {%s} \n",
					glist_getcanvas(glist), x,
					PD_COLOR_EDIT, x->x_buf);
				x->x_buf[0] = 0;   }   }
		else
		{	gradix_ftoa(x);
			if (!x->x_numwidth && x->x_newsize)
				gradix_border(x);
			sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x -text {%s} \n",
				glist_getcanvas(glist), x,
				(x->x_gui.x_fsf.x_selected ? PD_COLOR_SELECT : x->x_gui.x_fcol),
				x->x_buf);
			x->x_buf[0] = 0;   }   }
}

static void gradix_draw_new(t_gradix *x, t_glist *glist) {
	int xpos = text_xpix(&x->x_gui.x_obj, glist);
	int ypos = text_ypix(&x->x_gui.x_obj, glist);
	int zoom = IEMGUI_ZOOM(x), iow = IOWIDTH * zoom, ioh = OHEIGHT * zoom;
	int w = x->x_gui.x_w, h = x->x_gui.x_h, d = zoom + h/(34*zoom);
	int half=h/2, rad=half-ioh, fine=zoom-1, corner = h/4;
	t_canvas *canvas = glist_getcanvas(glist);

	sys_vgui(".x%lx.c create line %d %d %d %d %d %d %d %d %d %d %d %d "
		" -width %d -fill #%06x -tags %lxBASE1\n",
		canvas,
		xpos, ypos,
		xpos + w - corner, ypos,
		xpos + w, ypos + corner,
		xpos + w, ypos + h,
		xpos, ypos + h,
		xpos, ypos,
		zoom, PD_COLOR_FG, x);
	sys_vgui(".x%lx.c create arc %d %d %d %d -start 270 -extent 180 -width %d "
		" -outline #%06x -tags %lxBASE2\n",
		canvas,
		xpos - rad, ypos + zoom + ioh,
		xpos + rad, ypos + h - zoom - ioh,
		zoom, x->x_gui.x_fcol, x);
	if (!x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags [list %lxOUT%d outlet]\n",
			canvas,
			xpos, ypos + h + zoom - ioh,
			xpos + iow, ypos + h,
			PD_COLOR_FG, x, 0);
	if (!x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags [list %lxIN%d inlet]\n",
			canvas,
			xpos, ypos,
			xpos + iow, ypos - zoom + ioh,
			PD_COLOR_FG, x, 0);
	sys_vgui(".x%lx.c create text %d %d -text {%s} -anchor w "
		" -font {{%s} -%d %s} -fill #%06x -tags [list %lxLABEL label text]\n",
		canvas, xpos + x->x_gui.x_ldx * zoom,
		ypos + x->x_gui.x_ldy * zoom + fine*2,
		(strcmp(x->x_gui.x_lab->s_name, "empty") ? x->x_gui.x_lab->s_name : ""),
		x->x_gui.x_font, x->x_gui.x_fontsize * zoom, sys_fontweight,
		x->x_gui.x_lcol, x);
	gradix_ftoa(x);
	sys_vgui(".x%lx.c create text %d %d -text {%s} -anchor w "
		" -font {{%s} -%d %s} -fill #%06x -tags %lxNUMBER\n",
		canvas, xpos + half + 2*zoom, ypos + half + d,
		x->x_buf, x->x_gui.x_font, x->x_gui.x_fontsize * zoom,
		sys_fontweight, (x->x_gui.x_fsf.x_change ?
		PD_COLOR_EDIT : x->x_gui.x_fcol), x);
}

static void gradix_draw_move(t_gradix *x, t_glist *glist) {
	int xpos = text_xpix(&x->x_gui.x_obj, glist);
	int ypos = text_ypix(&x->x_gui.x_obj, glist);
	int zoom = IEMGUI_ZOOM(x), iow = IOWIDTH * zoom, ioh = OHEIGHT * zoom;
	int w = x->x_gui.x_w, h = x->x_gui.x_h, d = zoom + h/(34*zoom);
	int half=h/2, rad=half-ioh, fine=zoom-1, corner = h/4;
	t_canvas *canvas = glist_getcanvas(glist);

	sys_vgui(".x%lx.c coords %lxBASE1 %d %d %d %d %d %d %d %d %d %d %d %d\n",
		canvas, x,
		xpos, ypos,
		xpos + w - corner, ypos,
		xpos + w, ypos + corner,
		xpos + w, ypos + h,
		xpos, ypos + h,
		xpos, ypos);
	sys_vgui(".x%lx.c coords %lxBASE2 %d %d %d %d\n",
		canvas, x,
		xpos - rad, ypos + zoom + ioh,
		xpos + rad, ypos + h - zoom - ioh);
	if (!x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c coords %lxOUT%d %d %d %d %d\n",
			canvas, x, 0,
			xpos, ypos + h + zoom - ioh,
			xpos + iow, ypos + h);
	if (!x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c coords %lxIN%d %d %d %d %d\n",
			canvas, x, 0,
			xpos, ypos,
			xpos + iow, ypos - zoom + ioh);
	sys_vgui(".x%lx.c coords %lxLABEL %d %d\n",
		canvas, x,
		xpos + x->x_gui.x_ldx * zoom,
		ypos + x->x_gui.x_ldy * zoom);
	sys_vgui(".x%lx.c coords %lxNUMBER %d %d\n",
		canvas, x, xpos + half + 2*zoom, ypos + half + d);
}

static void gradix_draw_erase(t_gradix* x, t_glist* glist) {
	t_canvas *canvas = glist_getcanvas(glist);
	sys_vgui(".x%lx.c delete %lxBASE1\n", canvas, x);
	sys_vgui(".x%lx.c delete %lxBASE2\n", canvas, x);
	sys_vgui(".x%lx.c delete %lxLABEL\n", canvas, x);
	sys_vgui(".x%lx.c delete %lxNUMBER\n", canvas, x);
	if (!x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c delete %lxOUT%d\n", canvas, x, 0);
	if (!x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c delete %lxIN%d\n", canvas, x, 0);
}

static void gradix_draw_config(t_gradix* x, t_glist* glist) {
	t_canvas *canvas = glist_getcanvas(glist);
	sys_vgui(".x%lx.c itemconfigure %lxLABEL -font {{%s} -%d %s} "
		" -fill #%06x -text {%s} \n",
		canvas, x,
		x->x_gui.x_font, x->x_gui.x_fontsize * IEMGUI_ZOOM(x), sys_fontweight,
		x->x_gui.x_lcol,
		strcmp(x->x_gui.x_lab->s_name, "empty") ? x->x_gui.x_lab->s_name:"");
	sys_vgui(".x%lx.c itemconfigure %lxNUMBER -font {{%s} -%d %s} -fill #%06x \n",
		canvas, x,
		x->x_gui.x_font, x->x_gui.x_fontsize * IEMGUI_ZOOM(x), sys_fontweight,
		(x->x_gui.x_fsf.x_selected ? PD_COLOR_SELECT : x->x_gui.x_fcol));
	sys_vgui(".x%lx.c itemconfigure %lxBASE1 -fill #%06x\n", canvas, x,
		PD_COLOR_FG);
	sys_vgui(".x%lx.c itemconfigure %lxBASE2 -outline #%06x\n", canvas, x,
		(x->x_gui.x_fsf.x_selected ? PD_COLOR_SELECT : x->x_gui.x_fcol));
}

static void gradix_draw_io(t_gradix* x,t_glist* glist, int old_snd_rcv_flags) {
	int xpos = text_xpix(&x->x_gui.x_obj, glist);
	int ypos = text_ypix(&x->x_gui.x_obj, glist);
	int zoom = IEMGUI_ZOOM(x), iow = IOWIDTH * zoom, ioh = OHEIGHT * zoom;
	t_canvas *canvas = glist_getcanvas(glist);

	if ((old_snd_rcv_flags & IEM_GUI_OLD_SND_FLAG) && !x->x_gui.x_fsf.x_snd_able)
	{	sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags %lxOUT%d\n",
			canvas,
			xpos, ypos + x->x_gui.x_h + zoom - ioh,
			xpos + iow, ypos + x->x_gui.x_h,
			PD_COLOR_FG, x, 0);
		/* keep these above outlet */
		sys_vgui(".x%lx.c raise %lxLABEL %lxOUT%d\n", canvas, x, x, 0);
		sys_vgui(".x%lx.c raise %lxNUMBER %lxLABEL\n", canvas, x, x);   }
	if (!(old_snd_rcv_flags & IEM_GUI_OLD_SND_FLAG) && x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c delete %lxOUT%d\n", canvas, x, 0);
	if ((old_snd_rcv_flags & IEM_GUI_OLD_RCV_FLAG) && !x->x_gui.x_fsf.x_rcv_able)
	{	sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags %lxIN%d\n",
			canvas,
			xpos, ypos,
			xpos + iow, ypos - zoom + ioh,
			PD_COLOR_FG, x, 0);
		/* keep these above inlet */
		sys_vgui(".x%lx.c raise %lxLABEL %lxIN%d\n", canvas, x, x, 0);
		sys_vgui(".x%lx.c raise %lxNUMBER %lxLABEL\n", canvas, x, x);   }
	if (!(old_snd_rcv_flags & IEM_GUI_OLD_RCV_FLAG) && x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c delete %lxIN%d\n", canvas, x, 0);
}

static void gradix_draw_select(t_gradix *x, t_glist *glist) {
	t_canvas *canvas = glist_getcanvas(glist);

	if (x->x_gui.x_fsf.x_selected)
	{	if (x->x_gui.x_fsf.x_change)
		{	x->x_gui.x_fsf.x_change = 0;
			clock_unset(x->x_clock_reset);
			x->x_buf[0] = 0;
			sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }
		sys_vgui(".x%lx.c itemconfigure %lxBASE1 -fill #%06x\n",
			canvas, x, PD_COLOR_SELECT);
		sys_vgui(".x%lx.c itemconfigure %lxBASE2 -outline #%06x\n",
			canvas, x, PD_COLOR_SELECT);
		sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x\n",
			canvas, x, PD_COLOR_SELECT);   }
	else
	{	sys_vgui(".x%lx.c itemconfigure %lxBASE1 -fill #%06x\n",
			canvas, x, PD_COLOR_FG);
		sys_vgui(".x%lx.c itemconfigure %lxBASE2 -outline #%06x\n",
			canvas, x, x->x_gui.x_fcol);
		sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x\n",
			canvas, x, x->x_gui.x_fcol);   }
}

static void gradix_draw(t_gradix *x, t_glist *glist, int mode) {
	if (mode == IEM_GUI_DRAW_MODE_UPDATE)
		sys_queuegui(x, glist, gradix_draw_update);
	else if (mode == IEM_GUI_DRAW_MODE_MOVE)
		gradix_draw_move(x, glist);
	else if (mode == IEM_GUI_DRAW_MODE_NEW)
		gradix_draw_new(x, glist);
	else if (mode == IEM_GUI_DRAW_MODE_SELECT)
		gradix_draw_select(x, glist);
	else if (mode == IEM_GUI_DRAW_MODE_ERASE)
		gradix_draw_erase(x, glist);
	else if (mode == IEM_GUI_DRAW_MODE_CONFIG)
		gradix_draw_config(x, glist);
	else if (mode >= IEM_GUI_DRAW_MODE_IO)
		gradix_draw_io(x, glist, mode - IEM_GUI_DRAW_MODE_IO);
}

/* ------------------------ gradix widgetbehaviour----------------------------- */

static void gradix_getrect
(t_gobj *z, t_glist *glist, int *xp1, int *yp1, int *xp2, int *yp2) {
	t_gradix* x = (t_gradix*)z;
	*xp1 = text_xpix(&x->x_gui.x_obj, glist);
	*yp1 = text_ypix(&x->x_gui.x_obj, glist);
	*xp2 = *xp1 + x->x_gui.x_w;
	*yp2 = *yp1 + x->x_gui.x_h;
}

static void gradix_save(t_gobj *z, t_binbuf *b) {
	t_gradix *x = (t_gradix *)z;
	t_symbol *bflcol[3];
	t_symbol *srl[3];

	iemgui_save(&x->x_gui, srl, bflcol);
	if (x->x_gui.x_fsf.x_change)
	{	x->x_gui.x_fsf.x_change = 0;
		clock_unset(x->x_clock_reset);
		sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }
	binbuf_addv(b, "ssiisiiffiisssiiiisssiiifi", gensym("#X"), gensym("obj"),
		(int)x->x_gui.x_obj.te_xpix, (int)x->x_gui.x_obj.te_ypix,
		gensym("gradix"), x->x_numwidth, x->x_zh,
		(t_float)x->x_min, (t_float)x->x_max, x->x_lin0_log1,
		iem_symargstoint(&x->x_gui.x_isa), srl[0], srl[1], srl[2],
		x->x_gui.x_ldx, x->x_gui.x_ldy,
		iem_fstyletoint(&x->x_gui.x_fsf), x->x_gui.x_fontsize,
		bflcol[0], bflcol[1], bflcol[2],
		x->x_base, x->x_prec, x->x_e, x->x_val, x->x_log_height);
	binbuf_addv(b, ";");
}

static int gradix_check_minmax(t_gradix *x, double min, double max) {
	int ret = 0;
	if (x->x_lin0_log1)
	{	if (min==0.0 && max==0.0)
			max = 1.0;
		if (max > 0.0)
		{	if (min <= 0.0)
				min = 0.01 * max;   }
		else
		{	if (min > 0.0)
				max = 0.01 * min;   }   }
	else if (min==0.0 && max==0.0)
		return(ret);
	x->x_min = min;
	x->x_max = max;
	if (x->x_val < x->x_min)
	{	x->x_val = x->x_min;
		ret = 1;   }
	else if (x->x_val > x->x_max)
	{	x->x_val = x->x_max;
		ret = 1;   }
	if (x->x_lin0_log1)
		x->x_k = exp(log(x->x_max/x->x_min) / (double)(x->x_log_height));
	else x->x_k = 1.0;
	return(ret);
}

static void gradix_properties(t_gobj *z, t_glist *owner) {
	t_gradix *x = (t_gradix *)z;
	char buf[800];
	t_symbol *srl[3];

	iemgui_properties(&x->x_gui, srl);
	if (x->x_gui.x_fsf.x_change)
	{	x->x_gui.x_fsf.x_change = 0;
		clock_unset(x->x_clock_reset);
		sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }
	sprintf(buf, "pdtk_iemgui_dialog %%s |gradix| \
			-------dimensions(digits)(pix):------- %d %d width: %d %d height: \
			-----------output-range:----------- %g min: %g max: %d \
			%d lin log %d %d log-height: %d \
			%s %s \
			%s %d %d \
			%d %d \
			#%06x #%06x #%06x\n",
			x->x_numwidth, MINDIGITS, x->x_zh, IEM_GUI_MINSIZE,
			x->x_min, x->x_max, 0,/*no_schedule*/
			x->x_lin0_log1, x->x_gui.x_isa.x_loadinit, -1,
				x->x_log_height, /*no multi, but iem-characteristic*/
			srl[0]->s_name, srl[1]->s_name,
			srl[2]->s_name, x->x_gui.x_ldx, x->x_gui.x_ldy,
			x->x_gui.x_fsf.x_font_style, x->x_gui.x_fontsize,
			0xffffff & x->x_gui.x_bcol, 0xffffff & x->x_gui.x_fcol,
				0xffffff & x->x_gui.x_lcol);
	gfxstub_new(&x->x_gui.x_obj.ob_pd, x, buf);
}

static void gradix_bang(t_gradix *x) {
	outlet_float(x->x_gui.x_obj.ob_outlet, x->x_val);
	if (x->x_gui.x_fsf.x_snd_able && x->x_gui.x_snd->s_thing)
		pd_float(x->x_gui.x_snd->s_thing, x->x_val);
}

static void gradix_dialog(t_gradix *x, t_symbol *s, int argc, t_atom *argv) {
	t_symbol *srl[3];
	int w = (int)atom_getfloatarg(0, argc, argv);
	int h = (int)atom_getfloatarg(1, argc, argv);
	double min = (double)atom_getfloatarg(2, argc, argv);
	double max = (double)atom_getfloatarg(3, argc, argv);
	int lilo = (int)atom_getfloatarg(4, argc, argv);
	int log_height = (int)atom_getfloatarg(6, argc, argv);
	int sr_flags;

	if (lilo != 0) lilo = 1;
	x->x_lin0_log1 = lilo;
	sr_flags = iemgui_dialog(&x->x_gui, srl, argc, argv);
	if (w < MINDIGITS) w = MINDIGITS;
	x->x_numwidth = w;
	if (h < IEM_GUI_MINSIZE) h = IEM_GUI_MINSIZE;
	x->x_zh = h;
	x->x_gui.x_h = h * IEMGUI_ZOOM(x) - (IEMGUI_ZOOM(x)-1)*2;
	if (log_height < 10)
		log_height = 10;
	x->x_log_height = log_height;
	gradix_calc_fontwidth(x);
	/*if (gradix_check_minmax(x, min, max))
	 gradix_bang(x);*/
	gradix_check_minmax(x, min, max);
	(*x->x_gui.x_draw)(x, x->x_gui.x_glist, IEM_GUI_DRAW_MODE_UPDATE);
	(*x->x_gui.x_draw)(x, x->x_gui.x_glist, IEM_GUI_DRAW_MODE_IO + sr_flags);
	(*x->x_gui.x_draw)(x, x->x_gui.x_glist, IEM_GUI_DRAW_MODE_CONFIG);
	(*x->x_gui.x_draw)(x, x->x_gui.x_glist, IEM_GUI_DRAW_MODE_MOVE);
	canvas_fixlinesfor (x->x_gui.x_glist, (t_text*)x);
}

static void gradix_motion(t_gradix *x, t_floatarg dx, t_floatarg dy) {
	double k2 = 1.0;
	ufloat uf = {.f = x->x_val};
	if (uf.ex > 148) k2 *= pow(2, uf.ex - 148);
	if (x->x_gui.x_fsf.x_finemoved)
		k2 /= (double)(x->x_base * x->x_base);

	if (x->x_lin0_log1)
		x->x_val *= pow(x->x_k, -k2*dy);
	else x->x_val -= k2*dy;
	gradix_clip(x);
	sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);
	gradix_bang(x);
	clock_unset(x->x_clock_reset);
}

static void gradix_set(t_gradix *x, t_floatarg f) {
	ufloat uf = {.f = f}, vf = {.f = x->x_val};
	if (uf.u32 != vf.u32)
	{	x->x_val = f;
		gradix_clip(x);
		sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }
}

static void gradix_float(t_gradix *x, t_float f) {
	gradix_set(x, f);
	if (x->x_gui.x_fsf.x_put_in2out)
		gradix_bang(x);
}

static void gradix_click(t_gradix *x, t_floatarg xpos, t_floatarg ypos,
 t_floatarg shift, t_floatarg ctrl, t_floatarg alt) {
	if (alt)
	{	if (x->x_val != 0)
		{	x->x_tog = x->x_val;
			gradix_float(x, 0);
			return;   }
		else gradix_float(x, x->x_tog);   }
	glist_grab(x->x_gui.x_glist, &x->x_gui.x_obj.te_g,
		(t_glistmotionfn)gradix_motion, gradix_key, xpos, ypos);
}

static int gradix_newclick(t_gobj *z, struct _glist *glist,
 int xpix, int ypix, int shift, int alt, int dbl, int doit) {
	t_gradix* x = (t_gradix *)z;
	if (doit)
	{	gradix_click( x, (t_floatarg)xpix, (t_floatarg)ypix,
			(t_floatarg)shift, 0, (t_floatarg)alt);
		x->x_gui.x_fsf.x_finemoved = (shift != 0);
		if (!x->x_gui.x_fsf.x_change)
		{	clock_delay(x->x_clock_wait, 50);
			x->x_gui.x_fsf.x_change = 1;
			clock_delay(x->x_clock_reset, 3000);
			x->x_buf[0] = 0;   }
		else
		{	x->x_gui.x_fsf.x_change = 0;
			clock_unset(x->x_clock_reset);
			x->x_buf[0] = 0;
			sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }   }
	return (1);
}

static void gradix_log_height(t_gradix *x, t_floatarg lh) {
	if (lh < 10.0) lh = 10.0;
	x->x_log_height = (int)lh;
	if (x->x_lin0_log1)
		x->x_k = exp(log(x->x_max/x->x_min)/(double)(x->x_log_height));
	else x->x_k = 1.0;
}

static void gradix_size(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	int h, w;
	w = (int)atom_getfloatarg(0, ac, av);
	if (w < MINDIGITS) w = MINDIGITS;
	x->x_numwidth = w;
	if (ac > 1)
	{	h = (int)atom_getfloatarg(1, ac, av);
		if (h < IEM_GUI_MINSIZE) h = IEM_GUI_MINSIZE;
		x->x_zh = h;
		x->x_gui.x_h = h * IEMGUI_ZOOM(x) - (IEMGUI_ZOOM(x)-1)*2;   }
	gradix_calc_fontwidth(x);
	iemgui_size((void *)x, &x->x_gui);
}

static void gradix_delta(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_delta((void *)x, &x->x_gui, s, ac, av);
}

static void gradix_pos(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_pos((void *)x, &x->x_gui, s, ac, av);
}

static void gradix_range(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	if (gradix_check_minmax(x, (double)atom_getfloatarg(0, ac, av),
	                           (double)atom_getfloatarg(1, ac, av)))
	{	sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);
		/*gradix_bang(x);*/   }
}

static void gradix_color(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_color((void *)x, &x->x_gui, s, ac, av);
}

static void gradix_send(t_gradix *x, t_symbol *s) {
	iemgui_send(x, &x->x_gui, s);
}

static void gradix_receive(t_gradix *x, t_symbol *s) {
	iemgui_receive(x, &x->x_gui, s);
}

static void gradix_label(t_gradix *x, t_symbol *s) {
	iemgui_label((void *)x, &x->x_gui, s);
}

static void gradix_label_pos(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	iemgui_label_pos((void *)x, &x->x_gui, s, ac, av);
}

static void gradix_label_font(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	int f = (int)atom_getfloatarg(1, ac, av);
	if (f < 4) f = 4;
	x->x_gui.x_fontsize = f;
	f = (int)atom_getfloatarg(0, ac, av);
	if (f<0 || f>2) f = 0;
	x->x_gui.x_fsf.x_font_style = f;
	gradix_calc_fontwidth(x);
	iemgui_label_font((void *)x, &x->x_gui, s, ac, av);
}

static void gradix_log(t_gradix *x) {
	x->x_lin0_log1 = 1;
	if (gradix_check_minmax(x, x->x_min, x->x_max))
	{	sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);
		/*gradix_bang(x);*/   }
}

static void gradix_lin(t_gradix *x) {
	x->x_lin0_log1 = 0;
}

static void gradix_init(t_gradix *x, t_floatarg f) {
	x->x_gui.x_isa.x_loadinit = (f == 0.0) ? 0 : 1;
}

static void gradix_loadbang(t_gradix *x, t_floatarg action) {
	if (action == LB_LOAD && x->x_gui.x_isa.x_loadinit)
	{	sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);
		gradix_bang(x);   }
}

static void gradix_key(void *z, t_floatarg fkey) {
	t_gradix *x = z;
	char c = fkey;
	char buf[3];
	buf[1] = 0;

	if (c == 0)
	{	x->x_gui.x_fsf.x_change = 0;
		clock_unset(x->x_clock_reset);
		sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);
		return;   }
	if ((c>='0' && c<='9') || c=='.' || c=='-' || c=='e' || c=='+' || c=='E')
	{	if (strlen(x->x_buf) < (IEMGUI_MAX_NUM_LEN-2))
		{	buf[0] = c;
			strcat(x->x_buf, buf);
			sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }   }
	else if ((c == '\b') || (c == 127))
	{	int sl = (int)strlen(x->x_buf) - 1;
		if (sl < 0)
			sl = 0;
		x->x_buf[sl] = 0;
		sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }
	else if ((c == '\n') || (c == 13))
	{	x->x_val = atof(x->x_buf);
		x->x_buf[0] = 0;
		x->x_gui.x_fsf.x_change = 0;
		clock_unset(x->x_clock_reset);
		gradix_clip(x);
		gradix_bang(x);
		sys_queuegui(x, x->x_gui.x_glist, gradix_draw_update);   }
	clock_delay(x->x_clock_reset, 3000);
}

static void gradix_list(t_gradix *x, t_symbol *s, int ac, t_atom *av) {
	if (!ac) gradix_bang(x);
	else if (IS_A_FLOAT(av, 0))
	{	gradix_set(x, atom_getfloatarg(0, ac, av));
		gradix_bang(x);   }
}

static void *gradix_new(t_symbol *s, int argc, t_atom *argv) {
	t_gradix *x = (t_gradix *)pd_new(gradix_class);
	int w = 5, h = 22;
	int lilo = 0, ldx = -1, ldy = -10;
	int fs = 11;
	int log_height = 256;
	double min = 0, max = 0, v = 0.0;
	int base=0, prec=0, e=0;

	x->x_gui.x_bcol = PD_COLOR_BG;
	x->x_gui.x_fcol = PD_COLOR_FG;
	x->x_gui.x_lcol = PD_COLOR_FG;

	if (argc>=20 && IS_A_FLOAT(argv,0) && IS_A_FLOAT(argv,1)
	 && IS_A_FLOAT(argv,2) && IS_A_FLOAT(argv,3)
	 && IS_A_FLOAT(argv,4) && IS_A_FLOAT(argv,5)
	 && (IS_A_SYMBOL(argv,6) || IS_A_FLOAT(argv,6))
	 && (IS_A_SYMBOL(argv,7) || IS_A_FLOAT(argv,7))
	 && (IS_A_SYMBOL(argv,8) || IS_A_FLOAT(argv,8))
	 && IS_A_FLOAT(argv,9) && IS_A_FLOAT(argv,10)
	 && IS_A_FLOAT(argv,11) && IS_A_FLOAT(argv,12) && IS_A_FLOAT(argv,16))
	{	w = (int)atom_getfloatarg(0, argc, argv);
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
		iemgui_all_loadcolors(&x->x_gui, argv+13, argv+14, argv+15);
		base = (int)atom_getfloatarg(16, argc, argv);
		prec = (int)atom_getfloatarg(17, argc, argv);
		e = (int)atom_getfloatarg(18, argc, argv);
		v = atom_getfloatarg(19, argc, argv);   }
	else iemgui_new_getnames(&x->x_gui, 6, 0);

	if (argc>=1 && argc<=3)
	{	base = (int)atom_getfloatarg(0, argc, argv);
		prec = (int)atom_getfloatarg(1, argc, argv);
		e    = (int)atom_getfloatarg(2, argc, argv);   }
	gradix_base(x, base ? base : 16);
	gradix_precision(x, prec ? prec : 6);
	x->x_e = e ? gradix_bounds(e) : x->x_base;

	if (argc==21 && IS_A_FLOAT(argv,20))
		log_height = (int)atom_getfloatarg(20, argc, argv);
	x->x_gui.x_draw = (t_iemfunptr)gradix_draw;
	x->x_gui.x_fsf.x_snd_able = 1;
	x->x_gui.x_fsf.x_rcv_able = 1;
	x->x_gui.x_glist = (t_glist *)canvas_getcurrent();
	if (x->x_gui.x_isa.x_loadinit)
		x->x_val = v;
	else x->x_val = 0.0;

	if (lilo != 0) lilo = 1;
	x->x_lin0_log1 = lilo;
	if (log_height < 10) log_height = 10;
	x->x_log_height = log_height;

	if (!strcmp(x->x_gui.x_snd->s_name, "empty")) x->x_gui.x_fsf.x_snd_able = 0;
	if (!strcmp(x->x_gui.x_rcv->s_name, "empty")) x->x_gui.x_fsf.x_rcv_able = 0;

	switch (x->x_gui.x_fsf.x_font_style)
	{	case 2: strcpy(x->x_gui.x_font, "times"); break;
		case 1: strcpy(x->x_gui.x_font, "helvetica"); break;
		default: x->x_gui.x_fsf.x_font_style = 0;
			strcpy(x->x_gui.x_font, sys_font);   }

	if (x->x_gui.x_fsf.x_rcv_able)
		pd_bind(&x->x_gui.x_obj.ob_pd, x->x_gui.x_rcv);
	x->x_gui.x_ldx = ldx;
	x->x_gui.x_ldy = ldy;

	if (fs < MINFONT) fs = MINFONT;
	x->x_gui.x_fontsize = fs;
	if (w < MINDIGITS) w = MINDIGITS;
	x->x_numwidth = w;
	if (h < IEM_GUI_MINSIZE) h = IEM_GUI_MINSIZE;
	x->x_gui.x_h = x->x_zh = h;

	x->x_buf[0] = 0;
	gradix_check_minmax(x, min, max);
	iemgui_verify_snd_ne_rcv(&x->x_gui);
	x->x_clock_reset = clock_new(x, (t_method)gradix_tick_reset);
	x->x_clock_wait = clock_new(x, (t_method)gradix_tick_wait);
	x->x_gui.x_fsf.x_change = 0;
	iemgui_newzoom(&x->x_gui);
	gradix_calc_fontwidth(x);
	outlet_new(&x->x_gui.x_obj, &s_float);
	return (x);
}

static void gradix_free(t_gradix *x) {
	if (x->x_gui.x_fsf.x_rcv_able)
		pd_unbind(&x->x_gui.x_obj.ob_pd, x->x_gui.x_rcv);
	clock_free(x->x_clock_reset);
	clock_free(x->x_clock_wait);
	gfxstub_deleteforkey(x);
}

void gradix_setup(void) {
	gradix_class = class_new(gensym("gradix"), (t_newmethod)gradix_new,
		(t_method)gradix_free, sizeof(t_gradix), 0, A_GIMME, 0);
	class_addbang(gradix_class, gradix_bang);
	class_addfloat(gradix_class, gradix_float);
	class_addlist(gradix_class, gradix_list);
	class_addmethod(gradix_class, (t_method)gradix_click,
		gensym("click"), A_FLOAT, A_FLOAT, A_FLOAT, A_FLOAT, A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_motion,
		gensym("motion"), A_FLOAT, A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_dialog,
		gensym("dialog"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_loadbang,
		gensym("loadbang"), A_DEFFLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_set,
		gensym("set"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_size,
		gensym("size"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_delta,
		gensym("delta"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_pos,
		gensym("pos"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_range,
		gensym("range"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_color,
		gensym("color"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_send,
		gensym("send"), A_DEFSYM, 0);
	class_addmethod(gradix_class, (t_method)gradix_receive,
		gensym("receive"), A_DEFSYM, 0);
	class_addmethod(gradix_class, (t_method)gradix_label,
		gensym("label"), A_DEFSYM, 0);
	class_addmethod(gradix_class, (t_method)gradix_label_pos,
		gensym("label_pos"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_label_font,
		gensym("label_font"), A_GIMME, 0);
	class_addmethod(gradix_class, (t_method)gradix_log,
		gensym("log"), 0);
	class_addmethod(gradix_class, (t_method)gradix_lin,
		gensym("lin"), 0);
	class_addmethod(gradix_class, (t_method)gradix_init,
		gensym("init"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_log_height,
		gensym("log_height"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_base,
		gensym("base"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_base,
		gensym("b"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_ebase,
		gensym("e"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_be,
		gensym("be"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_precision,
		gensym("p"), A_FLOAT, 0);
	class_addmethod(gradix_class, (t_method)gradix_zoom,
		gensym("zoom"), A_CANT, 0);
	gradix_widgetbehavior.w_getrectfn =    gradix_getrect;
	gradix_widgetbehavior.w_displacefn =   iemgui_displace;
	gradix_widgetbehavior.w_selectfn =     iemgui_select;
	gradix_widgetbehavior.w_activatefn =   NULL;
	gradix_widgetbehavior.w_deletefn =     iemgui_delete;
	gradix_widgetbehavior.w_visfn =        iemgui_vis;
	gradix_widgetbehavior.w_clickfn =      gradix_newclick;
	class_setwidget(gradix_class, &gradix_widgetbehavior);
	class_sethelpsymbol(gradix_class, gensym("numbox2"));
	class_setsavefn(gradix_class, gradix_save);
	class_setpropertiesfn(gradix_class, gradix_properties);
}
