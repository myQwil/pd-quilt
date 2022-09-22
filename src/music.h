#include "flin.h"
#include "note.h"
#include <stdlib.h> // strtof
#include <string.h> // memcpy

static inline int isoperator(char c) {
	return (c == '^' || c == 'v' || c == '+' || c == '-' || c == '*' || c == '/');
}

typedef struct {
	t_object obj;
	t_flin flin;
	t_note note;
	t_float oct;          /* # of semitone steps per octave */
	uint16_t siz;         /* current scale size */
	unsigned char strict; /* strict scale size toggle */
} t_music;

static inline t_float music_step(t_music *x, t_float *fp, int d, int n) {
	int i = d % n;
	int neg = i < 0;
	if (neg) {
		i += n;
	}
	return ((i ? fp[i] : 0) + x->oct * (d / n - neg));
}

static inline t_float music_interval(t_music *x, t_float *fp, t_float f) {
	int d = f;
	int n = x->siz;
	t_float step = music_step(x, fp, d, n);
	if (f != d) { // between two intervals
		int dir = f < 0 ? -1 : 1;
		t_float next = music_step(x, fp, d + dir, n);
		step += dir * (f - d) * (next - step);
	}
	return step;
}

static inline t_float music_getfloat(t_music *x, t_float *temp, const char *cp) {
	// ampersand before the number means it's a reference to the scale by index
	int ref = (*cp == '&');
	t_float f = cp[ref] ? strtof(cp + ref, 0) : 1;
	if (ref) {
		f = music_interval(x, temp, f);
	}
	return f;
}

static inline void music_operate(t_float *fp, char c, t_float f) {
	switch (c) {
	case '+':
	case '^': *fp += f; break;

	case '-':
	case 'v': *fp -= f; break;

	case '*': *fp *= f; break;

	case '/': *fp /= f; break;
	}
}

static void music_ptr(t_music *x, t_symbol *s) {
	post("%s%s%d", s->s_name, *s->s_name ? ": " : "", x->flin.siz);
}

static void music_print(t_music *x, t_symbol *s) {
	t_float *fp = x->flin.fp;
	if (*s->s_name) {
		startpost("%s: ", s->s_name);
	}
	for (int i = x->siz; i--; fp++) {
		startpost("%g ", *fp);
	}
	endpost();
}

static inline int revindex(int i, int n) {
	i %= n;
	if (i < 0) {
		i += n;
	}
	return i;
}

static int music_scale(t_music *x, t_flin *flin, int n, int ac, t_atom *av) {
	int siz = x->siz;
	if (n < 0) {
		n = revindex(n, siz);
	}
	switch (flin_resize(flin, &x->obj, n + ac)) {
	case -2: return (x->siz = 0);
	case -1: return siz;
	}

	t_float temp[siz]; // reference to unaltered values
	memcpy(temp, flin->fp, siz * sizeof(t_float));

	t_float *fp;
	for (; ac--; av++) {
		fp = flin->fp + n;
		if (av->a_type == A_FLOAT) {
			*fp = av->a_w.w_float;
			n++;
		} else if (av->a_type == A_SYMBOL) {
			const char *cp = av->a_w.w_symbol->s_name;
			int z; // inner arg count
			{
				int m = siz - n; // # of args left from original scale size
				if (m < 1) {
					m = 1;
				}
				char *p;
				z = strtol(cp, &p, 10); // check for a manually set arg count
				if (cp != p) {
					cp = p;
					if (z < 0) {
						z = revindex(z, m);
					}
					switch (flin_resize(flin, &x->obj, z + n + ac)) {
					case -2: return (x->siz = 0);
					case -1: return n;
					}
				} else {
					z = m;
				}
			}

			char c = cp[0];
			if (c == '&') {
				*fp = music_interval(x, temp, (cp[1] ? strtof(cp + 1, 0) : 1));
			} else if (isoperator(c)) {
				if (cp[0] == cp[1]) { // ++, --, etc.
					// do the same shift for all intervals that follow
					t_float f = music_getfloat(x, temp, cp + 2);
					for (; z--; n++, fp++) {
						music_operate(fp, c, f);
					}
					continue;
				} else {
					music_operate(fp, c, music_getfloat(x, temp, cp + 1));
				}
			} else if (c == '<' || c == '>') { // scale inversion
				int mvrt = cp[0] == cp[1]; // << or >> moves the root
				cp += 1 + mvrt;
				t_float f = (c - '=') * (*cp ? strtof(cp, 0) : 1); // direction and amount
				t_float *tp = temp + n;
				t_float oct = x->oct;
				t_float root = fp[0];

				int q, d = f;
				int neg = f < 0;
				int frac = f != d;
				int octs = (d + (neg && !frac)) / z - neg;
				int i = d % z;
				if (i < 0) {
					i += z;
				}

				tp[0] = 0;
				if (frac) {
					f -= d;
					int j;
					if (neg) {
						f += 1;
						j = i;
						i = (d - 1) % z;
						if (i < 0) i += z;
					} else {
						j = (d + 1) % z;
						if (j < 0) j += z;
					}
					t_float a = (i ? fp[i] : 0);
					t_float b = (j ? fp[j] : oct);
					t_float oa = oct - a, ob = oct - b;
					t_float g = 1 - f;
					d = i, q = z - i;
					for (i = d; --i >= 0;) {
						fp[i + q] = g * (tp[i] + oa) + f * (tp[i + 1] + ob);
					}
					if (--q) {
						fp[q] = g * (tp[z - 1] - a) + f * (ob);
					}
					for (i = q; --i > 0;) {
						fp[i] = g * (tp[i + d] - a) + f * (tp[i + d + 1] - b);
					}
					if (mvrt) {
						fp[0] = root + g * a + f * b + oct * octs;
					}
				} else {
					t_float a = (i ? fp[i] : 0);
					t_float oa = oct - a;
					d = i, q = z - i;
					for (i = d; --i >= 0;) {
						fp[i + q] = tp[i] + oa;
					}
					for (i = q; --i > 0;) {
						fp[i] = tp[i + d] - a;
					}
					if (mvrt) {
						fp[0] = root + a + oct * octs;
					}
				}
				tp[0] = root;
				n += z;
				continue;
			} else if (isoperator(cp[1])) { // current value ± semitones
				music_operate(fp, cp[1], music_getfloat(x, temp, cp + 2));
			}
			n++;
		}
	}
	return n;
}

static inline int music_i(t_music *x, t_flin *flin, int i, int ac, t_atom *av) {
	return music_scale(x, flin, i, ac, av);
}

static inline int music_x(t_music *x, t_flin *flin, int i, int ac, t_atom *av) {
	music_scale(x, flin, i, ac, av);
	return 0;
}

static inline int music_z(t_music *x, t_flin *flin, int i, int ac, t_atom *av) {
	if (x->strict) {
		return music_x(x, flin, i, ac, av);
	} else {
		return music_i(x, flin, i, ac, av);
	}
}

static void music_list(t_music *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	int n = music_z(x, &x->flin, 0, ac, av);
	if (n) {
		x->siz = n;
	}
}

static void music_f(t_music *x, t_float f, char c, t_float g);

static void music_float(t_music *x, t_float f) {
	music_f(x, f, 0, 0);
}

static int music_any(t_music *x, t_flin *flin, t_symbol *s, int ac, t_atom *av) {
	const char *cp = s->s_name;
	int n = 0;
	if (!ac) {
		char *p;
		t_float f = strtof(cp, &p);
		if (cp != p && p[0] != p[1] && isoperator(*p)) { // interval ± semitones
			music_f(x, f, *p, strtof(p + 1, 0));
		} else {
			t_atom atom = { .a_type = A_SYMBOL ,.a_w = {.w_symbol = s} };
			n = music_z(x, flin, 0, 1, &atom);
		}
	} else switch (*cp) {
	case '!':
		n = music_i(x, flin, atoi(cp + 1), ac, av); break; // lazy
	case '@':
		n = music_z(x, flin, atoi(cp + 1), ac, av); break; // default
	case '#':
		n = music_x(x, flin, atoi(cp + 1), ac, av); break; // strict
	default: {
		t_atom atoms[ac + 1];
		atoms[0] = (t_atom){ .a_type = A_SYMBOL ,.a_w = {.w_symbol = s} };
		memcpy(atoms + 1, av, ac * sizeof(t_atom));
		n = music_z(x, flin, 0, ac + 1, atoms);
	}
	}
	return n;
}

static void music_anything(t_music *x, t_symbol *s, int ac, t_atom *av) {
	int n = music_any(x, &x->flin, s, ac, av);
	if (n) {
		x->siz = n;
	}
}

static void music_symbol(t_music *x, t_symbol *s) {
	music_anything(x, s, 0, 0);
}

static void music_size(t_music *x, t_float f) {
	int i = f;
	if (i < 0) {
		i = i % x->siz + x->siz;
	} else if (i < 1) {
		i = 1;
	}
	switch (flin_resize(&x->flin, &x->obj, i)) {
	case -2: x->siz = 0;
	case -1: break;
	default: x->siz = i;
	}
}

static void music_strict(t_music *x, t_float f) {
	x->strict = f;
}

static void music_octave(t_music *x, t_float f) {
	x->oct = f;
}

static void music_ref(t_music *x, t_float f) {
	note_ref(&x->note, f);
}

static void music_tet(t_music *x, t_float f) {
	note_tet(&x->note, f);
}

static void music_octet(t_music *x, t_float f) {
	music_octave(x, f);
	music_tet(x, f);
}

static void music_set(t_music *x, t_symbol *s, int ac, t_atom *av) {
	(void)s;
	note_set(&x->note, ac, av);
}

static t_music *music_new(t_class *mclass, int n) {
	t_music *x = (t_music *)pd_new(mclass);

	x->siz = n;
	flin_alloc(&x->flin, n);

	t_atom atms[] = {
	  {.a_type = A_FLOAT, .a_w = {.w_float = 440}}
	, {.a_type = A_FLOAT, .a_w = {.w_float = 12 }}
	};
	note_set(&x->note, 2, atms);
	x->oct = x->note.tet;
	x->strict = 0;

	return x;
}

static t_class *class_music
(t_symbol *s, t_newmethod newm, t_method free, size_t size) {
	t_class *mclass = class_new(s, newm, free, size, 0, A_GIMME, 0);
	class_addfloat(mclass, music_float);
	class_addsymbol(mclass, music_symbol);
	class_addlist(mclass, music_list);
	class_addanything(mclass, music_anything);

	class_addmethod(mclass, (t_method)music_ptr, gensym("ptr"), A_DEFSYM, 0);
	class_addmethod(mclass, (t_method)music_print, gensym("print"), A_DEFSYM, 0);
	class_addmethod(mclass, (t_method)music_set, gensym("set"), A_GIMME, 0);
	class_addmethod(mclass, (t_method)music_ref, gensym("ref"), A_FLOAT, 0);
	class_addmethod(mclass, (t_method)music_tet, gensym("tet"), A_FLOAT, 0);
	class_addmethod(mclass, (t_method)music_octet, gensym("ot"), A_FLOAT, 0);
	class_addmethod(mclass, (t_method)music_size, gensym("size"), A_FLOAT, 0);
	class_addmethod(mclass, (t_method)music_octave, gensym("oct"), A_FLOAT, 0);
	class_addmethod(mclass, (t_method)music_strict, gensym("strict"), A_FLOAT, 0);

	return mclass;
}
