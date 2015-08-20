#!/bin/bash

# This calls the script with the parameters I use daily.
# No other parameters have been tested.
# My aim is to make the cross compilation script default to these values
# so that this command line can be discarded.


# A default, switch to n for testing other parts of the build quickly.

build_ffmpeg=y

# parse command line parameters, if any
while true; do
  case $1 in
    -h | --help ) echo "option is:
--ffmpeg=y/n  Build (y) or don't build (n) ffmpeg static binary
       "; exit 0 ;;
    --ffmpeg=* ) build_ffmpeg="${1#*=}"; shift ;;
    -- ) shift; break ;;
    -* ) echo "Error, unknown option: '$1'."; exit 1 ;;
    * ) break ;;
  esac
done




./cross_compile_ffmpeg_cygwin64.sh --build-ffmpeg-shared=n --build-ffmpeg-static=$build_ffmpeg --disable-nonfree=n --sandbox-ok=y --build-libmxf=y --build-mp4box=y --build-choice=win64 --git-get-latest=y --prefer-stable=n --build-mplayer=n

