/*
Game_Music_Emu library copyright (C) 2003-2009 Shay Green.
Sega Genesis YM2612 emulator copyright (C) 2002 Stephane Dallongeville.
MAME YM2612 emulator copyright (C) 2003 Jarek Burczynski, Tatsuyuki Satoh
Nuked OPN2 emulator copyright (C) 2017 Alexey Khokholov (Nuke.YKT)

--
Shay Green <gblargg@gmail.com>
*/

#include "m_pd.h"
#include <gme.h>
#include <string.h>

#ifndef NCH
#define NCH 2
#endif

#if defined MSW                   // when compiling for Windows
#define EXPORT __declspec(dllexport)
#elif __GNUC__ >= 4               // else, when compiling with GCC 4.0 or higher
#define EXPORT __attribute__((visibility("default")))
#endif
#ifndef EXPORT
#define EXPORT                    // empty definition for other cases
#endif

#undef byte
#define byte byte_
typedef unsigned char byte;
const int mask_size = 8;

static gme_err_t hnd_err( const char *str ) {
	if (str) post("Error: %s" ,str);
	return str;
}

typedef struct _gmepd {
	t_object x_obj;
	Music_Emu *emu;   /* emulator object */
	Music_Emu *info;  /* info-only emu fallback */
	t_symbol *path;   /* path to the most recently read file */
	int track;        /* current track number */
	byte mask;        /* muting mask */
	double tempo;     /* current tempo */
	double speed;     /* current speed */
	unsigned read:1;  /* when a file has been read but not yet played */
	unsigned open:1;  /* when a request for playback is made */
	unsigned stop:1;  /* flag to start from beginning on next playback */
	unsigned play:1;  /* play/pause toggle */
	t_outlet *o_meta; /* outputs track metadata */
} t_gmepd;

#define xpath x->path->s_name

static void gmepd_m3u(t_gmepd *x ,Music_Emu *emu) {
	char m3u_path [256 + 5];
	strncpy(m3u_path ,xpath ,256);
	m3u_path [256] = 0;
	char *p = strrchr(m3u_path ,'.');
	if (!p) p = m3u_path + strlen(m3u_path);
	strcpy(p ,".m3u");
	if (gme_load_m3u(emu ,m3u_path)) { } // ignore error
}

static Music_Emu *gmepd_emu(t_gmepd *x) {
	if (x->read && x->info) return x->info;
	else if (x->emu) return x->emu;
	else return NULL;
}

static void gmepd_time(t_gmepd *x ,t_floatarg f) {
	int track = f ? f : x->track;
	gme_info_t *info;
	Music_Emu *emu = gmepd_emu(x);
	if (emu && !hnd_err(gme_track_info(emu ,&info ,track-1)))
	{	t_atom flts[] =
		{	 { A_FLOAT ,{(t_float)(info->length > 0 ?
				info->length : info->play_length)} }
			,{ A_FLOAT ,{(t_float)info->fade_length} }   };
		gme_free_info(info);
		outlet_anything(x->o_meta ,gensym("time:") ,2 ,flts);   }
}

static void gmepd_start(t_gmepd *x) {
	if (!hnd_err(gme_start_track(x->emu ,x->track-1)))
	{	gme_set_fade(x->emu ,-1 ,0);
		x->stop = 0 ,x->play = 1;   }
}

static t_int *gmepd_perform(t_int *w) {
	t_gmepd *x = (t_gmepd *)(w[1]);
	t_sample *outs[NCH];
	for (int i=NCH; i--;) outs[i] = (t_sample *)(w[i+2]);
	int n = (int)(w[NCH+2]);

	if (x->open)
	{	gme_delete(x->emu); x->emu = NULL;
		if (!hnd_err(gme_open_file(xpath ,&x->emu ,sys_getsr() ,NCH>2)))
		{	gmepd_m3u(x ,x->emu);
			gme_ignore_silence (x->emu ,1        );
			gme_mute_voices    (x->emu ,x->mask  );
			gme_set_tempo      (x->emu ,x->tempo );
			gme_set_speed      (x->emu ,x->speed );
			if (x->track < 1 || x->track > gme_track_count(x->emu))
				x->track = 1;
			gmepd_start(x);   }
		x->open = x->read = 0;   }

	if (x->emu && x->play)
		 while (n--)
		 {	short buf[NCH];
			hnd_err(gme_play(x->emu ,NCH ,buf));
			for (int i=NCH; i--;)
				*outs[i]++ = buf[i] / (t_sample)32768;   }
	else while (n--) for (int i=NCH; i--;) *outs[i]++ = 0;
	return (w+NCH+3);
}

static void gmepd_open(t_gmepd *x ,t_symbol *s) {
	Music_Emu *info;
	if (!hnd_err(gme_open_file(s->s_name ,&info ,gme_info_only ,0)))
	{	x->path = s;
		x->track = x->read = 1;
		gme_delete(x->info); x->info = info;
		gmepd_m3u(x ,x->info);   }
	else x->read = 0;
	t_atom open = { A_FLOAT ,{(t_float)x->read} };
	outlet_anything(x->o_meta ,gensym("open:") ,1 ,&open);
}

static void gmepd_bang(t_gmepd *x) {
	if (x->read) x->open = 1;
	else if (x->stop && x->emu) gmepd_start(x);
	else x->play = !x->play;
}

static void gmepd_float(t_gmepd *x ,t_float f) {
	if (f <= 0)
	{	x->play = 0 ,x->stop = 1;
		return;   }
	else if (x->read) x->open = 1;

	Music_Emu *emu = gmepd_emu(x);
	if (emu && f > 0 && f <= gme_track_count(emu))
	{	x->track = f;
		if (x->emu) gmepd_start(x);   }
}

static void gmepd_stop(t_gmepd *x) {
	gmepd_float(x ,0);
}

static void gmepd_track(t_gmepd *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (!ac)
	{	t_atom flt = { A_FLOAT ,{(t_float)x->track} };
		outlet_anything(x->o_meta ,gensym("track:") ,1 ,&flt);   }
	else if (av->a_type == A_FLOAT)
	{	t_float f = av->a_w.w_float;
		Music_Emu *emu = gmepd_emu(x);
		if (emu && f > 0 && f <= gme_track_count(emu))
			x->track = f;   }
}

static void gmepd_tracks(t_gmepd *x) {
	Music_Emu *emu = gmepd_emu(x);
	t_float f = emu ? gme_track_count(emu) : 0;
	t_atom flt = { A_FLOAT ,{f} };
	outlet_anything(x->o_meta ,gensym("tracks:") ,1 ,&flt);
}

static const char *gmepd_meta
(t_gmepd *x ,gme_info_t *info ,const char *sym ,int *len ,char buf[33]) {
	const char *dict[][2] =
	{	 {"path"      ,xpath                                      }
		,{"system"    ,info->system                               }
		,{"game"      ,info->game                                 }
		,{"song"      ,info->song                                 }
		,{"author"    ,info->author                               }
		,{"copyright" ,info->copyright                            }
		,{"comment"   ,info->comment                              }
		,{"dumper"    ,info->dumper                               }
		,{"length"    ,(const char*)info->length                  }
		,{"fade"      ,(const char*)info->fade_length             }
		,{"track"     ,(const char*)x->track                      }
		,{"tracks"    ,(const char*)gme_track_count(gmepd_emu(x)) }
		,{"mask"      ,(const char*)x->mask                       }
		,{"bmask"     ,0                                          }   };
	int n = sizeof(dict) / sizeof(*dict);
	for (int i = 0; i < n; i++)
	{	if (!strcmp(sym ,dict[i][0]))
		{	if (len) *len = strlen(dict[i][0]);
			if (i >= 8)
			{	if (i == 13)
				{	int m = x->mask;
					sprintf(buf ,"%d%d%d%d%d%d%d%d" ,m&1 ,(m>>1)&1 ,(m>>2)&1
						,(m>>3)&1 ,(m>>4)&1 ,(m>>5)&1 ,(m>>6)&1 ,(m>>7)&1);   }
				else sprintf(buf ,"%ld" ,(intptr_t)dict[i][1]);
				return buf;   }
			else *buf = 0;
			return dict[i][1];   }   }
	*buf = 0;
	if (len) *len = 0;
	return 0;
}

static void gmepd_format(t_gmepd *x ,int ac ,t_atom *av) {
	gme_info_t *info;
	Music_Emu *emu = gmepd_emu(x);
	if (!emu || hnd_err(gme_track_info(emu ,&info ,x->track-1)))
	{	pd_error(x ,"gme~: %s" ,xpath);
		return;   }

	char buf[33];
	for (; ac--; av++) if (av->a_type == A_SYMBOL)
	{	const char *sym = av->a_w.w_symbol->s_name ,*dlr;
		while ( (dlr = strchr(sym ,'$')) )
		{	int len = dlr - sym;
			if (len)
			{	char before[len + 1];
				strncpy(before ,sym ,len);
				before[len] = 0;
				startpost("%s" ,before);
				sym += len;   }
			const char *meta = gmepd_meta(x ,info ,dlr+1 ,&len ,buf);
			if (meta) startpost("%s" ,meta);
			sym += len + 1;   }
		startpost("%s%s" ,sym ,ac ? " ":"");   }
	endpost();
	gme_free_info(info);
}

static void gmepd_send(t_gmepd *x ,t_symbol *s) {
	gme_info_t *info;
	Music_Emu *emu = gmepd_emu(x);
	if (!emu || hnd_err(gme_track_info(emu ,&info ,x->track-1)))
	{	pd_error(x ,"gme~: %s" ,xpath);
		return;   }

	char buf[33];
	const char *meta = gmepd_meta(x ,info ,s->s_name ,0 ,buf);
	if (meta)
	{	int len = strlen(s->s_name);
		char key[len + 2];
		strcpy(key ,s->s_name);
		strcpy(key+len ,":\0");
		t_atom val = { A_SYMBOL ,{.w_symbol = gensym(meta)} };
		outlet_anything(x->o_meta ,gensym(key) ,1 ,&val);   }
	else pd_error(x ,"gme~: attribute '%s' not found" ,s->s_name);
	gme_free_info(info);
}

static void gmepd_anything(t_gmepd *x ,t_symbol *s ,int ac ,t_atom *av) {
	gme_info_t *info;
	Music_Emu *emu = gmepd_emu(x);
	if (!emu || hnd_err(gme_track_info(emu ,&info ,x->track-1)))
	{	pd_error(x ,"gme~: %s" ,xpath);
		return;   }

	char buf[33];
	const char *meta = gmepd_meta(x ,info ,s->s_name ,0 ,buf);
	if (meta) post("%s: %s" ,s->s_name ,meta);
	else pd_error(x ,"gme~: no method for '%s'" ,s->s_name);
	gme_free_info(info);
}

static void gmepd_info_default(Music_Emu *emu ,int track) {
	gme_info_t *info;
	if (!hnd_err(gme_track_info(emu ,&info ,track-1)))
	{	startpost("%s" ,info->game);
		int c = gme_track_count(emu);
		int plist = c > 1;
		if (plist) startpost(" (%d/%d)" ,track ,c);
		if (*info->song) startpost("%s%s" ,(plist) ? " " : " - " ,info->song);
		endpost();
		gme_free_info(info);   }
}

static void gmepd_info(t_gmepd *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac) return gmepd_format(x ,ac ,av);

	Music_Emu *emu = gmepd_emu(x);
	if (emu) gmepd_info_default(emu ,x->track);
	else pd_error(x ,"gme~: %s" ,xpath);
}

static void gmepd_seek(t_gmepd *x ,t_floatarg f) {
	if (x->emu)
	{	gme_seek(x->emu ,f);
		gme_set_fade(x->emu ,-1 ,0);   }
}

static void gmepd_tempo(t_gmepd *x ,t_floatarg f) {
	x->tempo = f;
	if (x->emu) gme_set_tempo(x->emu ,x->tempo);
}

static void gmepd_speed(t_gmepd *x ,t_floatarg f) {
	x->speed = f;
	if (x->emu) gme_set_speed(x->emu ,x->speed);
}

static byte domask(byte mask ,int ac ,t_atom *av) {
	for (; ac--; av++) if (av->a_type == A_FLOAT)
	{	int d = av->a_w.w_float;
		if (!d)
		{	mask = 0;
			continue;   }
		if (d > 0) d--;
		d %= mask_size;
		if (d < 0) d += mask_size;
		mask ^= 1 << d;   }
	return mask;
}

static void gmepd_mute(t_gmepd *x ,t_symbol *s ,int ac ,t_atom *av) {
	x->mask = domask(x->mask ,ac ,av);
	if (x->emu) gme_mute_voices(x->emu ,x->mask);
}

static void gmepd_solo(t_gmepd *x ,t_symbol *s ,int ac ,t_atom *av) {
	byte mask = domask(~0 ,ac ,av);
	x->mask = (x->mask == mask) ? 0 : mask;
	if (x->emu) gme_mute_voices(x->emu ,x->mask);
}

static void gmepd_mask(t_gmepd *x ,t_symbol *s ,int ac ,t_atom *av) {
	if (ac && av->a_type == A_FLOAT)
	{	x->mask = av->a_w.w_float;
		if (x->emu) gme_mute_voices(x->emu ,x->mask);   }
	else
	{	t_atom flt = { A_FLOAT ,{(t_float)x->mask} };
		outlet_anything(x->o_meta ,gensym("mask:") ,1 ,&flt);   }
}

static void *gmepd_new(t_class *gmeclass ,t_symbol *s ,int ac ,t_atom *av) {
	t_gmepd *x = (t_gmepd *)pd_new(gmeclass);
	int i = NCH;
	while (i--) outlet_new(&x->x_obj ,&s_signal);
	x->o_meta = outlet_new(&x->x_obj ,0);
	if (ac) gmepd_solo(x ,NULL ,ac ,av);
	x->read = x->open = x->stop = x->play = 0;
	x->track = x->mask = 0;
	x->path = gensym("no track loaded");
	x->tempo = x->speed = 1.;
	return (x);
}

static void gmepd_free(t_gmepd *x) {
	gme_delete(x->emu);
	gme_delete(x->info);
}

static t_class *gmepd_setup(t_symbol *s ,t_newmethod newm) {
	t_class *gmeclass = class_new(s ,newm ,(t_method)gmepd_free
		,sizeof(t_gmepd) ,0 ,A_GIMME ,0);
	class_addbang    (gmeclass ,gmepd_bang);
	class_addfloat   (gmeclass ,gmepd_float);
	class_addanything(gmeclass ,gmepd_anything);

	class_addmethod(gmeclass ,(t_method)gmepd_open
		,gensym("open")  ,A_SYMBOL   ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_send
		,gensym("send")  ,A_SYMBOL   ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_seek
		,gensym("seek")  ,A_FLOAT    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_tempo
		,gensym("tempo") ,A_FLOAT    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_speed
		,gensym("speed") ,A_FLOAT    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_time
		,gensym("time")  ,A_DEFFLOAT ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_mute
		,gensym("mute")  ,A_GIMME    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_solo
		,gensym("solo")  ,A_GIMME    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_mask
		,gensym("mask")  ,A_GIMME    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_info
		,gensym("info")  ,A_GIMME    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_info
		,gensym("print") ,A_GIMME    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_track
		,gensym("track") ,A_GIMME    ,0);
	class_addmethod(gmeclass ,(t_method)gmepd_tracks
		,gensym("tracks") ,A_NULL);
	class_addmethod(gmeclass ,(t_method)gmepd_stop
		,gensym("stop")  ,A_NULL);
	class_addmethod(gmeclass ,(t_method)gmepd_bang
		,gensym("play")  ,A_NULL);

	return gmeclass;
}
