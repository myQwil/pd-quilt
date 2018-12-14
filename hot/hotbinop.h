
/* -------------------------- hotbinop -------------------------- */

typedef struct _hotbinop {
	t_object x_obj;
	t_float x_f1;
	t_float x_f2;
	t_pd *x_proxy;
} t_hotbinop;

typedef struct _hotbinop_proxy {
	t_object p_obj;
	t_hotbinop *p_master;
} t_hotbinop_proxy;

static void *hotbinop_new(t_class *floatclass, t_class *proxyclass, t_floatarg f) {
	t_hotbinop *x = (t_hotbinop *)pd_new(floatclass);
	t_pd *proxy = pd_new(proxyclass);
	x->x_proxy = proxy;
	((t_hotbinop_proxy *)proxy)->p_master = x;
	outlet_new(&x->x_obj, &s_float);
	inlet_new(&x->x_obj, proxy, 0, 0);
	x->x_f1 = 0;
	x->x_f2 = f;
	return (x);
}

static void hotbinop_free(t_hotbinop *x) {
	pd_free(x->x_proxy);
}
