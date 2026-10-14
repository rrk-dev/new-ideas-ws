/* [FND-06] Host smoke test for the C bridge. */
#include <stdio.h>
#include <string.h>

#include "vv_bridge.h"

static int fail(const char* what) {
  fprintf(stderr, "FAIL: %s\n", what);
  return 1;
}

int main(void) {
  /* STT-02: register backends first (required in VV_GGML_BACKEND_DL builds). */
  if (vv_backends_load(NULL, 0) != VV_OK) return fail("vv_backends_load");
  if (vv_abi_version() != VV_ABI_VERSION) return fail("abi version");
  if (strcmp(vv_version(), "0.1.0") != 0) return fail("vv_version");
  if (strlen(vv_whisper_version()) == 0) return fail("whisper version");
  if (strlen(vv_ggml_version()) == 0) return fail("ggml version");
  /* Both libraries are linked and share one ggml. */
  if (strlen(vv_whisper_system_info()) == 0) return fail("whisper sysinfo");
  if (strlen(vv_llama_system_info()) == 0) return fail("llama sysinfo");
  printf("vv_native %s (abi %d) whisper %s ggml %s\n", vv_version(),
         vv_abi_version(), vv_whisper_version(), vv_ggml_version());
  return 0;
}
