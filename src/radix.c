/* Copyright (c) 1997-1999 Miller Puckette.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution. */

/* my_numbox.c written by Thomas Musil (c) IEM KUG Graz Austria 2000-2001 */

#include "radix.h"

typedef struct {
	t_radix z;
	double  x_fontwidth;
	int     x_zh;         // un-zoomed height
} t_radixtcl;

/* --------------- radix gui number box ----------------------- */
static t_class *radix_class;
t_widgetbehavior radix_widgetbehavior;


static void radix_borderwidth(t_radix *x ,t_float zoom) {
	t_radixtcl *y = (t_radixtcl*)x;
	int n = x->x_numwidth ? x->x_numwidth : x->x_buflen;
  #ifdef __APPLE__
	x->x_gui.x_w = n * y->x_fontwidth * zoom;
  #else
	x->x_gui.x_w = n * round(y->x_fontwidth * zoom);
  #endif
	x->x_gui.x_w += (y->x_zh/2 + 3) * zoom;
}

static void radix_zoom(t_radix *x ,t_float zoom) {
	t_iemgui *gui = &x->x_gui;
	int oldzoom = gui->x_glist->gl_zoom;
	if (oldzoom < 1) oldzoom = 1;
	gui->x_h = ((t_radixtcl*)x)->x_zh * zoom - (zoom-1)*2;
	radix_borderwidth(x ,zoom);
}

static void radix_resize(t_radix *x) {
	radix_borderwidth(x ,IEMGUI_ZOOM(x));
	t_glist *glist = x->x_gui.x_glist;
	int xpos = text_xpix(&x->x_gui.x_obj ,glist);
	int ypos = text_ypix(&x->x_gui.x_obj ,glist);
	int w = x->x_gui.x_w ,h = x->x_gui.x_h ,corner = h/4;
	t_canvas *canvas = glist_getcanvas(glist);

	sys_vgui(".x%lx.c coords %lxBASE1 %d %d %d %d %d %d %d %d %d %d %d %d\n"
		,canvas ,x
		,xpos ,ypos
		,xpos + w - corner ,ypos
		,xpos + w ,ypos + corner
		,xpos + w ,ypos + h
		,xpos ,ypos + h
		,xpos ,ypos);
}

static void radix_draw_config(t_radix* x ,t_glist* glist) {
	t_canvas *canvas = glist_getcanvas(glist);
	sys_vgui(".x%lx.c itemconfigure %lxLABEL -font {{%s} -%d %s} "
		" -fill #%06x -text {%s} \n"
		,canvas ,x
		,x->x_gui.x_font ,x->x_gui.x_fontsize * IEMGUI_ZOOM(x) ,sys_fontweight
		,x->x_gui.x_lcol
		,strcmp(x->x_gui.x_lab->s_name ,"empty") ? x->x_gui.x_lab->s_name:"");
	sys_vgui(".x%lx.c itemconfigure %lxNUMBER -font {{%s} -%d %s} -fill #%06x \n"
		,canvas ,x
		,x->x_gui.x_font ,x->x_gui.x_fontsize * IEMGUI_ZOOM(x) ,sys_fontweight
		,(x->x_gui.x_fsf.x_selected ? PD_COLOR_SELECT : x->x_gui.x_fcol));
	sys_vgui(".x%lx.c itemconfigure %lxBASE1 -fill #%06x\n" ,canvas ,x
		,x->x_gui.x_bcol);
	sys_vgui(".x%lx.c itemconfigure %lxBASE2 -outline #%06x\n" ,canvas ,x
		,(x->x_gui.x_fsf.x_selected ? PD_COLOR_SELECT : x->x_gui.x_bcol));
}

static void radix_calc_fontwidth(t_radix *x) {
	double fwid = x->x_gui.x_fontsize;
	#ifdef _WIN32
		if (x->x_gui.x_fsf.x_font_style == 2)
			fwid *= 0.5;          // times
		else if (x->x_gui.x_fsf.x_font_style == 1)
			fwid *= 0.556123; // helvetica
		else fwid *= 0.6021;     // dejavu
	#elif defined(__APPLE__)
		if (x->x_gui.x_fsf.x_font_style == 2)
			fwid *= 0.5717;       // times
		else if (x->x_gui.x_fsf.x_font_style == 1)
			fwid *= 0.61111;  // helvetica
		else fwid *= 0.63636;    // dejavu
		//else fwid *= 0.61;     // monaco
	#else
		if (x->x_gui.x_fsf.x_font_style == 2)
			fwid *= 0.6018;       // times
		else if (x->x_gui.x_fsf.x_font_style == 1)
			fwid *= 0.6692;   // helvetica
		else fwid *= 0.724623;   // dejavu
	#endif
	((t_radixtcl*)x)->x_fontwidth = fwid;
}

static void radix_fontsize(t_radix *x ,t_float f) {
	if (f <= 0) f = 1;
	x->x_gui.x_fontsize = f;
	radix_draw_config(x ,x->x_gui.x_glist);
	radix_calc_fontwidth(x);
	radix_resize(x);
}

static void radix_fontwidth(t_radix *x ,t_float f) {
	((t_radixtcl*)x)->x_fontwidth = f;
	radix_resize(x);
}

static void radix_draw_update(t_gobj *client ,t_glist *glist) {
	t_radix *x = (t_radix*)client;
	if (!glist_isvisible(glist)) return;
	if (x->x_gui.x_change)
	{	if (x->x_buf[0])
		{	char *cp = x->x_buf;
			unsigned sl = strlen(x->x_buf);
			x->x_buf[sl] = '>';
			x->x_buf[sl+1] = 0;
			if (sl >= x->x_numwidth)
				cp += sl - x->x_numwidth + 1;
			sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x -text {%s} \n"
				,glist_getcanvas(glist) ,x ,PD_COLOR_EDIT ,cp);
			x->x_buf[sl] = 0;  }
		else
		{	radix_ftoa(x);
			if (!x->x_numwidth && x->x_resize) radix_resize(x);
			sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x -text {%s} \n"
				,glist_getcanvas(glist) ,x ,PD_COLOR_EDIT ,x->x_buf);
			x->x_buf[0] = 0;  }  }
	else
	{	radix_ftoa(x);
		if (!x->x_numwidth && x->x_resize) radix_resize(x);
		sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x -text {%s} \n"
			,glist_getcanvas(glist) ,x
			,(x->x_gui.x_fsf.x_selected ? PD_COLOR_SELECT : x->x_gui.x_fcol)
			,x->x_buf);
		x->x_buf[0] = 0;  }
}

static void radix_draw_new(t_radix *x ,t_glist *glist) {
	int xpos = text_xpix(&x->x_gui.x_obj ,glist);
	int ypos = text_ypix(&x->x_gui.x_obj ,glist);
	int w = x->x_gui.x_w ,h = x->x_gui.x_h;
	int zoom = IEMGUI_ZOOM(x) ,iow = IOWIDTH * zoom ,ioh = OHEIGHT * zoom;
	int half = h/2 ,corner = h/4 ,rad = half-ioh ,fine = zoom-1;
	t_canvas *canvas = glist_getcanvas(glist);

	sys_vgui(".x%lx.c create line %d %d %d %d %d %d %d %d %d %d %d %d "
		" -width %d -fill #%06x -tags %lxBASE1\n"
		,canvas
		,xpos ,ypos
		,xpos + w - corner ,ypos
		,xpos + w ,ypos + corner
		,xpos + w ,ypos + h
		,xpos ,ypos + h
		,xpos ,ypos
		,zoom ,x->x_gui.x_bcol ,x);
	sys_vgui(".x%lx.c create arc %d %d %d %d -start 270 -extent 180 -width %d "
		" -outline #%06x -tags %lxBASE2\n"
		,canvas
		,xpos - rad ,ypos + zoom + ioh
		,xpos + rad ,ypos + h - zoom - ioh
		,zoom ,x->x_gui.x_bcol ,x);
	if (!x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags [list %lxOUT%d outlet]\n"
			,canvas
			,xpos ,ypos + h + zoom - ioh
			,xpos + iow ,ypos + h
			,PD_COLOR_FG ,x ,0);
	if (!x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags [list %lxIN%d inlet]\n"
			,canvas
			,xpos ,ypos
			,xpos + iow ,ypos - zoom + ioh
			,PD_COLOR_FG ,x ,0);
	sys_vgui(".x%lx.c create text %d %d -text {%s} -anchor w "
		" -font {{%s} -%d %s} -fill #%06x -tags [list %lxLABEL label text]\n"
		,canvas
		,xpos + x->x_gui.x_ldx * zoom
		,ypos + x->x_gui.x_ldy * zoom
		,(strcmp(x->x_gui.x_lab->s_name ,"empty") ? x->x_gui.x_lab->s_name : "")
		,x->x_gui.x_font ,x->x_gui.x_fontsize * zoom ,sys_fontweight
		,x->x_gui.x_lcol ,x);
	radix_ftoa(x);
	sys_vgui(".x%lx.c create text %d %d -text {%s} -anchor w "
		" -font {{%s} -%d %s} -fill #%06x -tags %lxNUMBER\n"
		,canvas ,xpos + half + 2*zoom - 1 ,ypos + half + fine
		,x->x_buf ,x->x_gui.x_font ,x->x_gui.x_fontsize * zoom ,sys_fontweight
		,(x->x_gui.x_change ? PD_COLOR_EDIT : x->x_gui.x_fcol) ,x);
}

static void radix_draw_move(t_radix *x ,t_glist *glist) {
	int xpos = text_xpix(&x->x_gui.x_obj ,glist);
	int ypos = text_ypix(&x->x_gui.x_obj ,glist);
	int w = x->x_gui.x_w ,h = x->x_gui.x_h;
	int zoom = IEMGUI_ZOOM(x) ,iow = IOWIDTH * zoom ,ioh = OHEIGHT * zoom;
	int half = h/2 ,corner = h/4 ,rad = half-ioh ,fine = zoom-1;
	t_canvas *canvas = glist_getcanvas(glist);

	sys_vgui(".x%lx.c coords %lxBASE1 %d %d %d %d %d %d %d %d %d %d %d %d\n"
		,canvas ,x
		,xpos ,ypos
		,xpos + w - corner ,ypos
		,xpos + w ,ypos + corner
		,xpos + w ,ypos + h
		,xpos ,ypos + h
		,xpos ,ypos);
	sys_vgui(".x%lx.c coords %lxBASE2 %d %d %d %d\n"
		,canvas ,x
		,xpos - rad ,ypos + zoom + ioh
		,xpos + rad ,ypos + h - zoom - ioh);
	if (!x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c coords %lxOUT%d %d %d %d %d\n"
			,canvas ,x ,0
			,xpos ,ypos + h + zoom - ioh
			,xpos + iow ,ypos + h);
	if (!x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c coords %lxIN%d %d %d %d %d\n"
			,canvas ,x ,0
			,xpos ,ypos
			,xpos + iow ,ypos - zoom + ioh);
	sys_vgui(".x%lx.c coords %lxLABEL %d %d\n"
		,canvas ,x
		,xpos + x->x_gui.x_ldx * zoom
		,ypos + x->x_gui.x_ldy * zoom);
	sys_vgui(".x%lx.c coords %lxNUMBER %d %d\n"
		,canvas ,x ,xpos + half + 2*zoom - 1 ,ypos + half + fine);
}

static void radix_draw_erase(t_radix* x ,t_glist* glist) {
	t_canvas *canvas = glist_getcanvas(glist);
	sys_vgui(".x%lx.c delete %lxBASE1\n" ,canvas ,x);
	sys_vgui(".x%lx.c delete %lxBASE2\n" ,canvas ,x);
	sys_vgui(".x%lx.c delete %lxLABEL\n" ,canvas ,x);
	sys_vgui(".x%lx.c delete %lxNUMBER\n" ,canvas ,x);
	if (!x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c delete %lxOUT%d\n" ,canvas ,x ,0);
	if (!x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c delete %lxIN%d\n" ,canvas ,x ,0);
}

static void radix_draw_io(t_radix* x,t_glist* glist ,int old_snd_rcv_flags) {
	int xpos = text_xpix(&x->x_gui.x_obj ,glist);
	int ypos = text_ypix(&x->x_gui.x_obj ,glist);
	int zoom = IEMGUI_ZOOM(x) ,iow = IOWIDTH * zoom ,ioh = OHEIGHT * zoom;
	t_canvas *canvas = glist_getcanvas(glist);

	if ((old_snd_rcv_flags & IEM_GUI_OLD_SND_FLAG) && !x->x_gui.x_fsf.x_snd_able)
	{	sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags %lxOUT%d\n"
			,canvas
			,xpos ,ypos + x->x_gui.x_h + zoom - ioh
			,xpos + iow ,ypos + x->x_gui.x_h
			,PD_COLOR_FG ,x ,0);
		/* keep these above outlet */
		sys_vgui(".x%lx.c raise %lxLABEL %lxOUT%d\n" ,canvas ,x ,x ,0);
		sys_vgui(".x%lx.c raise %lxNUMBER %lxLABEL\n" ,canvas ,x ,x);  }
	if (!(old_snd_rcv_flags & IEM_GUI_OLD_SND_FLAG) && x->x_gui.x_fsf.x_snd_able)
		sys_vgui(".x%lx.c delete %lxOUT%d\n" ,canvas ,x ,0);
	if ((old_snd_rcv_flags & IEM_GUI_OLD_RCV_FLAG) && !x->x_gui.x_fsf.x_rcv_able)
	{	sys_vgui(".x%lx.c create rectangle %d %d %d %d "
			" -fill grey -outline #%06x -tags %lxIN%d\n"
			,canvas
			,xpos ,ypos
			,xpos + iow ,ypos - zoom + ioh
			,PD_COLOR_FG ,x ,0);
		/* keep these above inlet */
		sys_vgui(".x%lx.c raise %lxLABEL %lxIN%d\n" ,canvas ,x ,x ,0);
		sys_vgui(".x%lx.c raise %lxNUMBER %lxLABEL\n" ,canvas ,x ,x);  }
	if (!(old_snd_rcv_flags & IEM_GUI_OLD_RCV_FLAG) && x->x_gui.x_fsf.x_rcv_able)
		sys_vgui(".x%lx.c delete %lxIN%d\n" ,canvas ,x ,0);
}

static void radix_draw_select(t_radix *x ,t_glist *glist) {
	t_canvas *canvas = glist_getcanvas(glist);

	if (x->x_gui.x_fsf.x_selected)
	{	if (x->x_gui.x_change)
		{	x->x_gui.x_change = 0;
			clock_unset(x->x_clock_reset);
			x->x_buf[0] = 0;
			sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);  }
		sys_vgui(".x%lx.c itemconfigure %lxBASE1 -fill #%06x\n"
			,canvas ,x ,PD_COLOR_SELECT);
		sys_vgui(".x%lx.c itemconfigure %lxBASE2 -outline #%06x\n"
			,canvas ,x ,PD_COLOR_SELECT);
		sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x\n"
			,canvas ,x ,PD_COLOR_SELECT);  }
	else
	{	sys_vgui(".x%lx.c itemconfigure %lxBASE1 -fill #%06x\n"
			,canvas ,x ,x->x_gui.x_bcol);
		sys_vgui(".x%lx.c itemconfigure %lxBASE2 -outline #%06x\n"
			,canvas ,x ,x->x_gui.x_bcol);
		sys_vgui(".x%lx.c itemconfigure %lxNUMBER -fill #%06x\n"
			,canvas ,x ,x->x_gui.x_fcol);  }
}

static void radix_draw(t_radix *x ,t_glist *glist ,int mode) {
	if      (mode == IEM_GUI_DRAW_MODE_UPDATE)
		sys_queuegui(x ,glist ,radix_draw_update);
	else if (mode == IEM_GUI_DRAW_MODE_MOVE)
		radix_draw_move(x ,glist);
	else if (mode == IEM_GUI_DRAW_MODE_NEW)
		radix_draw_new(x ,glist);
	else if (mode == IEM_GUI_DRAW_MODE_SELECT)
		radix_draw_select(x ,glist);
	else if (mode == IEM_GUI_DRAW_MODE_ERASE)
		radix_draw_erase(x ,glist);
	else if (mode == IEM_GUI_DRAW_MODE_CONFIG)
		radix_draw_config(x ,glist);
	else if (mode >= IEM_GUI_DRAW_MODE_IO)
		radix_draw_io(x ,glist ,mode - IEM_GUI_DRAW_MODE_IO);
}

/* ------------------------- radix widgetbehaviour -------------------------- */

static void radix_getrect
(t_gobj *z ,t_glist *glist ,int *xp1 ,int *yp1 ,int *xp2 ,int *yp2) {
	t_radix* x = (t_radix*)z;
	*xp1 = text_xpix(&x->x_gui.x_obj ,glist);
	*yp1 = text_ypix(&x->x_gui.x_obj ,glist);
	*xp2 = *xp1 + x->x_gui.x_w;
	*yp2 = *yp1 + x->x_gui.x_h;
}

static void radix_save(t_gobj *z ,t_binbuf *b) {
	t_radix *x = (t_radix*)z;
	t_symbol *bflcol[3];
	t_symbol *srl[3];

	iemgui_save(&x->x_gui ,srl ,bflcol);
	if (x->x_gui.x_change)
	{	x->x_gui.x_change = 0;
		clock_unset(x->x_clock_reset);
		sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);  }
	binbuf_addv(b ,"ssiisiiffiisssiiiisssiiifi" ,gensym("#X") ,gensym("obj")
		,x->x_gui.x_obj.te_xpix ,x->x_gui.x_obj.te_ypix
		,gensym("radix") ,x->x_numwidth ,((t_radixtcl*)x)->x_zh
		,x->x_min ,x->x_max ,x->x_lilo
		,iem_symargstoint(&x->x_gui.x_isa) ,srl[0] ,srl[1] ,srl[2]
		,x->x_gui.x_ldx ,x->x_gui.x_ldy
		,iem_fstyletoint(&x->x_gui.x_fsf) ,x->x_gui.x_fontsize
		,bflcol[0] ,bflcol[1] ,bflcol[2]
		,x->x_base ,x->x_prec ,x->x_e
		,(x->x_gui.x_isa.x_loadinit ? x->x_val : 0) ,x->x_log_height);
	binbuf_addv(b ,";");
}

static void radix_properties(t_gobj *z ,t_glist *owner) {
	(void)owner;
	t_radix *x = (t_radix*)z;
	char buf[800];
	t_symbol *srl[3];

	iemgui_properties(&x->x_gui ,srl);
	if (x->x_gui.x_change)
	{	x->x_gui.x_change = 0;
		clock_unset(x->x_clock_reset);
		sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);  }
	sprintf(buf ,"pdtk_iemgui_dialog %%s |radix| "
		"-------dimensions(digits)(pix):------- %d %d width: %d %d height: "
		"-----------output-range:----------- %g min: %g max: %d "
		"%d lin log %d %d log-height: %d "
		"%s %s "
		"%s %d %d "
		"%d %d "
		"#%06x #%06x #%06x\n"
		,x->x_numwidth ,MINDIGITS ,((t_radixtcl*)x)->x_zh ,IEM_GUI_MINSIZE
		,x->x_min ,x->x_max ,0 /*no_schedule*/
		,x->x_lilo ,x->x_gui.x_isa.x_loadinit ,-1
		,x->x_log_height /*no multi ,but iem-characteristic*/
		,srl[0]->s_name ,srl[1]->s_name
		,srl[2]->s_name ,x->x_gui.x_ldx ,x->x_gui.x_ldy
		,x->x_gui.x_fsf.x_font_style ,x->x_gui.x_fontsize
		,0xffffff & x->x_gui.x_bcol ,0xffffff & x->x_gui.x_fcol
		,0xffffff & x->x_gui.x_lcol);
	gfxstub_new(&x->x_gui.x_obj.ob_pd ,x ,buf);
}

static void radix_bang(t_radix *x) {
	outlet_float(x->x_gui.x_obj.ob_outlet ,x->x_val);
	if (x->x_gui.x_fsf.x_snd_able && x->x_gui.x_snd->s_thing)
		pd_float(x->x_gui.x_snd->s_thing ,x->x_val);
}

static void radix_dialog(t_radix *x ,t_symbol *s ,int argc ,t_atom *argv) {
	(void)s;
	t_symbol *srl[3];
	int w          = atom_getfloatarg(0 ,argc ,argv);
	int h          = atom_getfloatarg(1 ,argc ,argv);
	double min     = atom_getfloatarg(2 ,argc ,argv);
	double max     = atom_getfloatarg(3 ,argc ,argv);
	int lilo       = atom_getfloatarg(4 ,argc ,argv);
	int log_height = atom_getfloatarg(6 ,argc ,argv);
	int sr_flags = iemgui_dialog(&x->x_gui ,srl ,argc ,argv);
	radix_calc_fontwidth(x);

	if (lilo != 0) lilo = 1;
	x->x_lilo = lilo;
	if (w < MINDIGITS)
		w = MINDIGITS;
	x->x_numwidth = w;
	if (h < IEM_GUI_MINSIZE)
		h = IEM_GUI_MINSIZE;
	((t_radixtcl*)x)->x_zh = h;
	x->x_gui.x_h = h * IEMGUI_ZOOM(x) - (IEMGUI_ZOOM(x)-1)*2;
	if (log_height < 10)
		log_height = 10;
	x->x_log_height = log_height;
	radix_borderwidth(x ,IEMGUI_ZOOM(x));
	/*if (radix_check_minmax(x ,min ,max))
	 radix_bang(x);*/
	radix_check_minmax(x ,min ,max);
	(*x->x_gui.x_draw)(x ,x->x_gui.x_glist ,IEM_GUI_DRAW_MODE_UPDATE);
	(*x->x_gui.x_draw)(x ,x->x_gui.x_glist ,IEM_GUI_DRAW_MODE_IO + sr_flags);
	(*x->x_gui.x_draw)(x ,x->x_gui.x_glist ,IEM_GUI_DRAW_MODE_CONFIG);
	(*x->x_gui.x_draw)(x ,x->x_gui.x_glist ,IEM_GUI_DRAW_MODE_MOVE);
	canvas_fixlinesfor (x->x_gui.x_glist ,(t_text*)x);
}

static void radix_motion(t_radix *x ,t_float dx ,t_float dy) {
	(void)dx;
	double k2 = 1. ,pwr = x->x_base * x->x_base ,fin = 1/pwr;
	ufloat uf = {.f = x->x_val};
	if (uf.ex > 150) k2 *= pow(2 ,uf.ex-150);
	if (x->x_gui.x_fsf.x_finemoved)
		k2 *= fin;
	if (x->x_lilo)
		x->x_val *= pow(x->x_k ,-k2*dy);
	else
	{	x->x_val -= k2*dy;
		double trunc = fin * floor(pwr * x->x_val + 0.5);
		if (trunc < x->x_val + fin*fin && trunc > x->x_val - fin*fin)
			x->x_val = trunc;  }
	radix_clip(x);
	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
	radix_bang(x);
	clock_unset(x->x_clock_reset);
}

static void radix_float(t_radix *x ,t_float f) {
	radix_set(x ,f);
	if (x->x_gui.x_fsf.x_put_in2out)
		radix_bang(x);
}

static void radix_click
(t_radix *x ,t_float xpos ,t_float ypos ,t_float shift ,t_float ctrl ,t_float alt) {
	(void)shift;
	(void)ctrl;
	if (alt)
	{	if (x->x_val != 0)
		{	x->x_tog = x->x_val;
			radix_float(x ,0);
			return;  }
		else radix_float(x ,x->x_tog);  }
	glist_grab(x->x_gui.x_glist ,&x->x_gui.x_obj.te_g
		,(t_glistmotionfn)radix_motion ,(t_glistkeyfn)radix_key ,xpos ,ypos);
}

static int radix_newclick(t_gobj *z ,struct _glist *glist
,int xpix ,int ypix ,int shift ,int alt ,int dbl ,int doit) {
	(void)glist;
	(void)dbl;
	t_radix* x = (t_radix*)z;
	if (doit)
	{	radix_click(x ,xpix ,ypix ,shift ,0 ,alt);
		x->x_gui.x_fsf.x_finemoved = (shift != 0);
		if (!x->x_gui.x_change)
		{	clock_delay(x->x_clock_wait ,50);
			x->x_gui.x_change = 1;
			clock_delay(x->x_clock_reset ,3000);
			x->x_buf[0] = 0;  }
		else
		{	x->x_gui.x_change = 0;
			clock_unset(x->x_clock_reset);
			x->x_buf[0] = 0;
			sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);  }  }
	return (1);
}

static void radix_size(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	int w ,h;
	w = atom_getintarg(0 ,ac ,av);
	if (w < MINDIGITS)
		w = MINDIGITS;
	x->x_numwidth = w;
	if (ac > 1)
	{	h = atom_getintarg(1 ,ac ,av);
		if (h < IEM_GUI_MINSIZE)
			h = IEM_GUI_MINSIZE;
		((t_radixtcl*)x)->x_zh = h;
		x->x_gui.x_h = h * IEMGUI_ZOOM(x) - (IEMGUI_ZOOM(x)-1)*2;  }
	radix_borderwidth(x ,IEMGUI_ZOOM(x));
	iemgui_size((void*)x ,&x->x_gui);
}

static void radix_delta(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	iemgui_delta((void*)x ,&x->x_gui ,s ,ac ,av);
}

static void radix_pos(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	iemgui_pos((void*)x ,&x->x_gui ,s ,ac ,av);
}

static void radix_range(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	(void)s;
	if (radix_check_minmax( x
	,atom_getfloatarg(0 ,ac ,av) ,atom_getfloatarg(1 ,ac ,av)))
	{	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
		/*radix_bang(x);*/  }
}

static void radix_color(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	iemgui_color((void*)x ,&x->x_gui ,s ,ac ,av);
}

static void radix_send(t_radix *x ,t_symbol *s) {
	iemgui_send(x ,&x->x_gui ,s);
}

static void radix_receive(t_radix *x ,t_symbol *s) {
	iemgui_receive(x ,&x->x_gui ,s);
}

static void radix_label(t_radix *x ,t_symbol *s) {
	iemgui_label((void*)x ,&x->x_gui ,s);
}

static void radix_label_pos(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	iemgui_label_pos((void*)x ,&x->x_gui ,s ,ac ,av);
}

static void radix_label_font(t_radix *x ,t_symbol *s ,int ac ,t_atom *av) {
	int f = atom_getfloatarg(1 ,ac ,av);
	if (f < MINFONT)
		f = MINFONT;
	x->x_gui.x_fontsize = f;
	f = atom_getfloatarg(0 ,ac ,av);
	if (f<0 || f>2) f = 0;
	x->x_gui.x_fsf.x_font_style = f;
	radix_borderwidth(x ,IEMGUI_ZOOM(x));
	iemgui_label_font((void*)x ,&x->x_gui ,s ,ac ,av);
}

static void radix_init(t_radix *x ,t_float f) {
	x->x_gui.x_isa.x_loadinit = (f == 0.) ? 0 : 1;
}

static void radix_loadbang(t_radix *x ,t_float action) {
	if (action == LB_LOAD && x->x_gui.x_isa.x_loadinit)
	{	sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
		radix_bang(x);  }
}

static void radix_key(void *z ,t_symbol *keysym ,t_float fkey) {
	(void)keysym;
	t_radix *x = z;
	char c = fkey;
	char buf[3];
	buf[1] = 0;

	if (c == 0)
	{	x->x_gui.x_change = 0;
		clock_unset(x->x_clock_reset);
		sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);
		return;  }
	if ((c>='0' && c<='9') || c=='.' || c=='-' || c=='e' || c=='+' || c=='E')
	{	if (strlen(x->x_buf) < (IEMGUI_MAX_NUM_LEN-2))
		{	buf[0] = c;
			strcat(x->x_buf ,buf);
			sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);  }  }
	else if ((c == '\b') || (c == 127))
	{	int sl = strlen(x->x_buf) - 1;
		if (sl < 0)
			sl = 0;
		x->x_buf[sl] = 0;
		sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);  }
	else if ((c == '\n') || (c == 13))
	{	x->x_val = atof(x->x_buf);
		x->x_buf[0] = 0;
		x->x_gui.x_change = 0;
		clock_unset(x->x_clock_reset);
		radix_clip(x);
		radix_bang(x);
		sys_queuegui(x ,x->x_gui.x_glist ,radix_draw_update);  }
	clock_delay(x->x_clock_reset ,3000);
}

static void *radix_new(t_symbol *s ,int argc ,t_atom *argv) {
	(void)s;
	t_radixtcl *y = (t_radixtcl*)pd_new(radix_class);
	t_radix *x = &y->z;
	int w = 0 ,h = 22;
	int lilo = 0 ,ldx = -1 ,ldy = -10;
	int fs = 11;
	int log_height = 256;
	double min = 0. ,max = 0. ,v = 0.;
	int base=0 ,prec=0 ,e=0;

	x->x_gui.x_bcol = PD_COLOR_BG;
	x->x_gui.x_fcol = PD_COLOR_FG;
	x->x_gui.x_lcol = PD_COLOR_FG;

	if (argc >= 20)
	{	w    = atom_getfloatarg(0  ,argc ,argv);
		h    = atom_getfloatarg(1  ,argc ,argv);
		min  = atom_getfloatarg(2  ,argc ,argv);
		max  = atom_getfloatarg(3  ,argc ,argv);
		lilo = atom_getfloatarg(4  ,argc ,argv);
		ldx  = atom_getfloatarg(9  ,argc ,argv);
		ldy  = atom_getfloatarg(10 ,argc ,argv);
		fs   = atom_getfloatarg(12 ,argc ,argv);
		base = atom_getfloatarg(16 ,argc ,argv);
		prec = atom_getfloatarg(17 ,argc ,argv);
		e    = atom_getfloatarg(18 ,argc ,argv);
		v    = atom_getfloatarg(19 ,argc ,argv);
		iem_inttosymargs(&x->x_gui.x_isa ,atom_getfloatarg(5 ,argc ,argv));
		iem_inttofstyle(&x->x_gui.x_fsf ,atom_getfloatarg(11 ,argc ,argv));
		iemgui_all_loadcolors(&x->x_gui ,argv+13 ,argv+14 ,argv+15);
		iemgui_new_getnames(&x->x_gui ,6 ,argv);  }
	else iemgui_new_getnames(&x->x_gui ,6 ,0);
	if (argc == 21) log_height = atom_getfloatarg(20 ,argc ,argv);

	if (argc >= 1 && argc <= 3)
	{	base = atom_getfloatarg(0 ,argc ,argv);
		prec = atom_getfloatarg(1 ,argc ,argv);
		e    = atom_getfloatarg(2 ,argc ,argv);  }
	radix_dobase(x ,base ? base : 16);
	radix_precision(x ,prec ? prec : (FLT_MANT_DIG / log2(x->x_base)));
	x->x_e = e ? radix_bounds(e) : x->x_base;

	x->x_gui.x_draw = (t_iemfunptr)radix_draw;
	x->x_gui.x_fsf.x_snd_able = 1;
	x->x_gui.x_fsf.x_rcv_able = 1;
	x->x_gui.x_glist = (t_glist*)canvas_getcurrent();
	if (x->x_gui.x_isa.x_loadinit)
		 x->x_val = v;
	else x->x_val = 0.;

	x->x_lilo = lilo;
	if (log_height < 10)
		log_height = 10;
	x->x_log_height = log_height;

	if (!strcmp(x->x_gui.x_snd->s_name ,"empty"))
		x->x_gui.x_fsf.x_snd_able = 0;
	if (!strcmp(x->x_gui.x_rcv->s_name ,"empty"))
		x->x_gui.x_fsf.x_rcv_able = 0;

	switch (x->x_gui.x_fsf.x_font_style)
	{	case 2: strcpy(x->x_gui.x_font ,"times"); break;
		case 1: strcpy(x->x_gui.x_font ,"helvetica"); break;
		default: x->x_gui.x_fsf.x_font_style = 0;
			strcpy(x->x_gui.x_font ,sys_font);  }

	if (x->x_gui.x_fsf.x_rcv_able)
		pd_bind(&x->x_gui.x_obj.ob_pd ,x->x_gui.x_rcv);
	x->x_gui.x_ldx = ldx;
	x->x_gui.x_ldy = ldy;

	if (fs < MINFONT)
		fs = MINFONT;
	x->x_gui.x_fontsize = fs;
	radix_calc_fontwidth(x);
	if (w < MINDIGITS)
		w = MINDIGITS;
	x->x_numwidth = w;
	if (h < IEM_GUI_MINSIZE)
		h = IEM_GUI_MINSIZE;
	x->x_gui.x_h = y->x_zh = h;

	x->x_buf[0] = 0;
	x->x_buflen = 3;
	radix_check_minmax(x ,min ,max);
	iemgui_verify_snd_ne_rcv(&x->x_gui);
	x->x_clock_reset = clock_new(x ,(t_method)radix_tick_reset);
	x->x_clock_wait = clock_new(x ,(t_method)radix_tick_wait);
	x->x_gui.x_change = 0;
	iemgui_newzoom(&x->x_gui);
	radix_borderwidth(x ,IEMGUI_ZOOM(x));
	outlet_new(&x->x_gui.x_obj ,&s_float);
	return (y);
}

static void radix_free(t_radix *x) {
	if (x->x_gui.x_fsf.x_rcv_able)
		pd_unbind(&x->x_gui.x_obj.ob_pd ,x->x_gui.x_rcv);
	clock_free(x->x_clock_reset);
	clock_free(x->x_clock_wait);
	gfxstub_deleteforkey(x);
}

void radix_setup(void) {
	radix_class = class_new(gensym("radix") ,(t_newmethod)radix_new
		,(t_method)radix_free ,sizeof(t_radixtcl) ,0 ,A_GIMME ,0);
	class_addbang  (radix_class ,radix_bang);
	class_addfloat (radix_class ,radix_float);
	class_addlist  (radix_class ,radix_list);

	class_addmethod(radix_class ,(t_method)radix_click
		,gensym("click")      ,A_FLOAT ,A_FLOAT ,A_FLOAT ,A_FLOAT ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_motion
		,gensym("motion")     ,A_FLOAT ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_dialog
		,gensym("dialog")     ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_loadbang
		,gensym("loadbang")   ,A_DEFFLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_set
		,gensym("set")        ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_size
		,gensym("size")       ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_delta
		,gensym("delta")      ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_pos
		,gensym("pos")        ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_range
		,gensym("range")      ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_color
		,gensym("color")      ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_send
		,gensym("send")       ,A_DEFSYM ,0);
	class_addmethod(radix_class ,(t_method)radix_receive
		,gensym("receive")    ,A_DEFSYM ,0);
	class_addmethod(radix_class ,(t_method)radix_label
		,gensym("label")      ,A_DEFSYM ,0);
	class_addmethod(radix_class ,(t_method)radix_label_pos
		,gensym("label_pos")  ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_label_font
		,gensym("label_font") ,A_GIMME ,0);
	class_addmethod(radix_class ,(t_method)radix_log
		,gensym("log")        ,A_NULL);
	class_addmethod(radix_class ,(t_method)radix_lin
		,gensym("lin")        ,A_NULL);
	class_addmethod(radix_class ,(t_method)radix_init
		,gensym("init")       ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_log_height
		,gensym("log_height") ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_base
		,gensym("base")       ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_base
		,gensym("b")          ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_ebase
		,gensym("e")          ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_be
		,gensym("be")         ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_precision
		,gensym("p")          ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_fontsize
		,gensym("fs")         ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_fontwidth
		,gensym("fw")         ,A_FLOAT ,0);
	class_addmethod(radix_class ,(t_method)radix_zoom
		,gensym("zoom")       ,A_CANT ,0);
	radix_widgetbehavior.w_visfn        = iemgui_vis;
	radix_widgetbehavior.w_clickfn      = radix_newclick;
	radix_widgetbehavior.w_selectfn     = iemgui_select;
	radix_widgetbehavior.w_deletefn     = iemgui_delete;
	radix_widgetbehavior.w_getrectfn    = radix_getrect;
	radix_widgetbehavior.w_displacefn   = iemgui_displace;
	radix_widgetbehavior.w_activatefn   = NULL;
	class_setwidget      (radix_class ,&radix_widgetbehavior);
	class_setsavefn      (radix_class ,radix_save);
	class_setpropertiesfn(radix_class ,radix_properties);
}
