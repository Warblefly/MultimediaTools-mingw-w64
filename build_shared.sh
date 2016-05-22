#!/bin/bash

# This calls the script with the parameters I use daily.
# No other parameters have been tested.
# My aim is to make the cross compilation script default to these values
# so that this command line can be discarded.


# A default, switch to n for testing other parts of the build quickly.

build_ffmpeg=y
dump_archive=y
upload_archive=y

# This is the filename where the complete binary archive is stored
dump_file="mingw-multimedia-executables-shared.zip"

# This works out how many CPUs we have
gcc_cpu_count="$(grep -c processor /proc/cpuinfo)" 

# This is the location that scp copies your archive to
# You will UNDOUBTEDLY want to change this.
upload_location="john@johnwarburton.net:~/www/gallery/html/"

while getopts faup opt_check; do
  case $opt_check in
    f)
      echo "Not building FFmpeg"
      build_ffmpeg=n 
      ;;
    a)
      echo "Not creating archive"
      dump_archive=n
      ;;
    u)
      echo "Not uploading archive"
      upload_archive=n
      ;;
    *)
      echo "Invalid option"
      ;;
  esac
done

if [[ "${upload_archive}" = [Yy] ]]; then
  read -s -p "Password for scp when uploading: " upload_password
fi

echo "Going to cross compile."
echo "build_ffmpeg is ${build_ffmpeg}"
echo "dump_archive is ${dump_archive}"
echo "Archive will be dumped to ${dump_file}"
echo "Archive will be uploaded to ${upload_location}"


./cross_compile_ffmpeg_shared.sh --build-ffmpeg-shared=n --build-ffmpeg-static=$build_ffmpeg --disable-nonfree=n --sandbox-ok=y --build-libmxf=y --build-mp4box=y --build-choice=win64 --git-get-latest=y --prefer-stable=n --build-mplayer=n --gcc-cpu-count=$gcc_cpu_count || { echo "Build failure. Please see error messages above." ; exit 1; } 

# A few shared libraries necessary for runtime have been stored in ./lib.
# These must now be moved somewhere more useful.



# Make archive of executables
if  [[ "$dump_archive" = [Yy] ]]; then
  echo "Archive dump selected."
  # Put the unzip script where we can find it.
  cp -v install-zipfile.cmd sandbox/mingw-w64-x86_64/x86_64-w64-mingw32/bin/install-zipfile.cmd
  
  cd sandbox/mingw-w64-x86_64/x86_64-w64-mingw32
  # Symbolic links are de-referenced because Windows doesn't understand these.
  zip -r -9 -v -db -dc ${dump_file}  ./bin/*exe ./bin/*com ./bin/*dll ./bin/*py ./bin/*pl ./bin/*cmd ./bin/*config ./bin/platforms/*dll ./bin/lib/* ./bin/share/* ./lib/frei0r-1/* ./plugins/* ./share/OpenCV/* ./share/tessdata ./share/terminfo ./share/misc/magic.mgc ./bin/install-zipfile.ps1 || exit 1
  cd -
  mv -v  "sandbox/mingw-w64-x86_64/x86_64-w64-mingw32/${dump_file}" .
  echo "Archive made and stored in ${dump_file}"
fi

if [[ "${upload_archive}" = [Yy] ]]; then
  echo "Uploading archive to ${upload_location}..."
  sshpass -p "${upload_password}" scp -v "${dump_file}" "${upload_location}"
fi

echo "Build script finished."
