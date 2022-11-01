#include "m_pd.h"

typedef const char *err_t;

typedef struct {
	t_symbol **arr; /* m3u list of tracks */
	t_symbol *dir;  /* starting directory */
	int size;       /* size of the list */
	int max;        /* size of the memory allocation */
} t_playlist;

static int m3u_size(FILE *fp, char *dir, int dlen) {
	int size = 0;
	char line[MAXPDSTRING];
	while (fgets(line, MAXPDSTRING, fp) != NULL) {
		line[strcspn(line, "\r\n")] = '\0';
		int isabs = (line[0] == '/');
		if ((isabs ? 0 : dlen) + strlen(line) >= MAXPDSTRING) {
			continue;
		}
		char *ext = strrchr(line, '.');
		if (ext && !strcmp(ext + 1, "m3u")) {
			strcpy(dir + dlen, line);
			char *fname = strrchr(line, '/');
			int len = (fname) ? ++fname - line : 0;
			FILE *m3u = fopen(dir, "r");
			if (m3u) {
				size += m3u_size(m3u, dir, dlen + len);
				fclose(m3u);
			}
		} else {
			size++;
		}
	}
	return size;
}

static int playlist_fill(t_playlist *pl, FILE *fp, char *dir, int dlen, int i) {
	char line[MAXPDSTRING];
	int oldlen = strlen(pl->dir->s_name);
	while (fgets(line, MAXPDSTRING, fp) != NULL) {
		line[strcspn(line, "\r\n")] = '\0';
		int isabs = (line[0] == '/');
		if ((isabs ? 0 : dlen) + strlen(line) >= MAXPDSTRING) {
			continue;
		}
		strcpy(dir + dlen, line);
		char *ext = strrchr(line, '.');
		if (ext && !strcmp(ext + 1, "m3u")) {
			char *fname = strrchr(line, '/');
			int len = (fname) ? ++fname - line : 0;
			FILE *m3u = fopen(dir, "r");
			if (m3u) {
				i = playlist_fill(pl, m3u, dir, dlen + len, i);
				fclose(m3u);
			}
		} else {
			pl->arr[i++] = gensym(dir + oldlen);
		}
	}
	return i;
}

static inline err_t playlist_m3u(t_playlist *pl, t_symbol *s) {
	FILE *fp = fopen(s->s_name, "r");
	if (!fp) {
		return "Could not open m3u";
	}

	char dir[MAXPDSTRING];
	strcpy(dir, pl->dir->s_name);
	int size = m3u_size(fp, dir, strlen(dir));
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
