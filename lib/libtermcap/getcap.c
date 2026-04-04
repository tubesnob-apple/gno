/*
 * getcap.c -- BSD capability database access routines for GNO/ME
 *
 * Implements: cgetent, cgetset, cgetclose, cgetnum, cgetstr, cgetcap
 *
 * Based on the 4.4BSD interface as used by lib/libtermcap/termcap.c.
 * Written for ORCA/C 2.2.2 targeting 65816 (16-bit int, 32-bit long/pointer).
 *
 * Termcap file format:
 *   # comment
 *   name1|name2|...:cap:cap#num:cap=str:tc=name:
 *   Lines ending with \ are continued on the next line.
 *
 * Return values (cgetent):
 *   0   found
 *  -1   not found
 *  -2   database inaccessible
 *  -3   tc= loop detected
 *
 * $Id: getcap.c,v 1.0 2026/04/03 Exp $
 */

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

/* Maximum size of a single capability entry (joined continuation lines). */
#define CAPBUFSIZ	4096

/* Maximum tc= chain depth before declaring a loop. */
#define MAX_TC_DEPTH	32

/* Entry prepended by cgetset(). */
static char *_cg_setbuf = NULL;

/* ── Internal helpers ──────────────────────────────────────────────────────── */

/*
 * Read one logical entry from a file descriptor (joining continuation lines).
 * Returns number of bytes placed in buf, or -1 on I/O error, 0 on EOF.
 * buf must be CAPBUFSIZ bytes.  The entry is NUL-terminated and has no
 * trailing newline.
 */
static int
read_entry(int fd, char *buf)
{
	int len = 0;
	int in_entry = 0;
	char ch;
	int n;

	while (len < CAPBUFSIZ - 1) {
		n = read(fd, &ch, 1);
		if (n < 0)
			return -1;
		if (n == 0) {
			buf[len] = '\0';
			return len;
		}

		if (ch == '\n') {
			if (len > 0 && buf[len - 1] == '\\') {
				/* continuation: remove the backslash, skip leading ws */
				len--;
				while (len < CAPBUFSIZ - 1) {
					n = read(fd, &ch, 1);
					if (n <= 0)
						break;
					if (ch != ' ' && ch != '\t')
						break;
				}
				/* ch now holds first non-ws char of next line */
				if (n > 0) {
					buf[len++] = ch;
				}
				continue;
			}
			/* end of logical entry */
			buf[len] = '\0';
			return len;
		}

		/* skip comment lines (start with #) that we haven't begun yet */
		if (len == 0 && ch == '#') {
			/* consume rest of line */
			while ((n = read(fd, &ch, 1)) > 0 && ch != '\n')
				;
			continue;
		}

		/* skip blank lines between entries */
		if (len == 0 && (ch == '\n' || ch == '\r'))
			continue;

		/* leading whitespace = continuation of previous entry → skip as separator */
		if (len == 0 && (ch == ' ' || ch == '\t'))
			continue;

		buf[len++] = ch;
		in_entry = 1;
	}

	buf[len] = '\0';
	return len;
}

/*
 * Check whether a capability entry (starting with the name field) matches
 * any of the names in the '|'-separated names list before the first ':'.
 * Returns 1 if matched, 0 otherwise.
 */
static int
name_match(const char *entry, const char *name)
{
	const char *p = entry;
	const char *start;
	int namelen = strlen(name);

	while (*p && *p != ':') {
		start = p;
		while (*p && *p != '|' && *p != ':')
			p++;
		if ((int)(p - start) == namelen &&
		    strncmp(start, name, namelen) == 0)
			return 1;
		if (*p == '|')
			p++;
	}
	return 0;
}

/*
 * Extract the tc= value from a capability entry.
 * Writes the name into tcname (NUL-terminated, up to tcnamelen bytes).
 * Returns 1 if tc= was found, 0 otherwise.
 */
static int
get_tc(const char *entry, char *tcname, int tcnamelen)
{
	const char *p = entry;

	/* skip the names field */
	while (*p && *p != ':')
		p++;

	while (*p == ':') {
		p++;
		if (p[0] == 't' && p[1] == 'c' && p[2] == '=') {
			int i = 0;
			p += 3;
			while (*p && *p != ':' && i < tcnamelen - 1)
				tcname[i++] = *p++;
			tcname[i] = '\0';
			return 1;
		}
		/* skip to next capability */
		while (*p && *p != ':')
			p++;
	}
	return 0;
}

/*
 * Search one database file (by path) for name.
 * Returns a malloc'd copy of the full entry in *result (caller frees),
 * or NULL if not found or error.
 */
static char *
search_file(const char *path, const char *name)
{
	int fd;
	static char buf[CAPBUFSIZ];
	int n;

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return NULL;

	while ((n = read_entry(fd, buf)) > 0) {
		if (name_match(buf, name)) {
			close(fd);
			return strdup(buf);
		}
	}

	close(fd);
	return NULL;
}

/*
 * Resolve tc= references, appending capabilities from referenced entries.
 * entry is the current (malloc'd) entry.  db_array is the search path.
 * depth tracks recursion to detect loops.
 * Returns a new malloc'd string with tc= fully resolved, or NULL on error.
 * Frees entry.
 */
static char *
resolve_tc(char *entry, char **db_array, int depth)
{
	char tcname[64];
	char *ref;
	char *resolved;
	char *p;
	size_t entrylen, reflen;
	int i;

	if (depth > MAX_TC_DEPTH) {
		free(entry);
		return NULL;	/* loop */
	}

	if (!get_tc(entry, tcname, sizeof(tcname)))
		return entry;	/* no tc= — done */

	/* find the referenced entry */
	ref = NULL;
	if (_cg_setbuf && name_match(_cg_setbuf, tcname))
		ref = strdup(_cg_setbuf);
	if (!ref && db_array) {
		for (i = 0; db_array[i]; i++) {
			ref = search_file(db_array[i], tcname);
			if (ref)
				break;
		}
	}

	if (!ref) {
		/* tc= target not found — strip the tc= and return */
		/* (termcap.c treats this as non-fatal) */
		return entry;
	}

	/* recursively resolve the referenced entry */
	ref = resolve_tc(ref, db_array, depth + 1);
	if (!ref) {
		free(entry);
		return NULL;
	}

	/*
	 * Append capabilities from ref (skipping its names field) to entry,
	 * but only capabilities not already present in entry.
	 * For simplicity, just concatenate — duplicates are benign for tgetstr/tgetnum.
	 */
	entrylen = strlen(entry);
	/* find ref's first ':' to skip the names field */
	p = strchr(ref, ':');
	if (!p) {
		free(ref);
		return entry;
	}
	reflen = strlen(p);

	resolved = (char *)malloc(entrylen + reflen + 1);
	if (!resolved) {
		free(ref);
		free(entry);
		return NULL;
	}

	strcpy(resolved, entry);
	/* ensure trailing ':' before appending */
	if (entrylen > 0 && resolved[entrylen - 1] != ':') {
		resolved[entrylen] = ':';
		entrylen++;
		resolved[entrylen] = '\0';
	}
	strcat(resolved, p + 1);	/* skip the ':' from ref names field */

	free(entry);
	free(ref);
	return resolved;
}

/* ── Public API ────────────────────────────────────────────────────────────── */

/*
 * cgetset -- prepend an entry string to all future cgetent searches.
 * Typically used when TERMCAP env var holds a full entry (not a filename).
 */
int
cgetset(char *ent)
{
	if (_cg_setbuf) {
		free(_cg_setbuf);
		_cg_setbuf = NULL;
	}
	if (ent == NULL)
		return 0;
	_cg_setbuf = strdup(ent);
	if (!_cg_setbuf)
		return -2;
	return 0;
}

/*
 * cgetclose -- reset getcap state.
 */
int
cgetclose(void)
{
	if (_cg_setbuf) {
		free(_cg_setbuf);
		_cg_setbuf = NULL;
	}
	return 0;
}

/*
 * cgetent -- look up terminal capability entry by name.
 *
 * Searches the set entry (cgetset), then each file in db_array.
 * On success, *buf is set to a malloc'd NUL-terminated capability string
 * with tc= references resolved.  Caller must free(*buf).
 *
 * Returns:  0 found, -1 not found, -2 db inaccessible, -3 tc= loop.
 */
int
cgetent(char **buf, char **db_array, char *name)
{
	char *entry = NULL;
	char *resolved;
	int i;

	/* check the prepended set entry first */
	if (_cg_setbuf && name_match(_cg_setbuf, name)) {
		entry = strdup(_cg_setbuf);
		if (!entry)
			return -2;
	}

	/* search the database files */
	if (!entry && db_array) {
		for (i = 0; db_array[i]; i++) {
			entry = search_file(db_array[i], name);
			if (entry)
				break;
		}
	}

	if (!entry)
		return -1;

	/* resolve tc= references */
	resolved = resolve_tc(entry, db_array, 0);
	if (!resolved)
		return -3;	/* loop */

	*buf = resolved;
	return 0;
}

/*
 * cgetcap -- find a capability of the given type in a capability record.
 *
 * type == ':' means boolean (just the id followed by ':' or end)
 * type == '#' means numeric (id#value)
 * type == '=' means string  (id=value)
 *
 * Returns pointer to the character after the id+type, or NULL if not found.
 * For boolean type, returns pointer to ':' or '\0' following the id.
 */
char *
cgetcap(char *buf, char *cap, int type)
{
	char *p = buf;
	int caplen = strlen(cap);

	/* skip the names field */
	while (*p && *p != ':')
		p++;

	while (*p == ':') {
		p++;
		if (strncmp(p, cap, caplen) == 0) {
			char *q = p + caplen;
			if (type == ':') {
				if (*q == ':' || *q == '\0')
					return q;
			} else {
				if (*q == (char)type)
					return q + 1;
			}
		}
		/* skip to next capability */
		while (*p && *p != ':')
			p++;
	}
	return NULL;
}

/*
 * cgetnum -- get a numeric capability value.
 * Finds cap#NUMBER in buf, stores result in *num.
 * Returns 0 on success, -1 if not found.
 */
int
cgetnum(char *buf, char *cap, long *num)
{
	char *p;

	p = cgetcap(buf, cap, '#');
	if (!p)
		return -1;

	/* parse decimal or octal number */
	if (*p == '0') {
		long val = 0;
		p++;
		while (*p >= '0' && *p <= '7')
			val = val * 8 + (*p++ - '0');
		*num = val;
	} else {
		long val = 0;
		while (*p >= '0' && *p <= '9')
			val = val * 10 + (*p++ - '0');
		*num = val;
	}
	return 0;
}

/*
 * cgetstr -- get a string capability value, decoding escape sequences.
 *
 * Finds cap=STRING in buf, allocates a decoded copy in *str (caller frees).
 * Returns length of decoded string on success, -1 if not found, -2 on malloc fail.
 *
 * Escape sequences recognized (termcap convention):
 *   \E or \e  →  ESC (0x1B)
 *   \n        →  NL  (0x0A)
 *   \r        →  CR  (0x0D)
 *   \t        →  TAB (0x09)
 *   \b        →  BS  (0x08)
 *   \f        →  FF  (0x0C)
 *   \0        →  NUL (0x00)
 *   \NNN      →  octal NNN
 *   \^        →  literal ^
 *   \\        →  literal backslash
 *   ^X        →  control-X (X & 0x1F)
 */
int
cgetstr(char *buf, char *cap, char **str)
{
	char *p;
	char *out;
	char *op;
	int len;
	char tmp[CAPBUFSIZ];

	p = cgetcap(buf, cap, '=');
	if (!p)
		return -1;

	/* decode into tmp */
	op = tmp;
	while (*p && *p != ':' && op < tmp + CAPBUFSIZ - 1) {
		if (*p == '\\') {
			p++;
			switch (*p) {
			case 'E': case 'e':  *op++ = '\033'; p++; break;
			case 'n':            *op++ = '\n';   p++; break;
			case 'r':            *op++ = '\r';   p++; break;
			case 't':            *op++ = '\t';   p++; break;
			case 'b':            *op++ = '\b';   p++; break;
			case 'f':            *op++ = '\f';   p++; break;
			case '0':            *op++ = '\0';   p++; break;
			case '\\':           *op++ = '\\';   p++; break;
			case '^':            *op++ = '^';    p++; break;
			default:
				if (*p >= '0' && *p <= '7') {
					/* octal */
					int val = 0;
					int cnt = 0;
					while (cnt < 3 && *p >= '0' && *p <= '7')
						val = val * 8 + (*p++ - '0'), cnt++;
					*op++ = (char)val;
				} else {
					*op++ = *p++;
				}
				break;
			}
		} else if (*p == '^') {
			p++;
			if (*p)
				*op++ = (char)((*p++) & 0x1F);
		} else {
			*op++ = *p++;
		}
	}
	*op = '\0';

	len = op - tmp;
	out = (char *)malloc(len + 1);
	if (!out)
		return -2;
	memcpy(out, tmp, len + 1);
	*str = out;
	return len;
}
