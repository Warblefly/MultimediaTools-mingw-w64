/**\file debug.c
 * \ingroup 1394cmdr
 * \brief Primarily, this encodes a string debug level for known trace levels in 1394cmdr.sys
 */

#include "pch.h"
/**\brief stringifier for 1394cmdr.sys trace levels
 * \param nLevel The trace level to convert
 * \return NULL-terminated static string for that level (guaranteed non-NULL, "UNKNOWN" if unknown)
 */

const char *strTraceLevel(int nLevel)
{
	switch(nLevel)
	{
	case TL_FATAL:  return " FATAL ";
	case TL_ALWAYS: return "ALWAYS ";
	case TL_ERROR:  return " ERROR ";
	case TL_WARNING:return "WARNING";
	case TL_CHECK:  return " CHECK ";
	case TL_ENTER:  return " ENTER ";
	case TL_EXIT:   return "  EXIT ";
	case TL_VERBOSE:return "VERBOSE";
	default:        return "UNKNOWN";
	}
}
