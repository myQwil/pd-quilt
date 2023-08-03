#include "m_pd.h"

// @return 1 if the current state is the same as the one being requested
static inline int pause_state(unsigned char *pause, int ac, t_atom *av) {
	if (ac && av->a_type == A_FLOAT) {
		int state = (av->a_w.w_float != 0);
		if (*pause == state) {
			return 1;
		} else {
			*pause = state;
		}
	} else {
		*pause = !*pause;
	}
	return 0;
}
