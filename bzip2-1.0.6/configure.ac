AC_INIT([bzip2],[1.0.8])
# ------------------------------------------------------------------
# This file is part of bzip2/libbzip2, a program and library for
# lossless, block-sorting data compression.
#
# bzip2/libbzip2 version 1.0.6 of 6 September 2010
# Copyright (C) 1996-2010 Julian Seward <jseward@bzip.org>
#
# File: configure.ac for autoconf configuration
# Contributed by Keith Marshall <keithmarshall@users.sourceforge.net>
#
# Please read the WARNING, DISCLAIMER and PATENTS sections in the 
# README file.
#
# This program is released under the terms of the license contained
# in the file LICENSE.
# ------------------------------------------------------------------
AC_PROG_CC
AC_PROG_LN_S

BZIP2_AC_ENABLE_SHARED
BZIP2_AC_SUBST_DLLVER
BZIP2_AC_SUBST_DLLNAME

AC_ARG_VAR([AR],[Archive librarian command])
AC_ARG_VAR([ARFLAGS],[Archive librarian control flags, e.g. cq])
AC_ARG_VAR([RANLIB],[Archive library indexing command])

AC_CHECK_TOOL([AR],[ar],[ar])
AC_CHECK_TOOL([RANLIB],[ranlib],[true])

AC_MSG_CHECKING([for flags to pass to ${AR}])
AC_SUBST([ARFLAGS],[${ARFLAGS-cq}])
AC_MSG_RESULT([${ARFLAGS}])

AC_CONFIG_FILES([Makefile])
AC_OUTPUT

# configure.ac: end of file
