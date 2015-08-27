#!/bin/bash

# This calls the script with the parameters I use daily.
# No other parameters have been tested.
# My aim is to make the cross compilation script default to these values
# so that this command line can be discarded.


# A default, switch to n for testing other parts of the build quickly.

build_ffmpeg=y
dump_archive=y
dump_file="/home/john/www/gallery/html/mingw-multimedia-executables-shared.tar.xz"

# parse command line parameters, if any
while true; do
  case $1 in
    -h | --help ) echo "option is:
--ffmpeg=y/n  Build (y) or don't build (n) ffmpeg static binary
--archive=y/n  Zip-up and dump archive (y) or not (n) in a directory of your choice
       "; exit 0 ;;
    --ffmpeg=* ) build_ffmpeg="${1#*=}"; shift ;;
    --archive=* ) dump_archive="${1#*=}"; shift ;;
    -- ) shift; break ;;
    -* ) echo "Error, unknown option: '$1'."; exit 1 ;;
    * ) break ;;
  esac
done

echo "Going to cross compile."
echo "build_ffmpeg is ${build_ffmpeg}"
echo "dump_archive is ${dump_archive}"
echo "Archive will be dumped to ${dump_file}"


./cross_compile_ffmpeg_shared.sh --build-ffmpeg-shared=n --build-ffmpeg-static=$build_ffmpeg --disable-nonfree=n --sandbox-ok=y --build-libmxf=y --build-mp4box=y --build-choice=win64 --git-get-latest=y --prefer-stable=n --build-mplayer=n || echo "Build failure. Please see error messages above." || exit 1

# Make archive of executables
if  [[ "$dump_archive" = [Yy] ]]; then
  echo "Archive dump selected."
  cd sandbox/mingw-w64-x86_64/x86_64-w64-mingw32
  # Symbolic links are de-referenced because Windows doesn't understand these.
  tar hacvvf ${dump_file} ./bin/*exe ./bin/*dll ./bin/*config ./lib/frei0r-1/* || exit 1
  echo "Archive made and stored in ${dump_file}"
fi

echo "Build script finished."
