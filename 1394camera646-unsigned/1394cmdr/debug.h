/*++

Copyright (c) 1998 Microsoft Corporation

Module Name:

    debug.h

Abstract:

Author:

    Peter Binder (pbinder) 3/16/98

Revision History:
Date     Who       What
-------- --------- ------------------------------------------------------------
3/16/98  pbinder   starting...
4/13/98  pbinder   taken from another project...
--*/

extern LONG t1394CmdrDebugLevel;

const char *strTraceLevel(int nLevel);

#ifdef DBG_1394CMDR

#define _DRIVERNAME_    "1394CMDR"

#define TL_ALWAYS  -2 // this one is used sparingly for critical debug information
#define TL_FATAL   -3
#define TL_NONE    -1
#define TL_ALL     10
#define TL_ERROR    0
#define TL_WARNING  1
#define TL_CHECK    2
#define TL_ENTER    5
#define TL_EXIT     6
#define TL_VERBOSE 10
#define TL_TRACE   10

// Add a file and line preamble to a trace format string
// note: +24 trims off D:\WINDDK\3700\1394cmdr\ //
#define _TP(FMT) "1394cmdr.sys : %15s:%d : " FMT , __FILE__ + 24, __LINE__

#define TRACE( l, x ) if( (l) <= t1394CmdrDebugLevel ) { DbgPrint  x ; }

#define ENTER(n) TRACE(TL_ENTER, (_TP("ENTER %s\n"), n))
#define EXIT(n,x) TRACE(TL_EXIT, (_TP("EXIT %s(%08x)\n"), n, x))

#else  // DBG_1394CMDR

#define TRACE( l, x )

#define ENTER(n)
#define EXIT(n,x)

#endif // DBG_1394CMDR


