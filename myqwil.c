#include "m_pd.h"

static t_class *myQwil_class;

static void *myQwil_new(void) {
	t_object *x = (t_object *)pd_new(myQwil_class);
	return (x);
}

void graid_setup(void);
void divrt_setup(void);
void rand_setup(void);
void randv_setup(void);
void rind_setup(void);
void muse_setup(void);
void ruse_setup(void);
void harm_setup(void);
void fton_setup(void);
void ntof_setup(void);
void radx_setup(void);
void same_setup(void);
void sploat_setup(void);
void gloat_setup(void);


/* ------------------------ setup routine ------------------------ */

void myQwil_setup(void) {
	myQwil_class = class_new(gensym("myQwil"), myQwil_new, 0,
		sizeof(t_object), CLASS_NOINLET, 0);

	graid_setup();
	divrt_setup();
	rand_setup();
	randv_setup();
	rind_setup();
	muse_setup();
	ruse_setup();
	harm_setup();
	fton_setup();
	ntof_setup();
	radx_setup();
	same_setup();
	sploat_setup();
	gloat_setup();
	post("myQwil loaded! ");
}
