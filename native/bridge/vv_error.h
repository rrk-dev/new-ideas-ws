/*
 * Error codes returned by every fallible vv_* function (vv-ffi-bridge).
 * 0 = success, negative = failure. Never renumber: Dart maps these to
 * Failure types in one place (packages/vv_native/lib/src/errors.dart).
 */
#ifndef VV_ERROR_H
#define VV_ERROR_H

#define VV_OK 0
#define VV_E_INVALID_ARG (-1)
#define VV_E_MODEL_LOAD (-2)
#define VV_E_OOM (-3)
#define VV_E_CANCELLED (-4)
#define VV_E_IO (-5)
#define VV_E_BACKEND (-6)
#define VV_E_BUSY (-7)
#define VV_E_INTERNAL (-8)

#endif /* VV_ERROR_H */
