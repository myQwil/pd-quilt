void setup_0x40paq(void);
void setup_0x40unpaq(void);
void blunt_setup(void);
void chrd_setup(void);
void chrono_setup(void);
void delp_setup(void);
void fldec_setup(void);
void flenc_setup(void);
void fton_setup(void);
void has_setup(void);
void is_setup(void);
void linp_setup(void);
void linp_tilde_setup(void);
void metro_tilde_setup(void);
void muse_setup(void);
void ntof_setup(void);
void paq_setup(void);
void radix_setup(void);
void rand_setup(void);
void rind_setup(void);
void same_setup(void);
void slx_setup(void);
void sly_setup(void);
void tabosc2_tilde_setup(void);
void tabread2_tilde_setup(void);
void unpaq_setup(void);

// void ffplay_tilde_setup(void);
// void gme_tilde_setup(void);
// void gmes_tilde_setup(void);

void quilt_setup(void) {
	setup_0x40paq();
	setup_0x40unpaq();
	blunt_setup();
	chrd_setup();
	chrono_setup();
	delp_setup();
	fldec_setup();
	flenc_setup();
	fton_setup();
	has_setup();
	is_setup();
	linp_setup();
	linp_tilde_setup();
	metro_tilde_setup();
	muse_setup();
	ntof_setup();
	paq_setup();
	radix_setup();
	rand_setup();
	rind_setup();
	same_setup();
	slx_setup();
	sly_setup();
	tabosc2_tilde_setup();
	tabread2_tilde_setup();
	unpaq_setup();

	// ffplay_tilde_setup();
	// gme_tilde_setup();
	// gmes_tilde_setup();
}
