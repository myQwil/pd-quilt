#include "m_pd.h"

typedef union {
	t_float f;
#if PD_FLOATSIZE == 32
	uint32_t u;
	struct {
		uint32_t mt : 23, ex : 8, sg : 1;
	};
#else
	uint64_t u;
	struct {
		uint64_t mt : 52, ex : 11, sg : 1;
	};
#endif
} ufloat;
