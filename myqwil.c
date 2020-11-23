void muse_setup(void);
void chrd_setup(void);
void rand_setup(void);
void rind_setup(void);
void ntof_setup(void);
void fton_setup(void);
void sploat_setup(void);
void gloat_setup(void);
void span_setup(void);
void same_setup(void);
void ceil_setup(void);
void radix_setup(void);
void setup_0x21(void);
void setup_0x21_tilde(void);
void is_setup(void);
void pak_setup(void);
void unpak_setup(void);
void setup_0x40pak(void);
void setup_0x40unpak(void);
void stopwatch_setup(void);

void blunt_setup(void);
void ffplay_tilde_setup(void);
void gme_tilde_setup(void);
void gmes_tilde_setup(void);

void myQwil_setup(void) {
	muse_setup();
	chrd_setup();
	rand_setup();
	rind_setup();
	ntof_setup();
	fton_setup();
	sploat_setup();
	gloat_setup();
	span_setup();
	same_setup();
	ceil_setup();
	radix_setup();
	setup_0x21();
	setup_0x21_tilde();
	is_setup();
	pak_setup();
	unpak_setup();
	setup_0x40pak();
	setup_0x40unpak();
	stopwatch_setup();

	blunt_setup();
	ffplay_tilde_setup();
	gme_tilde_setup();
	gmes_tilde_setup();
}
