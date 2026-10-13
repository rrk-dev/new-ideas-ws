/*
 * VaultVoice bridge error codes (vv-ffi-bridge). Every fallible vv_* function
 * returns int32_t: VV_OK or one of the negative codes below. Dart maps them to
 * Failure in one place. Never renumber; only append.
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
