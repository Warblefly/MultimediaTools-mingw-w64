# aclocal.m4 -*- Autoconf -*- vim: filetype=config
# ------------------------------------------------------------------
# This file is part of bzip2/libbzip2, a program and library for
# lossless, block-sorting data compression.
#
# bzip2/libbzip2 version 1.0.5 of 10 December 2007
# Copyright (C) 1996-2007 Julian Seward <jseward@bzip.org>
#
# File: aclocal.m4 for autoconf configuration
# Contributed by Keith Marshall <keithmarshall@users.sourceforge.net>
#
# Please read the WARNING, DISCLAIMER and PATENTS sections in the 
# README file.
#
# This program is released under the terms of the license contained
# in the file LICENSE.
# ------------------------------------------------------------------

# BZIP2_AC_WINDOWS_HOST
# ---------------------
# Check if the runtime platform is a native MS-Windows host.
# FIXME: is checking _WIN64 an appropriate choice, for 64-bit Windows?
# Because we only need to know whether the host is (native) win32
# or not, we can avoid the expensive AC_CANONICAL_HOST checks.
#
AC_DEFUN([BZIP2_AC_WINDOWS_HOST],
[AC_CACHE_CHECK([whether we are building for an MS-Windows host],
 [bzip2_cv_windows_host],
 AC_COMPILE_IFELSE([AC_LANG_SOURCE([[
@%:@if defined _WIN32 || defined _WIN64
 choke me
@%:@endif]])],
[bzip2_cv_windows_host=no], [bzip2_cv_windows_host=yes]))dnl
])# BZIP2_AC_WINDOWS_HOST

# BZIP2_AC_CYGWIN_HOST
# ---------------------
# Check if the runtime platform is a cygwin host.
# Because we only need to know whether the host is cygwin
# or not, we can avoid the expensive AC_CANONICAL_HOST checks.
#
AC_DEFUN([BZIP2_AC_CYGWIN_HOST],
[AC_CACHE_CHECK([whether we are building for a cygwin host],
 [bzip2_cv_cygwin_host],
 AC_COMPILE_IFELSE([AC_LANG_SOURCE([[
@%:@if defined __CYGWIN__
 choke me
@%:@endif]])],
[bzip2_cv_cygwin_host=no], [bzip2_cv_cygwin_host=yes]))dnl
])# BZIP2_AC_CYGWIN_HOST

# BZIP2_AC_ENABLE_SHARED
# ----------------------
# Check if the user is configuring with `--enable-shared';
# if yes, activate shared library build support as appropriate,
# for the host on which this build is to be deployed.
#
AC_DEFUN([BZIP2_AC_ENABLE_SHARED],
[AC_REQUIRE([BZIP2_AC_WINDOWS_HOST])dnl
 AC_REQUIRE([BZIP2_AC_CYGWIN_HOST])dnl
 AC_MSG_CHECKING([for make goal to build shared libraries])
 AC_ARG_ENABLE([shared],
 [AS_HELP_STRING([--enable-shared],
  [enable building as a shared library @<:@default=no@:>@])],
 [if test "x$enable_shared" = xyes
  then
    if test "x${bzip2_cv_windows_host}" = xyes ||
       test "x${bzip2_cv_cygwin_host}" = xyes
    then
      enable_shared="all-dll-shared"
    else
      enable_shared="all-bzip2-shared"
    fi
  else
    enable_shared="none"
  fi
 ], [enable_shared="none"])dnl
 AC_MSG_RESULT([${enable_shared}])
 [test "x$enable_shared" = xnone && enable_shared=""]
 AC_SUBST([enable_shared])dnl
])# BZIP2_AC_ENABLE_SHARED

# BZIP2_AC_SUBST_DLLVER
# ---------------------
# Establish the ABI version number for MS-Windows shared libraries;
# this is derived from the universal SO_VER and SO_AGE properties, as
# specified in `Makefile.in'; (nominally, it is SO_VER - SO_AGE, but
# see the note in `Makefile.in', explaining why, in this instance,
# we use one more than that nominal value for $host = mingw32)
#
AC_DEFUN([BZIP2_AC_SUBST_DLLVER],
[AC_REQUIRE([BZIP2_AC_WINDOWS_HOST])dnl
 AC_MSG_CHECKING([for API version of DLL shared libraries])
 [SO_VER=`FS=' 	';sed -n "/^[$FS]*SO_VER[$FS]*=[$FS]*/s///p" ${srcdir}/Makefile.in`]
 [SO_AGE=`FS=' 	';sed -n "/^[$FS]*SO_AGE[$FS]*=[$FS]*/s///p" ${srcdir}/Makefile.in`]
 [dllver=`expr ${SO_VER} - ${SO_AGE}`
  test "x$bzip2_cv_windows_host" = xyes && dllver=`expr 1 + ${SO_VER} - ${SO_AGE}`]
 AC_SUBST([DLLVER], [${dllver}])
 AC_MSG_RESULT([${dllver}])dnl
])# BZIP2_AC_SUBST_DLLVER

# BZIP2_AC_SUBST_DLLNAME
# ----------------------
# Establish the base name MS-Windows or cygwin shared libraries;
#
AC_DEFUN([BZIP2_AC_SUBST_DLLNAME],
[AC_REQUIRE([BZIP2_AC_WINDOWS_HOST])dnl
 AC_MSG_CHECKING([for base name of DLL shared libraries])
 [dllname=cygbz2
  test "x$bzip2_cv_windows_host" = xyes && dllname=libbz2]
 AC_SUBST([DLLNAME], [${dllname}])
 AC_MSG_RESULT([${dllname}])dnl
])# BZIP2_AC_SUBST_DLLNAME

# aclocal.m4: end of file
