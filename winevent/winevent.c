/**
 * [winevent] Generates mouse and keyboard events on Windows
 * @author Patrice Colet <pat@mamalala.org> (source code for kbdstroke)
 * @author Jean-Yves Gratius <jyg@gumo.fr> (modified code for winevent)
 * @license GNU Public License		)c( 2008
 */
 
#include <windows.h>
#include "../m_pd.h"

/** The class */
t_class *winevent_class;
 
typedef struct winevent {
	t_object x_obj; /* The instance. Contains inlets and outlets */
	t_float xsize_factor;
	t_float ysize_factor;
} t_winevent;



void winevent_downkey(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	if (argc >= 1) {
		if (argv[0].a_type == A_FLOAT) {
			t_float str = atom_getfloat(argv);
			//only use the first argument	<---fix this
			keybd_event(str, 0, 0, 0); }
		else post("Error : Bad argument type. Must be a float or a symbol. "); }
	else post("Error : Missing argument");
}

void winevent_upkey(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	if (argc >= 1) {
		if (argv[0].a_type == A_FLOAT) {
			t_float str = atom_getfloat(argv);
			//only use the first argument	<---fix this
			keybd_event(str, 0, 2, 0); }
		else post("Error : Bad argument type. Must be a float or a symbol. "); }
	else post("Error : Missing argument");
}
void winevent_key(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	if (argc >= 1) {
		if (argv[0].a_type == A_FLOAT) {
			t_float str = atom_getfloat(argv);
			//only use the first argument	<---fix this
			keybd_event(str, 0, 0, 0);
			keybd_event(str, 0, 2, 0); }
		else post("Error : Bad argument type. Must be a float or a symbol. "); }
	else post("Error : Missing argument");
}

void winevent_mouse(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	if (argc >= 1) {
		if (argv[0].a_type == A_FLOAT) {
			t_float str = atom_getfloat(argv);
			mouse_event(str, 0, 0, 0 ,0); }
		else post("Error : Bad argument type. Must be a float or a symbol. "); }
	else post("Error : Missing argument");
}

void winevent_mouse_move(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	if (argc >= 2) {
		if ((argv[0].a_type == A_FLOAT)&&(argv[1].a_type == A_FLOAT)) {
			t_float str1 = atom_getfloatarg(0, argc, argv);
			t_float str2 = atom_getfloatarg(1, argc, argv);
			mouse_event(MOUSEEVENTF_MOVE, str1, str2, 0 ,0); }
		else post("Error : Bad argument type. Must be a float or a symbol. "); }
	else post("Error : Missing argument");
}

void winevent_mouse_pos(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	if (argc >= 2) {
		if ((argv[0].a_type == A_FLOAT)&&(argv[1].a_type == A_FLOAT))	{
			t_float str1 = atom_getfloatarg(0, argc, argv) * x->xsize_factor;		
			t_float str2 = atom_getfloatarg(1, argc, argv) * x->ysize_factor;
			mouse_event((MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE), str1, str2, 0 ,0); }
		else post("Error : Bad argument type. Must be a float or a symbol. "); }
	else post("Error : Missing argument");
}

void winevent_mouse_wheel(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	if (argc >= 1) {
		if (argv[0].a_type == A_FLOAT) {
			t_float str = atom_getfloat(argv);
			mouse_event(MOUSEEVENTF_WHEEL, 0, 0, str ,0); }
		else post("Error : Bad argument type. Must be a float or a symbol. "); }
	else post("Error : Missing argument");
}

void winevent_get_screen_xsize(t_winevent *x, t_float *s, int argc, t_atom *argv) {
	POINT p_curseur;
	GetCursorPos(&p_curseur);
	outlet_float(x->x_obj.ob_outlet, p_curseur.x);
}




void winevent_float(t_winevent *x, t_floatarg f) {
	outlet_float(x->x_obj.ob_outlet, f);
	post("appel_de_la_methode_winevent_float...");
}

/* constructor */
void *winevent_new(t_symbol *selector, int argc, t_atom *argv) {
	t_winevent *x = (t_winevent *) pd_new(winevent_class);
	outlet_new(&x->x_obj, gensym("float"));
	x->xsize_factor = 65536 / (GetSystemMetrics(SM_CXSCREEN));
	x->ysize_factor = 65536 / (GetSystemMetrics(SM_CYSCREEN));
	return (void *)x;
}

/* setup */
__declspec(dllexport) void winevent_setup(void) {
	winevent_class = class_new(gensym("winevent"),
		(t_newmethod)winevent_new, 0,
		sizeof(t_winevent), 0,
		A_GIMME, 0);
	class_addmethod(winevent_class, (t_method)winevent_downkey, gensym("downkey"), A_GIMME, 0);
	class_addmethod(winevent_class, (t_method)winevent_upkey, gensym("upkey"), A_GIMME, 0);
	class_addmethod(winevent_class, (t_method)winevent_key, gensym("key"), A_GIMME, 0);
	class_addmethod(winevent_class, (t_method)winevent_mouse, gensym("mouse"), A_GIMME, 0);
	class_addmethod(winevent_class, (t_method)winevent_mouse_move, gensym("mouse_move"), A_GIMME, 0);
	class_addmethod(winevent_class, (t_method)winevent_mouse_pos, gensym("mouse_pos"), A_GIMME, 0);
	class_addmethod(winevent_class, (t_method)winevent_mouse_wheel, gensym("mouse_wheel"), A_GIMME, 0);
	class_addmethod(winevent_class, (t_method) winevent_get_screen_xsize, gensym("xsize"), A_GIMME, 0);
	class_addfloat(winevent_class, (t_method)winevent_float);
}
