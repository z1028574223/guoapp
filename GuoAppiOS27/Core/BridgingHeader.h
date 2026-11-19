#ifndef GuoAppiOS27_Bridging_Header_h
#define GuoAppiOS27_Bridging_Header_h
#include <stdbool.h>
#include <stddef.h>

/* Go core (native/bridge, -buildmode=c-archive) exports these two C symbols.
   The returned char* is allocated by Go and MUST be released with DuanjuFree. */
extern char *DuanjuRequest(char *input);
extern void DuanjuFree(char *value);

#endif
