/*
 * t_unicode_str.c — C11 Unicode string literals and universal character names
 * EXPECT: compile success
 *
 * Notes on ORCA/C support:
 *   - u8"..." string literals are supported
 *   - \u (4-hex-digit BMP UCNs) in strings are supported
 *   - \U (8-hex-digit) UCNs are NOT supported (code point too large for
 *     the IIgs execution character set, which is 8-bit)
 *   - char16_t / char32_t (u"..." / U"...") are NOT supported
 *   - L"..." wide strings may or may not be available
 */

/* u8 string literal — UTF-8, type const char[] */
const char *u8str  = u8"Hello";
const char *u8_bmp = u8"\u00E9";    /* é — U+00E9, BMP, fits in execution set */

/* Universal character names in string literals (\u only — Mac Roman charset).
 * Only characters present in the IIgs execution charset (Mac Roman) are valid.
 * U+00E9 é, U+00F1 ñ, U+00FC ü, U+00C0 À are all in Mac Roman. */
const char *ucn_str   = "caf\u00E9";  /* "café" — é is U+00E9, in Mac Roman */
const char *ucn_tilde = "ma\u00F1ana"; /* "mañana" — ñ is U+00F1, in Mac Roman */

/* UCN in identifier — if ORCA/C supports it */
/* Skipped: identifier UCNs are rarely tested and ORCA/C support unclear */

int test_unicode(void) {
    return (u8str != 0 && u8_bmp != 0 && ucn_str != 0 && ucn_tilde != 0) ? 0 : 1;
}
