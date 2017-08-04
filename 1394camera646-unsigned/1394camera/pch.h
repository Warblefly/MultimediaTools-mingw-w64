/**\file pch.h
 * \brief precompiled header thingy for building 1394camera .dll
 * \ingroup capi
 */

#include <windows.h>
#include <setupapi.h>
#include <shlwapi.h>
#include <strsafe.h>
#include "1394camapi.h"
#include "debug.h"

#ifdef __cplusplus
#include "1394Camera.h"
extern "C" {
#endif

// g_hInstDLL gets set to the DLL Instance on every DLL_PROCESS_ATTACH
// it must be used when referencing resources contained in the DLL
// the actual instance is defined in 1394main.c
extern HINSTANCE g_hInstDLL;

#ifndef ULONG_PTR
#define ULONG_PTR unsigned long *
#endif

#ifdef __cplusplus
}
#endif
