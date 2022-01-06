#ifndef _LDK_HEADER_VER
static inline int _ldk_strncmp(const char *s1, const char *s2, uint64_t n) {
	if (n && *s1 != *s2) return 1;
	while (n && *s1 != 0 && *s2 != 0) {
		s1++; s2++; n--;
		if (n && *s1 != *s2) return 1;
	}
	return 0;
}

#define _LDK_HEADER_VER "v0.0.104-7-g557c7143fddde4a3"
#define _LDK_C_BINDINGS_HEADER_VER "v0.0.104.0-1-g66ae845b5d7a8e94-dirty"
static inline const char* check_get_ldk_version() {
	LDKStr bin_ver = _ldk_get_compiled_version();
	if (_ldk_strncmp(_LDK_HEADER_VER, (const char*)bin_ver.chars, bin_ver.len) != 0) {
	// Version mismatch, we don't know what we're running!
		return 0;
	}
	return _LDK_HEADER_VER;
}
static inline const char* check_get_ldk_bindings_version() {
	LDKStr bin_ver = _ldk_c_bindings_get_compiled_version();
	if (_ldk_strncmp(_LDK_C_BINDINGS_HEADER_VER, (const char*)bin_ver.chars, bin_ver.len) != 0) {
	// Version mismatch, we don't know what we're running!
		return 0;
	}
	return _LDK_C_BINDINGS_HEADER_VER;
}
#endif /* _LDK_HEADER_VER */
