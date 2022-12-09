#include "m_pd.h"

typedef const char *err_t;

typedef struct {
	t_symbol **arr; /* m3u list of tracks */
	t_symbol *dir;  /* starting directory */
	int size;       /* size of the list */
	int max;        /* size of the memory allocation */
} t_playlist;

	// prevents self-referencing m3u's from causing an infinite loop
static int depth;

#define M3U_MAIN(deeper, increment) \
	char line[MAXPDSTRING]; \
	while (fgets(line, MAXPDSTRING, fp) != NULL) { \
		line[strcspn(line, "\r\n")] = '\0'; \
		int isabs = (line[0] == '/'); \
		if ((isabs ? 0 : dlen) + strlen(line) >= MAXPDSTRING) { \
			continue; \
		} \
		strcpy(dir + dlen, line); \
		char *ext = strrchr(line, '.'); \
		if (ext && !strcmp(ext + 1, "m3u")) { \
			char *fname = strrchr(line, '/'); \
			int len = (fname) ? ++fname - line : 0; \
			FILE *m3u = fopen(dir, "r"); \
			if (m3u && depth < 0x100) { \
				depth++; \
				(deeper); \
				depth--; \
				fclose(m3u); \
			} \
		} else { \
			(increment); \
		} \
	}

static int m3u_size(FILE *fp, char *dir, int dlen) {
	int size = 0;
	M3U_MAIN (
	  size += m3u_size(m3u, dir, dlen + len)
	, size++
	)
	return size;
}

static int playlist_fill(t_playlist *pl, FILE *fp, char *dir, int dlen, int i) {
	int oldlen = strlen(pl->dir->s_name);
	M3U_MAIN (
	  i = playlist_fill(pl, m3u, dir, dlen + len, i)
	, pl->arr[i++] = gensym(dir + oldlen)
	)
	return i;
}

static inline err_t playlist_m3u(t_playlist *pl, t_symbol *s) {
	FILE *fp = fopen(s->s_name, "r");
	if (!fp) {
		return "Could not open m3u";
	}

	depth = 1;
	char dir[MAXPDSTRING];
	strcpy(dir, pl->dir->s_name);
	int size = m3u_size(fp, dir, strlen(dir));
	if (size < 1) {
		return "Playlist is empty";
	}
	if (size > pl->max) {
		pl->arr = (t_symbol **)resizebytes(pl->arr
		, pl->max * sizeof(t_symbol *), size * sizeof(t_symbol *));
		pl->max = size;
	}
	pl->size = size;
	rewind(fp);

	playlist_fill(pl, fp, dir, strlen(pl->dir->s_name), 0);
	fclose(fp);
	return 0;
}
