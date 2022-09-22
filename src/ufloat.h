#include "m_pd.h"

typedef union {
	t_float f;
#if PD_FLOATSIZE == 32
	uint32_t u;
	struct {
		uint32_t m : 23, e : 8, s : 1;
	} fu;
#else
	uint64_t u;
	struct {
		uint64_t m : 52, e : 11, s : 1;
	} fu;
#endif
} ufloat;

#define mt fu.m
#define ex fu.e
#define sg fu.s
