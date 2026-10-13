// String helpers that llama.cpp's JSON-schema→GBNF converter needs from
// common.cpp (LLM-05). Copied verbatim from native/llama.cpp/common/common.cpp
// at v0.6.0 (d812350, MIT, (c) the llama.cpp authors) so that `vv_jsg` does
// not link `llama-common` (which carries HTTP/download code — egress policy).
#include <climits>
#include <cstdarg>
#include <cstdio>
#include <sstream>
#include <string>
#include <vector>

#include "ggml.h"

std::string string_format(const char* fmt, ...) {
  va_list ap;
  va_list ap2;
  va_start(ap, fmt);
  va_copy(ap2, ap);
  int size = vsnprintf(NULL, 0, fmt, ap);
  GGML_ASSERT(size >= 0 && size < INT_MAX);  // NOLINT
  std::vector<char> buf(size + 1);
  int size2 = vsnprintf(buf.data(), size + 1, fmt, ap2);
  GGML_ASSERT(size2 == size);
  va_end(ap2);
  va_end(ap);
  return std::string(buf.data(), size);
}

std::string string_join(const std::vector<std::string>& values, const std::string& separator) {
  std::ostringstream result;
  for (size_t i = 0; i < values.size(); ++i) {
    if (i > 0) result << separator;
    result << values[i];
  }
  return result.str();
}

std::vector<std::string> string_split(const std::string& str, const std::string& delimiter) {
  std::vector<std::string> parts;
  size_t start = 0;
  size_t end = str.find(delimiter);
  while (end != std::string::npos) {
    parts.push_back(str.substr(start, end - start));
    start = end + delimiter.length();
    end = str.find(delimiter, start);
  }
  parts.push_back(str.substr(start));
  return parts;
}

std::string string_repeat(const std::string& str, size_t n) {
  if (n == 0) return "";
  std::string result;
  result.reserve(str.length() * n);
  for (size_t i = 0; i < n; ++i) result += str;
  return result;
}
