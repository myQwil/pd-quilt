#include "m_pd.h"

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	union {
		t_symbol *iu_symto;
		t_gpointer *iu_pointerslot;
		t_float *iu_floatslot;
		t_symbol **iu_symslot;
		t_float iu_floatsignalvalue;
	};
};
