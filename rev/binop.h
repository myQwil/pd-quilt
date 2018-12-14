
/* -------------------------- binop -------------------------- */

typedef struct _binop {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
} t_binop;

static void *binop_new(t_class *floatclass, t_floatarg f) {
	t_binop *x = (t_binop *)pd_new(floatclass);
	outlet_new(&x->x_obj, &s_float);
	floatinlet_new(&x->x_obj, &x->x_f2);
	x->x_f1 = 0;
	x->x_f2 = f;
	return (x);
}
