#ifndef HAVE_STRNDUP
#define HAVE_STRNDUP
static inline char *strndup(const char *s, size_t n)
{
    char *result;
    size_t len = strlen (s);
    if (n < len) len = n;
    result = (char *) malloc (len + 1);
    if (!result) return 0;
    result[len] = '\0';
    return (char *) strncpy (result, s, len);
}
#endif /*HAVE_STRNDUP*/

