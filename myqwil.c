void muse_setup(void);
void chrd_setup(void);
void rand_setup(void);
void rind_setup(void);
void ntof_setup(void);
void fton_setup(void);
void flenc_setup(void);
void fldec_setup(void);
void slx_setup(void);
void sly_setup(void);
void same_setup(void);
void ceil_setup(void);
void delp_setup(void);
void linp_setup(void);
void linp_tilde_setup(void);

void chrono_setup(void);
void radix_setup(void);
void setup_0x21(void);
void setup_0x21_tilde(void);
void x_setup(void);
void is_setup(void);
void has_setup(void);
void pak_setup(void);
void unpak_setup(void);
void setup_0x40pak(void);
void setup_0x40unpak(void);
void tabread2_tilde_setup(void);
void tabosc2_tilde_setup(void);

void blunt_setup(void);
// void ffplay_tilde_setup(void);
// void gme_tilde_setup(void);
// void gmes_tilde_setup(void);

void myQwil_setup(void) {
	muse_setup();
	chrd_setup();
	rand_setup();
	rind_setup();
	ntof_setup();
	fton_setup();
	flenc_setup();
	fldec_setup();
	slx_setup();
	sly_setup();
	same_setup();
	ceil_setup();
	delp_setup();
	linp_setup();
	linp_tilde_setup();

	chrono_setup();
	radix_setup();
	setup_0x21();
	setup_0x21_tilde();
	x_setup();
	is_setup();
	has_setup();
	pak_setup();
	unpak_setup();
	setup_0x40pak();
	setup_0x40unpak();
	tabread2_tilde_setup();
	tabosc2_tilde_setup();

	blunt_setup();
	// ffplay_tilde_setup();
	// gme_tilde_setup();
	// gmes_tilde_setup();
}
