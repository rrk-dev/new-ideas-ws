// vv_json_schema_to_gbnf (LLM-05): profile JSON Schema -> GBNF using
// llama.cpp's converter (common/json-schema-to-grammar.cpp, built as the
// static `vv_jsg` lib without llama-common). Verified at llama.cpp v0.6.0:
// `std::string json_schema_to_grammar(const common_json&, bool force_gbnf)`,
// `common_json::parse(const std::string&)` (throws common_json_error),
// conversion errors throw std::invalid_argument.
#include <cstdlib>
#include <cstring>
#include <new>
#include <stdexcept>
#include <string>

#include "json-schema-to-grammar.h"
#include "json.h"
#include "vv_llama.h"

extern "C" int32_t vv_json_schema_to_gbnf(const char* schema_json, char** out_gbnf) {
  if (!schema_json || !out_gbnf) return VV_E_INVALID_ARG;
  *out_gbnf = nullptr;
  try {
    common_json schema = common_json::parse(std::string(schema_json));
    std::string g = json_schema_to_grammar(schema, /*force_gbnf=*/true);
    char* s = static_cast<char*>(malloc(g.size() + 1));
    if (!s) return VV_E_OOM;
    memcpy(s, g.data(), g.size() + 1);
    *out_gbnf = s;
    return VV_OK;
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (const std::exception&) {
    return VV_E_INVALID_ARG;  // not JSON, or a schema the converter rejects
  } catch (...) {
    return VV_E_INTERNAL;
  }
}
