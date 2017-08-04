/**\file debug.h
 * \brief Internal header for debug tracing functionality
 * \ingroup dialogs
 */

/*
 *	Version 6.4
 *
 *  Copyright 8/2006
 *
 *  Christopher Baker
 *  Robotics Institute
 *  Carnegie Mellon University
 *  Pittsburgh, PA
 *
 *	Copyright 5/2000
 * 
 *	Iwan Ulrich
 *	Robotics Institute
 *	Carnegie Mellon University
 *	Pittsburgh, PA
 *
 *  This file is part of the CMU 1394 Digital Camera Driver
 *
 *  The CMU 1394 Digital Camera Driver is free software; you can redistribute 
 *  it and/or modify it under the terms of the GNU Lesser General Public License 
 *  as published by the Free Software Foundation; either version 2.1 of the License,
 *  or (at your option) any later version.
 *
 *  The CMU 1394 Digital Camera Driver is distributed in the hope that it will 
 *  be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with the CMU 1394 Digital Camera Driver; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifdef __cplusplus
extern "C" {
#endif

/**\brief Use sparingly for things that should always be printed out 
 * \ingroup debug
 */
#define DLL_TRACE_ALWAYS  -2

/**\brief Placeholder to turn all tracing off (except the ALWAYS ones) 
 * \ingroup debug
 */
#define DLL_TRACE_NONE    -1

/**\brief PlaceHolder to turn everything on
 * \ingroup debug
 */
#define DLL_TRACE_ALL    100

/**\brief Critical Errors and otherwise very bad things
 * \ingroup debug
 */
#define DLL_TRACE_ERROR    0

/**\brief Non-critical Errors and marginally bad things
 * \ingroup debug
 */
#define DLL_TRACE_WARNING  1

/**\brief Infrequent but important checkpoints
 * \ingroup debug
 */
#define DLL_TRACE_CHECK    2

/**\brief Function entry
 * \ingroup debug
 */
#define DLL_TRACE_ENTER    5

/**\brief Function Exit
 * \ingroup debug
 */
#define DLL_TRACE_EXIT     6

/**\brief Frequent (inner-loop) checkpoints and otherwise huge printouts
 * \ingroup debug
 */
#define DLL_TRACE_VERBOSE 10

#if _MSC_VER >= 1300
// VS7+ supports variadic macros that we can use to cleanly inject file/line numbers
#define DllTrace(LEVEL,FMT,...) _DllTraceEx((__FILE__),(__LINE__),(LEVEL), FMT, __VA_ARGS__)
#else
// VS6- doesn't support variadic macros, so we don't get file/line numbers in the output
#define DllTrace _DllTrace
#endif

void _DllTrace(int nlevel,const char *format, ...);
void _DllTraceEx(const char *file, int line, int nlevel, const char *format, ...);

const char *WinStrError(DWORD dwError);
const char *StrLastError();
const char *StrDllTraceLevel(int nLevel);

#ifdef __cplusplus
}
#endif
