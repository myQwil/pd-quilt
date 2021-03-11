#include "flin.h"
#include "note.h"
#include <stdlib.h> // strtof
#include <string.h> // memcpy

static int isoperator(char c) {
	return (c=='^' || c=='v' || c=='+' || c=='-' || c=='*' || c=='/');
}

typedef struct {
	t_flin flin;
	t_note note;
	t_float oct;     /* # of semitone steps per octave */
	uint16_t siz;    /* current scale size */
	unsigned expl:1; /* explicit scale size toggle */
} t_music;

static void music_ptr(t_music *x ,t_symbol *s) {
	post("%s%s%d" ,s->s_name ,*s->s_name?": ":"" ,x->flin.siz);
}

static void music_peek(t_music *x ,t_symbol *s) {
	t_float *fp = x->flin.fp;
	if (*s->s_name) startpost("%s: " ,s->s_name);
	for (int i=x->siz; i--; fp++) startpost("%g " ,*fp);
	endpost();
}

static int gcd(int a ,int b) {
	int r;
	while (b)
	{	r = a % b;
		a = b;
		b = r;   }
	return a;
}

static void music_invert(t_music *x ,t_float *fp ,int mvrt ,int n ,int d) {
	int neg = d<0 ,octs = d/n;
	d %= n;
	if (!d)
	{	fp[0] += mvrt * x->oct * octs;
		return;   }
	d += n * neg;
	float shift = fp[d];
	fp[d] += fp[0] + mvrt * (shift + x->oct * (octs - neg));
	fp[0] = 0;

	int g = gcd(d ,n) ,r = n-d ,i;
	for (i = 0; i < g; i++)
	{	int temp = fp[i];
		int j = i;
		for (;;)
		{	int k = j + d;
			if (k >= n) k -= n;
			if (k == i) break;
			fp[j] = fp[k] - shift + x->oct * (j >= r);
			j = k;   }
		fp[j] = temp - shift + x->oct * (j >= r);   }
}

static void music_operate(t_float *fp ,char c ,t_float f) {
	switch (c)
	{	case '+':
		case '^': *fp += f; break;

		case '-':
		case 'v': *fp -= f; break;

		case '*': *fp *= f; break;

		case '/': *fp /= f; break;   }
}

static int music_scale(t_music *x ,int i ,int ac ,t_atom *av) {
	if (flin_resize(&x->flin ,i+ac) < 0)
		return x->siz;

	int n = i;
	t_float *fp = x->flin.fp + i;
	for (; ac--; av++)
	{	if (av->a_type == A_FLOAT)
		{	*fp = av->a_w.w_float;
			n++ ,fp++;   }
		else if (av->a_type == A_SYMBOL)
		{	const char *cp = av->a_w.w_symbol->s_name;
			char *p;
			int m = x->siz - n;
			if (m <= 0) m = 1;
			i = strtol(cp ,&p ,10);
			if (cp != p)
			{	cp = p;
				if (i < 0) i = i % m + m;
				int res = flin_resize(&x->flin ,i+ac+n);
				if      (res > 0) fp = x->flin.fp + n;
				else if (res < 0) break;   }
			else i = m;

			char c = cp[0];
			if (isoperator(c))
			{	if (cp[0] == cp[1])
				{	t_float f = cp[2] ? strtof(cp+2,0) : 1;
					for (; i--; n++ ,fp++)
						music_operate(fp ,c ,f);
					continue;   }
				else music_operate(fp ,c ,(cp[1] ? strtof(cp+1,0) : 1));   }
			else if (c=='<' || c=='>')
			{	int mvrt = cp[0] == cp[1];
				cp += 1 + mvrt;
				music_invert(x ,fp ,mvrt ,i ,(c-'=') * (*cp ? atoi(cp) : 1));
				n+=i ,fp+=i;
				continue;   }
			else if (isoperator(cp[1]))
				music_operate(fp ,cp[1] ,(cp[2] ? strtof(cp+2,0) : 1));
			n++ ,fp++;   }   }
	return n;
}

static void music_i(t_music *x ,int i ,int ac ,t_atom *av) {
	x->siz = music_scale(x ,i ,ac ,av);
}

static void music_x(t_music *x ,int i ,int ac ,t_atom *av) {
	music_scale(x ,i ,ac ,av);
}

static void music_z(t_music *x ,int i ,int ac ,t_atom *av) {
	if (x->expl)
	     music_x(x ,i ,ac ,av);
	else music_i(x ,i ,ac ,av);
}

static void music_list(t_music *x ,t_symbol *s ,int ac ,t_atom *av) {
	music_z(x ,0 ,ac ,av);
}

static void music_f(t_music *x ,t_float f ,char c ,t_float g);

static void music_float(t_music *x ,t_float f) {
	music_f(x ,f ,0 ,0);
}

static void music_anything(t_music *x ,t_symbol *s ,int ac ,t_atom *av) {
	const char *cp = s->s_name;
	if (!ac)
	{	char *p;
		t_float f = strtof(cp ,&p);
		if (cp!=p && p[0]!=p[1] && isoperator(*p))
		{	cp = p;
			t_float g = strtof(cp+1,0);
			music_f(x ,f ,*cp ,g);   }
		else
		{	t_atom atom = {A_SYMBOL ,{.w_symbol = s}};
			music_z(x ,0 ,1 ,&atom);   }   }
	else if (*cp == '!') music_i(x ,strtol(cp+1,0,10) ,ac ,av); // implicit
	else if (*cp == '@') music_x(x ,strtol(cp+1,0,10) ,ac ,av); // explicit
	else if (*cp == '#') music_z(x ,strtol(cp+1,0,10) ,ac ,av); // default
	else
	{	t_atom atoms[ac+1];
		atoms[0] = (t_atom){A_SYMBOL ,{.w_symbol = s}};
		memcpy(atoms+1 ,av ,ac * sizeof(t_atom));
		music_z(x ,0 ,ac+1 ,atoms);   }
}

static void music_symbol(t_music *x ,t_symbol *s) {
	music_anything(x ,s ,0 ,0);
}

static void music_size(t_music *x ,t_floatarg n) {
	if (flin_resize(&x->flin ,n) < 0)
		return;
	x->siz = n;
}

static void music_expl(t_music *x ,t_floatarg f) {
	x->expl = f;
}

static void music_octave(t_music *x ,t_floatarg f) {
	x->oct = f;
}

static void music_ref(t_music *x ,t_floatarg f) {
	note_ref(&x->note ,f);
}

static void music_tet(t_music *x ,t_floatarg f) {
	note_tet(&x->note ,f);
}

static void music_octet(t_music *x ,t_floatarg f) {
	music_octave(x ,f);
	music_tet(x ,f);
}

static void music_set(t_music *x ,t_symbol *s ,int ac ,t_atom *av) {
	note_set(&x->note ,ac ,av);
}

static t_music *music_new(t_class *mclass ,int ac) {
	t_music *x = (t_music *)pd_new(mclass);

	x->siz = x->flin.ins = ac;
	flin_alloc(&x->flin ,ac);

	t_atom atms[] = { {A_FLOAT ,{440}} ,{A_FLOAT ,{12}} };
	note_set(&x->note ,2 ,atms);
	x->oct = x->note.tet;
	x->expl = 0;

	return x;
}

static t_class *music_setup
(t_symbol *s ,t_newmethod newm ,t_method free ,size_t size) {
	t_class *mclass = class_new(s ,newm ,free ,size ,0 ,A_GIMME ,0);
	class_addfloat   (mclass ,music_float);
	class_addsymbol  (mclass ,music_symbol);
	class_addlist    (mclass ,music_list);
	class_addanything(mclass ,music_anything);

	class_addmethod(mclass ,(t_method)music_ptr
		,gensym("ptr")  ,A_DEFSYM ,0);
	class_addmethod(mclass ,(t_method)music_peek
		,gensym("peek") ,A_DEFSYM ,0);
	class_addmethod(mclass ,(t_method)music_set
		,gensym("set")  ,A_GIMME  ,0);
	class_addmethod(mclass ,(t_method)music_size
		,gensym("n")    ,A_FLOAT  ,0);
	class_addmethod(mclass ,(t_method)music_expl
		,gensym("expl") ,A_FLOAT  ,0);
	class_addmethod(mclass ,(t_method)music_octave
		,gensym("oct")  ,A_FLOAT  ,0);
	class_addmethod(mclass ,(t_method)music_ref
		,gensym("ref")  ,A_FLOAT  ,0);
	class_addmethod(mclass ,(t_method)music_tet
		,gensym("tet")  ,A_FLOAT  ,0);
	class_addmethod(mclass ,(t_method)music_octet
		,gensym("ot")   ,A_FLOAT  ,0);

	return mclass;
}
