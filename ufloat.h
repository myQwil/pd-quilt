typedef union {
	float f;
	unsigned u;
	struct { unsigned mt:23,ex:8,sg:1; } s;
} ufloat;
#define mt s.mt
#define ex s.ex
#define sg s.sg
