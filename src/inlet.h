#include "m_pd.h"

union inletunion {
	t_symbol *iu_symto;
	t_gpointer *iu_pointerslot;
	t_float *iu_floatslot;
	t_symbol **iu_symslot;
	t_float iu_floatsignalvalue;
};

struct _inlet {
	t_pd i_pd;
	struct _inlet *i_next;
	t_object *i_owner;
	t_pd *i_dest;
	t_symbol *i_symfrom;
	union inletunion i_un;
};
