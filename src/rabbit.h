#include "m_pd.h"
#include <samplerate.h>

#define FRAMES 0x10

typedef struct _rabbit {
	SRC_STATE *state;
	SRC_DATA data;
	t_float speed; /* playback speed */
	double ratio;  /* resampling ratio */
} t_rabbit;

// SRC can get stuck if it's too close to the fastest possible speed
static const t_float fastest = FRAMES - (1. / 128.);
static const t_float slowest = 1. / FRAMES;

static inline void rabbit_speed(t_rabbit *x, t_float f) {
	x->speed = f;
	f *= x->ratio;
	f = f > fastest ? fastest : (f < slowest ? slowest : f);
	x->data.src_ratio = 1. / f;
}

static inline void rabbit_reset(t_rabbit *x) {
	src_reset(x->state);
	x->data.output_frames_gen = 0;
	x->data.input_frames = 0;
}

static int rabbit_interp(t_rabbit *x, int nch, t_float f) {
	int d = f;
	if (d < SRC_SINC_BEST_QUALITY || d > SRC_LINEAR) {
		return 1;
	}

	int err;
	src_delete(x->state);
	if ((x->state = src_new(d, nch, &err)) == NULL) {
		post("Error : src_new() failed : %s.", src_strerror(err));
	}
	return err;
}

static int rabbit_init(t_rabbit *x, unsigned nch) {
	int err;
	SRC_STATE *state;
	if (!(state = src_new(SRC_SINC_FASTEST, nch, &err))) {
		pd_error(0, "src_new() failed : %s.", src_strerror(err));
	}
	x->state = state;
	x->data.src_ratio = x->ratio = 1.0;
	x->data.output_frames = FRAMES;
	x->speed = 1.0;
	return err;
}
