#include "m_pd.h"
#include <float.h>

#if   PD_FLOATSIZE == 32
# define MANT_DIG FLT_MANT_DIG
#elif PD_FLOATSIZE == 64
# define MANT_DIG DBL_MANT_DIG
#endif

typedef union {
	t_float f;
	PD_FLOATUINTTYPE u;
	struct {
		PD_FLOATUINTTYPE mantissa : MANT_DIG - 1,
		                 exponent : PD_FLOATSIZE - MANT_DIG,
		                 sign : 1;
	};
} ufloat;
