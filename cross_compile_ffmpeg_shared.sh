#!/usr/bin/env bash



# set -x
# ffmpeg windows cross compile helper/download script
# Copyright (C) 2014 Roger Pack, the script is under the GPLv3, but output FFmpeg's aren't necessarily
# with modifications by John Warburton john@johnwarburton.com

#Gnulib
# 1. Check it out separately
# 2. 

#Gnu Coreutils
# 1. Remove configure test for mounted file system list
# 2. Set -Werror inactive



yes_no_sel () {
  unset user_input
  local question="$1"
  shift
  local default_answer="$1"
  while [[ "$user_input" != [YyNn] ]]; do
    echo -n "$question"
    read user_input
    if [[ -z "$user_input" ]]; then
      echo "using default $default_answer"
      user_input=$default_answer
    fi
    if [[ "$user_input" != [YyNn] ]]; then
      clear; echo 'Your selection was not vaild, please try again.'; echo
    fi
  done
  # downcase it
  user_input=$(echo $user_input | tr '[A-Z]' '[a-z]')
}

check_missing_packages () {
  local check_packages=('curl' 'pkg-config' 'make' 'git' 'svn' 'cmake' 'gcc' 'autoconf' 'libtool' 'automake' 'yasm' 'cvs' 'flex' 'bison' 'makeinfo' 'g++' 'ed' 'hg' 'patch' 'pax' 'bzr' 'gperf' 'ruby' 'doxygen' 'xsltproc' 'autogen' 'rake')
  for package in "${check_packages[@]}"; do
    type -P "$package" >/dev/null || missing_packages=("$package" "${missing_packages[@]}")
  done

  if [[ -n "${missing_packages[@]}" ]]; then
    clear
    echo "Could not find the following execs (svn is actually package subversion, makeinfo is actually package texinfo if you're missing them): ${missing_packages[@]}"
    echo 'Install the missing packages before running this script.'
    echo "for ubuntu: $ sudo apt-get install subversion curl texinfo g++ bison flex cvs yasm automake libtool autoconf gcc cmake git make pkg-config zlib1g-dev mercurial" 
    echo "for gentoo (a non ubuntu distro): same as above, but no g++, no gcc, git is dev-vcs/git, zlib1g-dev is zlib, pkg-config is dev-util/pkgconfig, add ed..."
    exit 1
  fi

  local out=`cmake --version` # like cmake version 2.8.7
  local version_have=`echo "$out" | cut -d " " -f 3`

  function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

  if [[ $(version $version_have)  < $(version '2.8.10') ]]; then
    echo "your cmake version is too old $version_have wanted 2.8.10"
    exit 1
  fi

  if [[ ! -f /usr/include/zlib.h ]]; then
    echo "warning: you may need to install zlib development headers first if you want to build mp4box [on ubuntu: $ apt-get install zlib1g-dev]" # XXX do like configure does and attempt to compile and include zlib.h instead?
    sleep 1
  fi

  out=`yasm --version`
  yasm_version=`echo "$out" | cut -d " " -f 2` # like 1.1.0.112
  if [[ $(version $yasm_version)  < $(version '1.2.0') ]]; then
    echo "your yasm version is too old $yasm_version wanted 1.2.0"
    exit 1
  fi

}


intro() {
  cat <<EOL
     ##################### Welcome ######################
  Welcome to the ffmpeg cross-compile builder-helper script.
  Downloads and builds will be installed to directories within $cur_dir
  If this is not ok, then exit now, and cd to the directory where you'd
  like them installed, then run this script again from there.  
  NB that once you build your compilers, you can no longer rename/move
  the sandbox directory, since it will have some hard coded paths in there.
  You can, of course, rebuild ffmpeg from within it, etc.
EOL
  if [[ $sandbox_ok != 'y' && ! -d sandbox ]]; then
    yes_no_sel "Is ./sandbox ok (requires ~ 5GB space) [Y/n]?" "y"
    if [[ "$user_input" = "n" ]]; then
      exit 1
    fi
  fi
  mkdir -p "$cur_dir"
  cd "$cur_dir"
  if [[ $disable_nonfree = "y" ]]; then
    non_free="n"
  else
    if  [[ $disable_nonfree = "n" ]]; then
      non_free="y" 
    else
      yes_no_sel "Would you like to include non-free (non GPL compatible) libraries, like many high quality aac encoders [libfdk_aac]
The resultant binary may not be distributable, but can be useful for in-house use. Include these non-free-license libraries [y/N]?" "n"
      non_free="$user_input" # save it away
    fi
  fi
}

pick_compiler_flavors() {

  while [[ "$build_choice" != [1-4] ]]; do
    if [[ -n "${unknown_opts[@]}" ]]; then
      echo -n 'Unknown option(s)'
      for unknown_opt in "${unknown_opts[@]}"; do
        echo -n " '$unknown_opt'"
      done
      echo ', ignored.'; echo
    fi
    cat <<'EOF'
What version of MinGW-w64 would you like to build or update?
  1. Both Win32 and Win64
  2. Win32 (32-bit only)
  3. Win64 (64-bit only)
  4. Exit
EOF
    echo -n 'Input your choice [1-5]: '
    read build_choice
  done
  case "$build_choice" in
  1 ) build_choice=multi ;;
  2 ) build_choice=win32 ;;
  3 ) build_choice=win64 ;;
  4 ) echo "exiting"; exit 0 ;;
  * ) clear;  echo 'Your choice was not valid, please try again.'; echo ;;
  esac
}

install_cross_compiler() {
  if [[ -f "mingw-w64-i686/compiler.done" || -f "mingw-w64-x86_64/compiler.done" ]]; then
   echo "MinGW-w64 compiler of some type or other already installed, not re-installing..."
   if [[ $rebuild_compilers != "y" ]]; then
     return # early exit, they already have some type of cross compiler built.
   fi
  fi

  if [[ -z $build_choice ]]; then
    pick_compiler_flavors
  fi
  if [[ -f mingw-w64-build-3.6.6 ]]; then
    rm mingw-w64-build-3.6.6 || exit 1
  fi 
  curl http://zeranoe.com/scripts/mingw_w64_build/mingw-w64-build-3.6.6 -O || exit 1
  chmod u+x mingw-w64-build-3.6.6
  unset CFLAGS # don't want these for the compiler itself since it creates executables to run on the local box
  # pthreads version to avoid having to use cvs for it
  echo "building cross compile gcc [requires internet access]"
# Quick patch to update mingw to 4.0.4
  sed -i.bak "s/mingw_w64_release_ver='3.3.0'/mingw_w64_release_ver='4.0.4'/" mingw-w64-build-3.6.6
  sed -i.bak "s/gcc_release_ver='4.9.2'/gcc_release_ver='5.2.0'/" mingw-w64-build-3.6.6
  sed -i.bak "s/mpfr_release_ver='3.1.2'/mpfr_release_ver='3.1.3'/" mingw-w64-build-3.6.6
  sed -i.bak "s/binutils_release_ver='2.25'/binutils_release_ver='2.25.1'/" mingw-w64-build-3.6.6
  sed -i.bak "s/isl_release_ver='0.12.2'/isl_release_ver='0.14'/" mingw-w64-build-3.6.6
# Gendef compilation throws a char-as-array-index error when invoked with "--target=" : "--host" avoids this.
#  sed -i.bak 's#gendef/configure" --build="$system_type" --prefix="$mingw_w64_prefix" --target#gendef/configure" --build="$system_type" --prefix="$mingw_w64_prefix" --host#' mingw-w64-build-3.6.6
  nice ./mingw-w64-build-3.6.6 --clean-build --disable-shared --default-configure --mingw-w64-ver=4.0.4 --gcc-ver=5.2.0 --pthreads-w32-ver=cvs --cpu-count=$gcc_cpu_count --build-type=$build_choice --enable-gendef --enable-widl --binutils-ver=2.25.1 --verbose || exit 1 # --disable-shared allows c++ to be distributed at all...which seemed necessary for some random dependency...
  export CFLAGS=$original_cflags # reset it
  if [ -d mingw-w64-x86_64 ]; then
    touch mingw-w64-x86_64/compiler.done
  fi
  if [ -d mingw-w64-i686 ]; then
    touch mingw-w64-i686/compiler.done
  fi
  # clear
  echo "Ok, done building MinGW-w64 cross-compiler..."
}

# helper methods for downloading and building projects that can take generic input

do_svn_checkout() {
  repo_url="$1"
  to_dir="$2"
  desired_revision="$3"
  if [ ! -d $to_dir ]; then
    echo "svn checking out to $to_dir"
    if [[ -z "$desired_revision" ]]; then
      svn checkout $repo_url $to_dir.tmp || exit 1
    else
      svn checkout -r $desired_revision $repo_url $to_dir.tmp || exit 1
    fi
    mv $to_dir.tmp $to_dir
  else
    cd $to_dir
    echo "not svn Updating $to_dir since usually svn repo's aren't updated frequently enough..."
    # XXX accomodate for desired revision here if I ever uncomment the next line...
    # svn up
    cd ..
  fi
}

update_to_desired_git_branch_or_revision() {
  local to_dir="$1"
  local desired_branch="$2" # or tag or whatever...
  if [ -n "$desired_branch" ]; then
   pushd $to_dir
   cd $to_dir
      echo "git checkout $desired_branch"
      git checkout "$desired_branch" || exit 1 # if this fails, nuke the directory first...
      git merge "$desired_branch" || exit 1 # this would be if they want to checkout a revision number, not a branch...
   popd # in case it's a cd to ., don't want to cd to .. here...since sometimes we call it with a '.'
  fi
}

do_git_checkout() {
  local repo_url="$1"
  local to_dir="$2"
  if [[ -z $to_dir ]]; then
    echo "got empty to dir for git checkout?"
    exit 1
  fi
  local desired_branch="$3"
  if [ ! -d $to_dir ]; then
    echo "Downloading (via git clone) $to_dir"
    rm -rf $to_dir.tmp # just in case it was interrupted previously...
    # prevent partial checkouts by renaming it only after success
    git clone $repo_url $to_dir.tmp || exit 1
    mv $to_dir.tmp $to_dir
    echo "done downloading $to_dir"
    update_to_desired_git_branch_or_revision $to_dir $desired_branch
  else
    cd $to_dir
    old_git_version=`git rev-parse HEAD`

    if [[ -z $desired_branch ]]; then
      if [[ $git_get_latest = "y" ]]; then
        echo "Updating to latest $to_dir version... $desired_branch"
        git pull
      else
        echo "not doing git get latest pull for latest code $to_dir"
      fi
    else
      if [[ $git_get_latest = "y" ]]; then
        echo "Doing git fetch $to_dir in case it affects the desired branch [$desired_branch]"
        git fetch
      else
        echo "not doing git fetch $to_dir to see if it affected desired branch [$desired_branch]"
      fi
    fi
    update_to_desired_git_branch_or_revision "." $desired_branch
    new_git_version=`git rev-parse HEAD`
    if [[ "$old_git_version" != "$new_git_version" ]]; then
     echo "got upstream changes, forcing re-configure."
     rm already*
    else
     echo "this pull got no new upstream changes, not forcing re-configure..."
    fi 
    cd ..
  fi
}

download_config_files() {
   curl -o config.guess "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
   curl -o config.sub "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
   chmod +x config.guess config.sub
}

get_small_touchfile_name() { # have to call with assignment like a=$(get_small...)
  local beginning="$1"
  local extra_stuff="$2"
  local touch_name="${beginning}_$(echo -- $extra_stuff $CFLAGS | /usr/bin/env md5sum | head --bytes 10)" # make it smaller
  touch_name=$(echo $touch_name | sed "s/ //g") # md5sum introduces spaces, remove them
  echo $touch_name # bash cruddy return system LOL
} 

do_configure() {
  local configure_options="$1"
  local configure_name="$2"
  if [[ "$configure_name" = "" ]]; then
    configure_name="./configure"
  fi
  local cur_dir2=$(pwd)
  local english_name=$(basename $cur_dir2)
  local touch_name=$(get_small_touchfile_name already_configured "$configure_options $configure_name $LDFLAGS $CFLAGS")
  if [ ! -f "$touch_name" ]; then
    make clean # just in case
    #make uninstall # does weird things when run under ffmpeg src
    if [ ! -f ${configure_name} ]; then
      if [ -f bootstrap.sh ]; then
        ./bootstrap.sh
      fi
      if [ -f bootstrap ]; then
        ./bootstrap
      fi
      if [ -f autogen.sh ]; then
        ./autogen.sh
      fi
      if [ -f autogen ]; then
        ./autogen
      fi
    fi
    rm -f already_* # reset
    echo "configuring $english_name ($PWD) as $ PATH=$PATH $configure_name $configure_options"
    nice "$configure_name" $configure_options || exit 1
    touch -- "$touch_name"
    make clean # just in case
  else
    echo "already configured $(basename $cur_dir2)" 
  fi
}

do_make() {
  local extra_make_options="$1 -j $cpu_count"
  local cur_dir2=$(pwd)
  local touch_name=$(get_small_touchfile_name already_ran_make "$extra_make_options")

  if [ ! -f $touch_name ]; then
    echo
    echo "making $cur_dir2 as $ PATH=$PATH make $extra_make_options"
    echo
    nice make $extra_make_options || exit 1
    touch $touch_name || exit 1 # only touch if the build was OK
  else
    echo "already did make $(basename "$cur_dir2")"
  fi
}

do_rake() {
  local extra_make_options="$1 -j $cpu_count"
  local cur_dir2=$(pwd)
  local touch_name=$(get_small_touchfile_name already_ran_rake "$extra_make_options")

  if [ ! -f $touch_name ]; then
    echo
    echo "raking $cur_dir2 as $ PATH=$PATH rake $extra_make_options"
    echo
    nice rake $extra_make_options || exit 1
    touch $touch_name || exit 1 # only touch if the build was OK
  else
    echo "already did make $(basename "$cur_dir2")"
  fi
}

do_smake() {
  local extra_make_options="$1"
  local cur_dir2=$(pwd)
  local touch_name=$(get_small_touchfile_name already_ran_make "$extra_make_options")

  if [ ! -f $touch_name ]; then
    echo
    echo "smaking $cur_dir2 as $ PATH=$PATH smake $extra_make_options"
    echo
    nice ${mingw_w64_x86_64_prefix}/../bin/smake.exe $extra_make_options || exit 1
    touch $touch_name || exit 1 # only touch if the build was OK
  else
    echo "already did smake $(basename "$cur_dir2")"
  fi
}


do_make_install() {
  local extra_make_options="$1"
  do_make "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "make installing $cur_dir2 as $ PATH=$PATH make install $extra_make_options"
    nice make install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}

do_smake_install() {
  local extra_make_options="$1"
  do_smake "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "smake installing $cur_dir2 as $ PATH=$PATH smake install $extra_make_options"
    nice ${mingw_w64_x86_64_prefix}/../bin/smake.exe install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}


do_cmake() {
  extra_args="$1" 
  local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")

  if [ ! -f $touch_name ]; then
    local cur_dir2=$(pwd)
    echo doing cmake in $cur_dir2 with PATH=$PATH  with extra_args=$extra_args like this:
    echo cmake . -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
    cmake . -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
    touch $touch_name || exit 1
  fi
}

apply_patch() {
 local url=$1
 local patch_name=$(basename $url)
 local patch_done_name="$patch_name.done"
 if [[ ! -e $patch_done_name ]]; then
   if [[ -f $patch_name ]]; then
    rm $patch_name || exit 1
   fi
   curl $url -O || exit 1
   echo "applying patch $patch_name"
   cat $patch_name
   patch -p0 < "$patch_name" || exit 1
   touch $patch_done_name || exit 1
   rm already_ran* # if it's a new patch, reset everything too, in case it's really really really new
 else
   echo "patch $patch_name already applied"
 fi
}

apply_patch_p1() {
 local url=$1
 local patch_name=$(basename $url)
 local patch_done_name="$patch_name.done"
 if [[ ! -e $patch_done_name ]]; then
   if [[ -f $patch_name ]]; then
    rm $patch_name || exit 1
   fi
   curl $url -O || exit 1
   echo "applying patch $patch_name"
   patch -p1 < "$patch_name" || exit 1
   touch $patch_done_name || exit 1
   rm already_ran* # if it's a new patch, reset everything too, in case it's really really really new
 else
   echo "patch $patch_name already applied"
 fi
}



download_and_unpack_file() {
  url="$1"
  output_name=$(basename $url)
  output_dir="$2"
  if [ ! -f "$output_dir/unpacked.successfully" ]; then
    echo "downloading $url"
    if [[ -f $output_name ]]; then
      rm "$output_name" || exit 1
    fi
#    echo "About to call curl ${url} and output_name is ${output_name} and output_dir is ${output_dir}"
    curl -k -O -L "${url}" || exit 1
    tar -xvf "$output_name" || unzip "$output_name" || exit 1
    touch "$output_dir/unpacked.successfully" || exit 1
    rm "$output_name" || exit 1
  fi
}

download_and_unpack_bz2file() {
  url="$1"
  output_name=$(basename $url)
  output_dir="$2"
  if [ ! -f "$output_dir/unpacked.successfully" ]; then
    echo "downloading $url"
    if [[ -f $output_name ]]; then
      rm "$output_name" || exit 1
    fi
    curl "$url" -O -L || exit 1
    mkdir $output_dir
    tar ixvf "$output_name" -C $output_dir --strip-components=1 || exit 1
    touch "$output_dir/unpacked.successfully" || exit 1
    rm "$output_name" || exit 1
  fi
}



generic_configure() {
  local extra_configure_options="$1"
  do_configure "--host=$host_target --prefix=$mingw_w64_x86_64_prefix --disable-shared --enable-static $extra_configure_options"
}

# needs 2 parameters currently [url, name it will be unpacked to]
generic_download_and_install() {
  local url="$1"
  local english_name="$2" 
  local extra_configure_options="$3"
  download_and_unpack_file $url $english_name
  cd $english_name || exit "needs 2 parameters"
  generic_configure_make_install "$extra_configure_options"
  cd ..
}

generic_configure_make_install() {
  generic_configure "$1"
  do_make_and_make_install
}

generic_configure_rake_install() {
  generic_configure "$1"
  do_rake_and_rake_install
}


do_make_and_make_install() {
  local extra_make_options="$1"
  do_make "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "make installing $(pwd) as $ PATH=$PATH make install $extra_make_options"
    nice make install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}

do_rake_and_rake_install() {
  local extra_make_options="$1"
  do_rake "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "rake installing $(pwd) as $ PATH=$PATH rake install $extra_make_options"
    nice rake install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}


do_cmake_and_install() {
  extra_args="$1" 
  local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")

  if [ ! -f $touch_name ]; then
    rm -f already_* # reset so that make will run again if option just changed
    local cur_dir2=$(pwd)
    echo doing cmake in $cur_dir2 with PATH=$PATH  with extra_args=$extra_args like this:
    echo cmake –G”Unix Makefiles” . -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args
    cmake –G”Unix Makefiles” . -DENABLE_STATIC_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
    touch $touch_name || exit 1
  fi
  do_make_and_make_install
}

build_libx265() {
  if [[ $prefer_stable = "n" ]]; then
    local old_hg_version
    if [[ -d x265 ]]; then
      cd x265
      if [[ $git_get_latest = "y" ]]; then
        echo "doing hg pull -u x265"
        old_hg_version=`hg --debug id -i`
        hg pull -u || exit 1
        hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
      else
        echo "not doing hg pull x265"
        old_hg_version=`hg --debug id -i`
      fi
    else
      hg clone https://bitbucket.org/multicoreware/x265 || exit 1
      cd x265
      old_hg_version=none-yet
    fi
    cd source

    # hg checkout 9b0c9b # no longer needed, but once was...

    local new_hg_version=`hg --debug id -i`  
    if [[ "$old_hg_version" != "$new_hg_version" ]]; then
      echo "got upstream hg changes, forcing rebuild...x265"
      rm already*
    else
      echo "still at hg $new_hg_version x265"
    fi
  else
    local old_hg_version
    if [[ -d x265 ]]; then
      cd x265
      if [[ $git_get_latest = "y" ]]; then
        echo "doing hg pull -u x265"
        old_hg_version=`hg --debug id -i`
        hg pull -u || exit 1
        hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
      else
        echo "not doing hg pull x265"
        old_hg_version=`hg --debug id -i`
      fi
    else
      hg clone https://bitbucket.org/multicoreware/x265 -r stable || exit 1
      cd x265
      old_hg_version=none-yet
    fi
    cd source

    # hg checkout 9b0c9b # no longer needed, but once was...

    local new_hg_version=`hg --debug id -i`  
    if [[ "$old_hg_version" != "$new_hg_version" ]]; then
      echo "got upstream hg changes, forcing rebuild...x265"
      rm already*
    else
      echo "still at hg $new_hg_version x265"
    fi
  fi
  
  local cmake_params="-DENABLE_SHARED=OFF"
  if [[ $high_bitdepth == "y" ]]; then
    cmake_params="$cmake_params -DHIGH_BIT_DEPTH=ON" # Enable 10 bits (main10) and 12 bits (???) per pixels profiles.
    if grep "DHIGH_BIT_DEPTH=0" CMakeFiles/cli.dir/flags.make; then
      rm already_ran_cmake_* #Last build was not high bitdepth. Forcing rebuild.
    fi
  else
    if grep "DHIGH_BIT_DEPTH=1" CMakeFiles/cli.dir/flags.make; then
      rm already_ran_cmake_* #Last build was high bitdepth. Forcing rebuild.
    fi
  fi
  # apply_patch_p1 file://${top_dir}/x265-missing-bool.patch  
  # Fixed by x265 developers now
  do_cmake "$cmake_params" 
  do_make_install
  cd ../..
}

#x264_profile_guided=y

build_libx264() {
  do_git_checkout git://git.videolan.org/x264.git x264
  cd x264
  local configure_flags="--host=$host_target --enable-static --cross-prefix=$cross_prefix --prefix=$mingw_w64_x86_64_prefix --extra-cflags=-DPTW32_STATIC_LIB --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac" # --enable-win32thread --enable-debug shouldn't hurt us since ffmpeg strips it anyway I think
  
  if [[ $high_bitdepth == "y" ]]; then
    configure_flags="$configure_flags --bit-depth=10" # Enable 10 bits (main10) per pixels profile.
    if grep -q "HIGH_BIT_DEPTH 0" config.h; then
      rm already_configured_* #Last build was not high bitdepth. Forcing reconfigure.
    fi
  else
    if grep -q "HIGH_BIT_DEPTH 1" config.h; then
      rm already_configured_* #Last build was high bitdepth. Forcing reconfigure.
    fi
  fi
  
  if [[ $x264_profile_guided = y ]]; then
    # TODO more march=native here?
    # TODO profile guided here option, with wine?
    do_configure "$configure_flags"
    curl http://samples.mplayerhq.hu/yuv4mpeg2/example.y4m.bz2 -O || exit 1
    rm example.y4m # in case it exists already...
    bunzip2 example.y4m.bz2 || exit 1
    # XXX does this kill git updates? maybe a more general fix, since vid.stab does also?
    sed -i.bak "s_\\, ./x264_, wine ./x264_" Makefile # in case they have wine auto-run disabled http://askubuntu.com/questions/344088/how-to-ensure-wine-does-not-auto-run-exe-files
    do_make_install "fprofiled VIDS=example.y4m" # guess it has its own make fprofiled, so we don't need to manually add -fprofile-generate here...
  else 
    do_configure "$configure_flags"
    do_make_install
  fi
  cd ..
}

build_librtmp() {
  #  download_and_unpack_file http://rtmpdump.mplayerhq.hu/download/rtmpdump-2.3.tgz rtmpdump-2.3 # has some odd configure failure
  #  cd rtmpdump-2.3/librtmp

  do_git_checkout "http://repo.or.cz/r/rtmpdump.git" rtmpdump_git # 883c33489403ed360a01d1a47ec76d476525b49e # trunk didn't build once...this one i sstable
  cd rtmpdump_git/librtmp
  do_make_install "CRYPTO=GNUTLS OPT=-O2 CROSS_COMPILE=$cross_prefix SHARED=no prefix=$mingw_w64_x86_64_prefix"
  #make install CRYPTO=GNUTLS OPT='-O2 -g' "CROSS_COMPILE=$cross_prefix" SHARED=no "prefix=$mingw_w64_x86_64_prefix" || exit 1
  sed -i.bak 's/-lrtmp -lz/-lrtmp -lwinmm -lz/' "$PKG_CONFIG_PATH/librtmp.pc"
  cd ..
   # TODO do_make here instead...
   make SYS=mingw CRYPTO=GNUTLS OPT=-O2 CROSS_COMPILE=$cross_prefix SHARED=no LIB_GNUTLS="`pkg-config --libs gnutls` -lz" || exit 1
   # The makefile doesn't install
   cp -fv rtmpdump.exe rtmpgw.exe rtmpsrv.exe rtmpsuck.exe "${mingw_w64_x86_64_prefix}/bin"
  cd ..

}

#build_qt5() {
#  generic_download_and_install http://download.qt.io/official_releases/qt/5.4/5.4.1/submodules/qtbase-opensource-src-5.4.1.tar.xz qtbase-opensource-src-5.4.1
#}


build_qt() {
# This is quite a minimal installation to try to shorten a VERY long compile.
# It's needed for OpenDCP and may well be extended to other programs later.
  unset CFLAGS
  download_and_unpack_file http://download.qt.io/archive/qt/4.8/4.8.6/qt-everywhere-opensource-src-4.8.6.tar.gz qt-everywhere-opensource-src-4.8.6
  cd qt-everywhere-opensource-src-4.8.6
    apply_patch_p1 file://${top_dir}/qplatformdefs.h.patch
    apply_patch_p1 file://${top_dir}/qfiledialog.cpp.patch
    # vlc's configure options...mostly
#    do_configure "-static -release -fast -no-exceptions -no-stl -no-sql-sqlite -no-qt3support -no-gif -no-libmng -qt-libjpeg -no-libtiff -no-qdbus -no-openssl -no-webkit -sse -no-script -no-multimedia -no-phonon -opensource -no-scripttools -no-opengl -no-script -no-scripttools -no-declarative -no-declarative-debug -opensource -no-s60 -host-little-endian -confirm-license -xplatform win32-g++ -device-option CROSS_COMPILE=$cross_prefix -prefix $mingw_w64_x86_64_prefix -prefix-install -nomake examples"
    do_configure "-release -static -no-exceptions -no-sql-sqlite -no-scripttools -no-script -no-accessibility -no-qt3support -no-multimedia -no-audio-backend -no-phonon -no-phonon-backend -no-declarative -no-declarative-debug -no-s60 -host-little-endian -no-webkit -xplatform win32-g++ -no-cups -no-dbus -nomake tests -nomake docs -nomake tools -opensource -confirm-license -nomake demos -nomake examples -no-libmng -device-option CROSS_COMPILE=$cross_prefix -prefix $mingw_w64_x86_64_prefix -prefix-install"
    if [ ! -f 'already_qt_maked_k' ]; then
      do_make # sub-src might make the build faster? # complains on mng? huh?
      do_make_install
      touch 'already_qt_maked_k'
    fi
    # vlc needs an adjust .pc file? huh wuh?
#    sed -i.bak 's/Libs: -L${libdir} -lQtGui/Libs: -L${libdir} -lcomctl32 -lqjpeg -lqtaccessiblewidgets -lQtGui/' "$PKG_CONFIG_PATH/QtGui.pc" # sniff
  cd ..
  export CFLAGS=$original_cflags
}

build_libsoxr() {
  #download_and_unpack_file http://sourceforge.net/projects/soxr/files/soxr-0.1.1-Source.tar.xz soxr-0.1.1-Source # not /download since apparently some tar's can't untar it without an extension?
  do_git_checkout git://git.code.sf.net/p/soxr/code "soxr-code"
  cd soxr-code
    do_cmake "-DHAVE_WORDS_BIGENDIAN_EXITCODE=0  -DBUILD_SHARED_LIBS:bool=off -DBUILD_TESTS:BOOL=OFF"
    do_make_install
  cd ..
}

build_opencv() {
  do_git_checkout https://github.com/Itseez/opencv.git "opencv"
  cd opencv
  # This is only used for a couple of frei0r filters. Surely we can switch off more options than this?
  # WEBP is switched off because it triggers a Cmake bug that removes #define-s of EPSILON and variants
  # This needs more work
    do_cmake "-DWITH_IPP=OFF -DWITH_DSHOW=OFF -DBUILD_SHARED_LIBS=OFF -DBUILD_opencv_apps=ON -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DBUILD_WITH_DEBUG_INFO=OFF -DWITH_WEBP=OFF"
  sed -i.bak "s|DBL_EPSILON|2.2204460492503131E-16|g" modules/imgproc/include/opencv2/imgproc/types_c.h
    do_make_install
  export OpenCV_DIR=`pwd`
  export OpenCV_INCLUDE_DIR="${OpenCV_DIR}/include"
  cd ..
  # This helps frei0r find opencv
}

build_opendcp() {
# There are quite a few patches because I prefer to build this as a static program,
# whereas the author, understandably, created it as a dynamically-linked program.
  do_git_checkout https://code.google.com/p/opendcp/ opendcp
  cd opendcp
    export CMAKE_LIBRARY_PATH="${mingw_w64_x86_64_prefix}/lib"
    export CMAKE_INCLUDE_PATH="${mingw_w64_x86_64_prefix}/include:${mingw_w64_x86_64_prefix}/include/openjpeg-2.1"
    export CMAKE_CXX_FLAGS="-fopenmp"
    export CMAKE_C_FLAGS="-fopenmp"
    apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.patch
    apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.openjpeg-2.1.patch
    apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.libs.patch
    apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.windres.patch
    apply_patch file://${top_dir}/opendcp-packages-CMakeLists.txt-static.patch
    do_cmake "-DENABLE_XMLSEC=ON -DENABLE_GUI=ON -DBUILD_STATIC=ON -DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_OPENMP=OFF"
    do_make_install
    unset CMAKE_C_FLAGS
    unset CMAKE_CXX_FLAGS
    unset CMAKE_LIBRARY_PATH
    unset CMAKE_INCLUDE_PATH
  cd ..
}

build_libxavs() {
  do_svn_checkout https://svn.code.sf.net/p/xavs/code/trunk xavs
  cd xavs
    export LDFLAGS='-lm'
    generic_configure "--cross-prefix=$cross_prefix" # see https://github.com/rdp/ffmpeg-windows-build-helpers/issues/3
    unset LDFLAGS
    do_make_install "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar PREFIX=$mingw_w64_x86_64_prefix RANLIB=$(echo $cross_prefix)ranlib STRIP=$(echo $cross_prefix)strip"
  cd ..
}

build_libpng() {
  download_and_unpack_file http://download.sourceforge.net/libpng/libpng-1.6.16.tar.xz libpng-1.6.16
  cd libpng-1.6.16
    # DBL_EPSILON 21 Feb 2015 starts to come back "undefined". I have NO IDEA why.
    grep -lr DBL_EPSILON contrib | xargs sed -i "s| DBL_EPSILON| 2.2204460492503131E-16|g"
    generic_configure_make_install
    sed -i.bak 's/-lpng16.*$/-lpng16 -lz/' "$PKG_CONFIG_PATH/libpng.pc"
    sed -i.bak 's/-lpng16.*$/-lpng16 -lz/' "$PKG_CONFIG_PATH/libpng16.pc"
  cd ..
}  

build_libopenjpeg() {
# FFmpeg doesn't yet take Openjpeg 2 so we compile version 1 here.
  download_and_unpack_file http://downloads.sourceforge.net/project/openjpeg.mirror/1.5.2/openjpeg-1.5.2.tar.gz openjpeg-1.5.2
  cd openjpeg-1.5.2
    # The CMakeFile include forces /usr/include, which is no use for Mingw builds at all.
#    sed  -i.bak "s|-I/usr/include||" applications/mj2/CMakeFiles/extract_j2k_from_mj2.dir/includes_C.rsp
    # export CFLAGS="$CFLAGS -DOPJ_STATIC" # see https://github.com/rdp/ffmpeg-windows-build-helpers/issues/37
    do_cmake "-DBUILD_CODEC:bool=off -DBUILD_VIEWER:bool=OFF -DBUILD_MJ2:bool=OFF -DBUILD_JPWL:bool=OFF -DBUILD_JPIP:bool=OFF -DBUILD_TESTS:BOOL=OFF -DBUILD_SHARED_LIBS:BOOL=OFF -DCMAKE_VERBOSE_MAKEFILE=OFF" 
    do_make_install
   # export CFLAGS=$original_cflags # reset it
  cd ..
}

build_libopenjpeg2() {
  download_and_unpack_file "http://downloads.sourceforge.net/project/openjpeg.mirror/2.1.0/openjpeg-2.1.0.tar.gz" openjpeg-2.1.0
  cd openjpeg-2.1.0
    export CFLAGS="$CFLAGS -DOPJ_STATIC"
    do_cmake "-D_BUILD_SHARED_LIBS:BOOL=OFF -DBUILD_VIEWER:bool=OFF -DBUILD_MJ2:bool=OFF -DBUILD_JPWL:bool=OFF -DBUILD_JPIP:bool=OFF -DBUILD_TESTS:bool=OFF -DBUILD_SHARED_LIBS:bool=OFF -DBUILD_CODEC:bool=OFF"
    do_make_install
    export CFLAGS=$original_cflags
  cd ..
}

build_libvpx() {
  if [[ $prefer_stable = "y" ]]; then
    download_and_unpack_file http://webm.googlecode.com/files/libvpx-v1.3.0.tar.bz2 libvpx-v1.3.0
    cd libvpx-v1.3.0
  else
    do_git_checkout https://chromium.googlesource.com/webm/libvpx "libvpx_git"
    cd libvpx_git
  fi
  export CROSS="$cross_prefix"
  if [[ "$bits_target" = "32" ]]; then
    do_configure "--extra-cflags=-DPTW32_STATIC_LIB --target=x86-win32-gcc --prefix=$mingw_w64_x86_64_prefix --enable-static --disable-shared"
  else
    do_configure "--extra-cflags=-DPTW32_STATIC_LIB --target=x86_64-win64-gcc --prefix=$mingw_w64_x86_64_prefix --enable-static --disable-shared --disable-unit-tests --disable-encode-perf-tests --disable-decode-perf-tests --enable-vp10 --enable-vp10-encoder --enable-vp10-decoder --enable-vp9-highbitdepth --enable-vp9-temporal-denoising --enable-postproc --enable-vp9-postproc"
  fi
  do_make_install
  unset CROSS
  cd ..
}

build_libutvideo() {
  download_and_unpack_file http://umezawa.dyndns.info/archive/utvideo/utvideo-12.2.1-src.zip utvideo-12.2.1
  cd utvideo-12.2.1
    apply_patch file://${top_dir}/utv.diff
    sed -i.bak "s|Format.o|DummyCodec.o|" GNUmakefile
    do_make_install "CROSS_PREFIX=$cross_prefix DESTDIR=$mingw_w64_x86_64_prefix prefix=" # prefix= to avoid it adding an extra /usr/local to it yikes
  cd ..
}


build_libilbc() {
  do_git_checkout https://github.com/dekkers/libilbc.git libilbc_git
  cd libilbc_git
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv || exit 1 # failure here, OS X means "you need libtoolize" perhaps? http://betterlogic.com/roger/2014/12/ilbc-cross-compile-os-x-mac-woe/
  fi
  generic_configure_make_install
  cd ..
}

build_libcdio-paranoia() {
  do_git_checkout https://github.com/rocky/libcdio-paranoia.git libcdio-paranoia
  cd libcdio-paranoia
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv || exit 1 # failure here, OS X means "you need libtoolize" perhaps? http://betterlogic.com/roger/2014/12/ilbc-cross-compile-os-x-mac-woe/
  fi
  generic_configure_make_install
  cd ..
}


build_lsdvd() {
  do_git_checkout git://git.code.sf.net/p/lsdvd/git lsdvd
  cd lsdvd
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv || exit 1 # failure here, OS X means "you need libtoolize" perhaps? http://betterlogic.com/roger/2014/12/ilbc-cross-compile-os-x-mac-woe/
  fi
  generic_configure_make_install
  cd ..
}


build_libflite() {
  download_and_unpack_file http://www.speech.cs.cmu.edu/flite/packed/flite-1.4/flite-1.4-release.tar.bz2 flite-1.4-release
  cd flite-1.4-release
   apply_patch flite_64.diff
   sed -i.bak "s|i386-mingw32-|$cross_prefix|" configure*
   generic_configure
   do_make
   make install # it fails in error...
   if [[ "$bits_target" = "32" ]]; then
     cp ./build/i386-mingw32/lib/*.a $mingw_w64_x86_64_prefix/lib || exit 1
   else
     cp ./build/x86_64-mingw32/lib/*.a $mingw_w64_x86_64_prefix/lib || exit 1
   fi
  cd ..
}

build_libgsm() {
  download_and_unpack_file http://www.quut.com/gsm/gsm-1.0.13.tar.gz gsm-1.0-pl13
  cd gsm-1.0-pl13
  apply_patch file://${top_dir}/libgsm.patch # for openssl to work with it, I think?
  # not do_make here since this actually fails [in error]
  make CC=${cross_prefix}gcc AR=${cross_prefix}ar RANLIB=${cross_prefix}ranlib INSTALL_ROOT=${mingw_w64_x86_64_prefix}
  cp lib/libgsm.a $mingw_w64_x86_64_prefix/lib || exit 1
  mkdir -p $mingw_w64_x86_64_prefix/include/gsm
  cp inc/gsm.h $mingw_w64_x86_64_prefix/include/gsm || exit 1
  cd ..
}

build_libopus() {
  download_and_unpack_file http://downloads.xiph.org/releases/opus/opus-1.1.1-beta.tar.gz opus-1.1.1-beta
  cd opus-1.1.1-beta
    apply_patch file://${top_dir}/opus11.patch # allow it to work with shared builds
    generic_configure_make_install "--enable-custom-modes --enable-asm" 
  cd ..
}

build_libdvdread() {
  build_libdvdcss
  download_and_unpack_file http://download.videolan.org/pub/videolan/libdvdread/5.0.2/libdvdread-5.0.2.tar.bz2 libdvdread-5.0.2
  cd libdvdread-5.0.2
  generic_configure "--with-libdvdcss CFLAGS=-DHAVE_DVDCSS_DVDCSS_H LDFLAGS=-ldvdcss" # vlc patch: "--enable-libdvdcss" # XXX ask how I'm *supposed* to do this to the dvdread peeps [svn?]
  #apply_patch https://raw.githubusercontent.com/rdp/ffmpeg-windows-build-helpers/master/patches/dvdread-win32.patch # has been reported to them...
  do_make_install 
  #sed -i "s/-ldvdread.*/-ldvdread -ldvdcss/" $mingw_w64_x86_64_prefix/bin/dvdread-config # ??? related to vlc patch, above, probably
  sed -i.bak 's/-ldvdread.*/-ldvdread -ldvdcss/' "$PKG_CONFIG_PATH/dvdread.pc"
  cd ..
}

build_libdvdnav() {
  download_and_unpack_file http://download.videolan.org/pub/videolan/libdvdnav/5.0.3/libdvdnav-5.0.3.tar.bz2 libdvdnav-5.0.3
  cd libdvdnav-5.0.3
  if [[ ! -f ./configure ]]; then
    ./autogen.sh
  fi
  generic_configure
  do_make_install 
  cd ..
}

build_libdvdcss() {
  do_git_checkout git://git.videolan.org/libdvdcss libdvdcss
  cd libdvdcss/src
#    apply_patch libdvdcss.c.patch
    cd ..
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
    fi
    generic_configure_make_install
  cd ..
}

build_gdb() {
  export LIBS="-lpsapi -ldl"
  generic_download_and_install http://ftp.gnu.org/gnu/gdb/gdb-7.9.tar.xz gdb-7.9
  unset LIBS
}

build_leptonica() {
  generic_download_and_install http://www.leptonica.com/source/leptonica-1.72.tar.gz leptonica-1.72 "LIBS=-lopenjpeg --disable-silent-rules --without-libopenjpeg"
}

build_ncurses() {
  export PATH_SEPARATOR=";"
  echo "mkdir -v -p ${mingw_w64_x86_64_prefix}/share/terminfo"
  mkdir -v -p ${mingw_w64_x86_64_prefix}/share/terminfo
  if [[ ! -f terminfo.src ]]; then
    wget http://invisible-island.net/datafiles/current/terminfo.src.gz
    gunzip terminfo.src.gz
  fi
  generic_download_and_install ftp://invisible-island.net/ncurses/current/ncurses-6.0-20150725.tgz ncurses-6.0-20150725 "--with-libtool --disable-termcap --enable-widec --enable-term-driver --enable-sp-funcs --without-ada --with-debug=no --with-shared=no --enable-database --with-progs --enable-interop --with-pkg-config-libdir=${mingw_w64_x86_64_prefix}/lib/pkgconfig --enable-pc-files"
  unset PATH_SEPARATOR
}

build_coreutils() {
  generic_download_and_install http://ftp.gnu.org/gnu/coreutils/coreutils-8.23.tar.xz coreutils-8.23
}

build_less() {
  generic_download_and_install http://greenwoodsoftware.com/less/less-471.tar.gz less-471
}

build_dvdbackup() {
  bzr branch lp:dvdbackup
  cd dvdbackup
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv || exit 1 # failure here, OS X means "you need libtoolize" perhaps? http://betterlogic.com/roger/2014/12/ilbc-cross-compile-os-x-mac-woe/
  fi
  sed -i.bak 's/mkdir(targetname, 0777)/mkdir(targetname)/' src/main.c
  generic_configure_make_install "LIBS=-ldvdcss"
  cd ..
}

build_glew() { # opengl stuff, apparently [disabled...]
  echo "still broken, wow this one looks tough LOL"
  exit
  download_and_unpack_file https://sourceforge.net/projects/glew/files/glew/1.10.0/glew-1.10.0.tgz/download glew-1.10.0 
  cd glew-1.10.0
    do_make_install "SYSTEM=linux-mingw32 GLEW_DEST=$mingw_w64_x86_64_prefix CC=${cross_prefix}gcc LD=${cross_prefix}ld CFLAGS=-DGLEW_STATIC" # could use $CFLAGS here [?] meh
    # now you should delete some "non static" files that it installed anyway? maybe? vlc does more here...
  cd ..
}

build_libopencore() {
  generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.3.tar.gz/download opencore-amr-0.1.3
  generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/vo-amrwbenc/vo-amrwbenc-0.1.2.tar.gz/download vo-amrwbenc-0.1.2
}

# NB this is kind of worse than just using the one that comes from the zeranoe script, since this one requires the -DPTHREAD_STATIC everywhere...
build_win32_pthreads() {
  download_and_unpack_file ftp://sourceware.org/pub/pthreads-win32/pthreads-w32-2-9-1-release.tar.gz   pthreads-w32-2-9-1-release
  cd pthreads-w32-2-9-1-release
    do_make "clean GC-static CROSS=$cross_prefix" # NB no make install
    cp libpthreadGC2.a $mingw_w64_x86_64_prefix/lib/libpthread.a || exit 1
    cp pthread.h sched.h semaphore.h $mingw_w64_x86_64_prefix/include || exit 1
  cd ..
}

build_libdlfcn() {
  do_git_checkout git://github.com/dlfcn-win32/dlfcn-win32.git dlfcn-win32
  cd dlfcn-win32
    ./configure --disable-shared --enable-static --cross-prefix=$cross_prefix --prefix=$mingw_w64_x86_64_prefix
    do_make_install
  cd ..
}

build_libjpeg_turbo() {
  do_git_checkout https://github.com/libjpeg-turbo/libjpeg-turbo libjpeg-turbo
  cd libjpeg-turbo
    do_cmake "-DENABLE_STATIC=TRUE -DENABLE_SHARED=FALSE"
    do_make_install
  # Change to CMAKE
#    if [[ ! -f "configure" ]]; then
#      autoreconf -fiv || exit 1
#    fi
#    sed -i.bak 's/nasm nasmw yasm/yasm nasm nasmw/' configure # tell it to prefer yasm, since nasm on OS X is old and broken for 64 bit builds
#    generic_configure_make_install
  
  cd ..
}

build_libogg() {
  generic_download_and_install http://downloads.xiph.org/releases/ogg/libogg-1.3.1.tar.gz libogg-1.3.1
}

build_libvorbis() {
  generic_download_and_install http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.4.tar.gz libvorbis-1.3.4
}

build_libspeex() {
  generic_download_and_install http://downloads.xiph.org/releases/speex/speex-1.2rc1.tar.gz speex-1.2rc1
}  

build_libtheora() {
  cpu_count=1 # can't handle it
#  download_and_unpack_file http://downloads.xiph.org/releases/theora/libtheora-1.2.0alpha1.tar.gz libtheora-1.2.0alpha1
#  cd libtheora-1.2.0alpha1
#    download_config_files
#    cd examples
#    apply_patch https://raw.githubusercontent.com/Warblefly/multimediaWin64/master/encoder_example.c.patch
#    cd ..
    do_svn_checkout http://svn.xiph.org/trunk/theora theora
    cd theora
      apply_patch file://${top_dir}/theora-examples-encoder_example.c.patch
      generic_configure_make_install
    cd ..
  #generic_download_and_install http://downloads.xiph.org/releases/theora/libtheora-1.2.0alpha1.tar.gz libtheora-1.2.0alpha1
  cpu_count=$original_cpu_count
}

build_libfribidi() {
  # generic_download_and_install http://fribidi.org/download/fribidi-0.19.5.tar.bz2 fribidi-0.19.5 # got report of still failing?
  download_and_unpack_file http://fribidi.org/download/fribidi-0.19.4.tar.bz2 fribidi-0.19.4
  cd fribidi-0.19.4
    # make it export symbols right...
    apply_patch file://${top_dir}/fribidi.diff
    generic_configure
    do_make_install
  cd ..

  #do_git_checkout http://anongit.freedesktop.org/git/fribidi/fribidi.git fribidi_git
  #cd fribidi_git
  #  ./bootstrap # couldn't figure out how to make this work...
  #  generic_configure
  #  do_make_install
  #cd ..
}

build_libass() {
  generic_download_and_install https://github.com/libass/libass/releases/download/0.12.1/libass-0.12.1.tar.gz libass-0.12.1
  # fribidi, fontconfig, freetype throw them all in there for good measure, trying to help mplayer once though it didn't help [FFmpeg needed a change for fribidi here though I believe]
  sed -i.bak 's/-lass -lm/-lass -lfribidi -lfontconfig -lfreetype -lexpat -lpng -lm/' "$PKG_CONFIG_PATH/libass.pc"
}

build_gmp() {
  download_and_unpack_file https://gmplib.org/download/gmp/gmp-6.0.0a.tar.bz2 gmp-6.0.0
  cd gmp-6.0.0
#    export CC_FOR_BUILD=/usr/bin/gcc
#    export CPP_FOR_BUILD=usr/bin/cpp
    generic_configure "ABI=$bits_target"
#    unset CC_FOR_BUILD
#    unset CPP_FOR_BUILD
    do_make_install
  cd .. 
}

build_orc() {
  generic_download_and_install http://download.videolan.org/contrib/orc-0.4.18.tar.gz orc-0.4.18
}

build_libxml2() {
  do_git_checkout git://git.gnome.org/libxml2 libxml2
  cd libxml2
    generic_configure_make_install "LIBS=-lws2_32 --without-python"
    sed -i.bak 's/-lxml2.*$/-lxml2 -lws2_32/' "$PKG_CONFIG_PATH/libxml-2.0.pc" # Shared applications need Winsock
  cd ..
#  generic_download_and_install ftp://xmlsoft.org/libxml2/libxml2-2.9.2.tar.gz libxml2-2.9.2 "--without-python"
}

build_libxslt() {
  do_git_checkout git://git.gnome.org/libxslt libxslt
#  cd libxslt-1.1.28/libxslt
#      apply_patch https://raw.githubusercontent.com/Warblefly/multimediaWin64/master/libxslt-security.c.patch
#    cd ..
    export LIBS="-lxml2"
    export LDFLAGS="-L${mingw_w64_x86_64_prefix}/lib"
  cd libxslt
    export CFLAGS="-DLIBXML_STATIC -DLIBXSLT_STATIC -DLIBEXSLT_STATIC"
    sed -i.bak 's/doc \\/ \\/' Makefile.am
    generic_configure_make_install "--disable-silent-rules --without-python --with-libxml-src=../libxml2"
    unset CFLAGS
    unset LIBS
    unset LDFLAGS
  cd ..
}

build_libxmlsec() {
  download_and_unpack_file http://www.aleksey.com/xmlsec/download/xmlsec1-1.2.20.tar.gz xmlsec1-1.2.20
  cd xmlsec1-1.2.20
    apply_patch file://${top_dir}/xsltsec-Makefile.in.patch
    generic_configure_make_install "--with-gcrypt=${mingw_w64_x86_64_prefix}"
  cd ..
}

build_libbluray() {
  do_git_checkout git://git.videolan.org/libbluray.git libbluray
  cd libbluray
    generic_configure_make_install "--disable-bdjava"
  cd ..
  sed -i.bak 's/-lbluray.*$/-lbluray -lxml2 -lws2_32/' "$PKG_CONFIG_PATH/libbluray.pc" # This is for mpv not linking against the right libraries
#  sed -i.bak 's/-lbluray.*$/-lbluray -lfreetype -lexpat -lz -lbz2/' "$PKG_CONFIG_PATH/libbluray.pc" # not sure...is this a blu-ray bug, or VLC's problem in not pulling freetype's .pc file? or our problem with not using pkg-config --static ...
}

build_libschroedinger() {
  download_and_unpack_file http://download.videolan.org/contrib/schroedinger-1.0.11.tar.gz schroedinger-1.0.11
  cd schroedinger-1.0.11
    generic_configure
    sed -i.bak 's/testsuite//' Makefile
    do_make_install
    sed -i.bak 's/-lschroedinger-1.0$/-lschroedinger-1.0 -lorc-0.4/' "$PKG_CONFIG_PATH/schroedinger-1.0.pc" # yikes!
  cd ..
}

build_gnutls() {
  download_and_unpack_file ftp://ftp.gnutls.org/gcrypt/gnutls/v3.4/gnutls-3.4.3.tar.xz gnutls-3.4.3
  cd gnutls-3.4.3
    generic_configure "--disable-cxx --disable-doc --without-p11-kit --enable-local-libopts --with-included-libtasn1" # don't need the c++ version, in an effort to cut down on size... XXXX test difference...
    do_make_install
  cd ..
  sed -i.bak 's/-lgnutls *$/-lgnutls -lnettle -lhogweed -lgmp -lcrypt32 -lws2_32 -liconv/' "$PKG_CONFIG_PATH/gnutls.pc"
}

build_libnettle() {
  download_and_unpack_file https://ftp.gnu.org/gnu/nettle/nettle-3.1.1.tar.gz nettle-3.1.1
  cd nettle-3.1.1
    generic_configure "--disable-openssl" # in case we have both gnutls and openssl, just use gnutls [except that gnutls uses this so...huh? https://github.com/rdp/ffmpeg-windows-build-helpers/issues/25#issuecomment-28158515
    do_make_install
  cd ..
}

build_bzlib2() {
  download_and_unpack_file http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz bzip2-1.0.6
  cd bzip2-1.0.6
    apply_patch file://$top_dir/bzip2_cross_compile.diff
    do_make "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar PREFIX=$mingw_w64_x86_64_prefix RANLIB=$(echo $cross_prefix)ranlib libbz2.a bzip2 bzip2recover install"
  cd ..
  mv $mingw_w64_x86_64_prefix/bin/bzip2  $mingw_w64_x86_64_prefix/bin/bzip2.exe
  mv $mingw_w64_x86_64_prefix/bin/bunzip2  $mingw_w64_x86_64_prefix/bin/bunzip2.exe
  mv $mingw_w64_x86_64_prefix/bin/bzcat  $mingw_w64_x86_64_prefix/bin/bzcat.exe
  mv $mingw_w64_x86_64_prefix/bin/bzip2recover  $mingw_w64_x86_64_prefix/bin/bzip2recover.exe
  mv $mingw_w64_x86_64_prefix/bin/bzgrep  $mingw_w64_x86_64_prefix/bin/bzgrep.exe
  mv $mingw_w64_x86_64_prefix/bin/bzmore  $mingw_w64_x86_64_prefix/bin/bzmore.exe
  mv $mingw_w64_x86_64_prefix/bin/bzdiff  $mingw_w64_x86_64_prefix/bin/bzdiff.exe
  rm $mingw_w64_x86_64_prefix/bin/bzegrep  $mingw_w64_x86_64_prefix/bin/bzfgrep  $mingw_w64_x86_64_prefix/bin/bzless $mingw_w64_x86_64_prefix/bin/bzcmp
  cp $mingw_w64_x86_64_prefix/bin/bzgrep.exe $mingw_w64_x86_64_prefix/bin/bzegrep.exe
  cp $mingw_w64_x86_64_prefix/bin/bzgrep.exe $mingw_w64_x86_64_prefix/bin/bzfgrep.exe
  cp $mingw_w64_x86_64_prefix/bin/bzmore.exe $mingw_w64_x86_64_prefix/bin/bzless.exe
  cp $mingw_w64_x86_64_prefix/bin/bzdiff.exe $mingw_w64_x86_64_prefix/bin/bzcmp.exe
}

build_zlib() {
  download_and_unpack_file http://zlib.net/zlib-1.2.8.tar.gz zlib-1.2.8
  cd zlib-1.2.8
    do_configure "--static --prefix=$mingw_w64_x86_64_prefix"
    do_make_install "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar RANLIB=$(echo $cross_prefix)ranlib ARFLAGS=rcs"
  cd ..
}

build_libxvid() {
  download_and_unpack_file http://downloads.xvid.org/downloads/xvidcore-1.3.3.tar.gz xvidcore
  cd xvidcore/build/generic
  if [ "$bits_target" = "64" ]; then
    local config_opts="--build=x86_64-unknown-linux-gnu --disable-assembly" # kludgey work arounds for 64 bit
  fi
  do_configure "--host=$host_target --prefix=$mingw_w64_x86_64_prefix $config_opts" # no static option...
  sed -i.bak "s/-mno-cygwin//" platform.inc # remove old compiler flag that now apparently breaks us

  cpu_count=1 # possibly can't build this multi-thread ? http://betterlogic.com/roger/2014/02/xvid-build-woe/
  do_make_install
  cpu_count=$original_cpu_count
  cd ../../..

  # force a static build after the fact by only installing the .a file
  if [[ -f "$mingw_w64_x86_64_prefix/lib/xvidcore.dll.a" ]]; then
    rm $mingw_w64_x86_64_prefix/lib/xvidcore.dll.a || exit 1
    mv $mingw_w64_x86_64_prefix/lib/xvidcore.a $mingw_w64_x86_64_prefix/lib/libxvidcore.a || exit 1
  fi
}

build_fontconfig() {
  download_and_unpack_file http://www.freedesktop.org/software/fontconfig/release/fontconfig-2.11.1.tar.gz fontconfig-2.11.1
  cd fontconfig-2.11.1
    generic_configure "--disable-docs"
    do_make_install
  cd .. 
  sed -i.bak 's/-L${libdir} -lfontconfig[^l]*$/-L${libdir} -lfontconfig -lfreetype -lexpat -lz/' "$PKG_CONFIG_PATH/fontconfig.pc"
}

build_libaacplus() {
  download_and_unpack_file http://217.20.164.161/~tipok/aacplus/libaacplus-2.0.2.tar.gz libaacplus-2.0.2
  cd libaacplus-2.0.2
    if [[ ! -f configure ]]; then
     ./autogen.sh --fail-early
    fi
    generic_configure_make_install 
  cd ..
}

build_openssl() {
  download_and_unpack_file http://www.openssl.org/source/openssl-1.0.2d.tar.gz openssl-1.0.2d
  cd openssl-1.0.2d
  export cross="$cross_prefix"
  export CC="${cross}gcc"
  export AR="${cross}ar"
  export RANLIB="${cross}ranlib"
  #XXXX do we need no-asm here?
  if [ "$bits_target" = "32" ]; then
    do_configure "--prefix=$mingw_w64_x86_64_prefix no-shared no-asm mingw" ./Configure
  else
    do_configure "--prefix=$mingw_w64_x86_64_prefix no-shared no-asm mingw64" ./Configure
  fi
  cpu_count=1
  do_make_install
  cpu_count=$original_cpu_count
  unset cross
  unset CC
  unset AR
  unset RANLIB
  cd ..
}

build_intel_quicksync_mfx() { # qsv
  do_git_checkout https://github.com/mjb2000/mfx_dispatch.git mfx_dispatch_git
  cd mfx_dispatch_git
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
    fi
    generic_configure_make_install
  cd ..
}

build_fdk_aac() {
  #generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-0.1.0.tar.gz/download fdk-aac-0.1.0
  do_git_checkout https://github.com/mstorsjo/fdk-aac.git fdk-aac_git
  cd fdk-aac_git
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
    fi
    generic_configure_make_install "--enable-example=yes"
  cd ..
}


build_libexpat() {
  generic_download_and_install http://sourceforge.net/projects/expat/files/expat/2.1.0/expat-2.1.0.tar.gz/download expat-2.1.0
}

build_ladspa() {
  curl -vo "${mingw_w64_x86_64_prefix}/include/ladspa.h" https://raw.githubusercontent.com/swh/ladspa/master/ladspa.h
}

build_libfftw() {
  generic_download_and_install http://www.fftw.org/fftw-3.3.4.tar.gz fftw-3.3.4 "--with-our-malloc16 --with-windows-f77-mangling --enable-threads --with-combined-threads --enable-portable-binary --enable-sse2 --with-incoming-stack-boundary=2"
}

build_libsamplerate() {
  generic_download_and_install http://www.mega-nerd.com/SRC/libsamplerate-0.1.8.tar.gz libsamplerate-0.1.8
}

build_vamp-sdk() {
  export cpu_count=1
  download_and_unpack_file http://code.soundsoftware.ac.uk/attachments/download/690/vamp-plugin-sdk-2.5.tar.gz vamp-plugin-sdk-2.5
  cd vamp-plugin-sdk-2.5
    # Tell the build system to use the mingw-w64 versions of binary utilities
    sed -i.bak 's/AR		= ar/AR		= x86_64-w64-mingw32-ar/' Makefile.in
    sed -i.bak 's/RANLIB		= ranlib/RANLIB		= x86_64-w64-mingw32-ranlib/' Makefile.in
    sed -i.bak 's/sdk plugins host rdfgen test/sdk plugins host rdfgen/' configure
    # Vamp installs shared libraries. They confuse mpv's linker (I think)
    export SNDFILE_LIBS="-lsndfile -lspeex -logg -lspeexdsp -lFLAC -lvorbisenc -lvorbis -logg -lvorbisfile -logg -lFLAC++ -lsndfile"
    generic_configure_make_install
    unset SNDFILE_LIBS
    echo "Now executing rm -fv $mingw_w64_x86_64_prefix/lib/libvamp*.so*"
    rm -fv $mingw_w64_x86_64_prefix/lib/libvamp*.so*
    export cpu_count=$original_cpu_count
  cd ..
}

build_librubberband() {
  download_and_unpack_file http://code.breakfastquay.com/attachments/download/34/rubberband-1.8.1.tar.bz2 rubberband-1.8.1
  cd rubberband-1.8.1
     sed -i.bak 's/:= ar/:= x86_64-w64-mingw32-ar/' Makefile.in
     sed -i.bak 's#:= bin/rubberband#:= bin/rubberband.exe#' Makefile.in
     export SNDFILE_LIBS="-lsndfile -lspeex -logg -lspeexdsp -lFLAC -lvorbisenc -lvorbis -logg -lvorbisfile -logg -lFLAC++ -lsndfile"
     generic_configure
     export cpu_count=1 
     do_make_install
     unset SNDFILE_LIBS
     # The shared libraries must vanish
     rm -fv ${mingw_w64_x86_64_prefix}/lib/librubberband*.so*
     # Need to force static linkers to link other libraries that rubberband depends on
     sed -i.bak 's/-lrubberband/-lrubberband -lsamplerate -lfftw3 -lstdc++/' "$PKG_CONFIG_PATH/rubberband.pc"
     export cpu_count=$original_cpu_count
  cd ..
}

build_iconv() {
  download_and_unpack_file http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz libiconv-1.14
  cd libiconv-1.14
    # Apply patch to fix non-exported inline function in gcc-5.2.0
    apply_patch file://${top_dir}/libiconv-1.14-iconv-fix-inline.patch
    # We also need an empty langinfo.h to compile this
#    touch $cur_dir/include/langinfo.h
    generic_configure_make_install
  cd ..
}

build_libgpg-error() {
  # We remove one of the .po files due to a bug in Cygwin's iconv that causes it to loop when converting certain character encodings
  download_and_unpack_file ftp://ftp.gnupg.org/gcrypt/libgpg-error/libgpg-error-1.19.tar.bz2 libgpg-error-1.19
  cd libgpg-error-1.19
#    rm po/ro.* # The Romanian translation causes Cygwin's iconv to loop. This is a Cygwin bug.
    generic_configure_make_install # "--prefix=${mingw_compiler_path/}" # This is so gpg-error-config can be seen by other programs
  cd ..
}

build_libgcrypt() {
#  generic_download_and_install ftp://ftp.gnupg.org/gcrypt/libgcrypt/libgcrypt-1.6.3.tar.gz libgcrypt-1.6.3 "GPG_ERROR_CONFIG=${mingw_w64_x86_64_prefix}/bin/gpg-error-config"
  do_git_checkout git://git.gnupg.org/libgcrypt.git libgcrypt
  cd libgcrypt
    generic_configure_make_install "GPG_ERROR_CONFIG=${mingw_w64_x86_64_prefix}/bin/gpg-error-config --disable-doc"
  cd ..
}

build_tesseract() {
  do_git_checkout https://github.com/tesseract-ocr/tesseract tesseract
  cd tesseract
    export LIBLEPT_HEADERSDIR="${mingw_w64_x86_64_prefix}/include/leptonica"
    export LIBS="-ltiff -ljpeg -lpng -lwebp -lz"
    sed -i.bak 's/Windows.h/windows.h/' opencl/openclwrapper.cpp
    sed -i.bak 's/-ltesseract/-ltesseract -llept -ltiff -ljpeg -lpng -lwebp -lz/' tesseract.pc.in
    # Unpack English language tessdata into data directory:
    tar xvvf ${top_dir}/tessdata-snapshot-20150411.tar.xz
    generic_configure_make_install
    cd tessdata
      do_make_install "install-langs LANGS=eng"
    cd ..
    unset LIBLEPT_HEADERSDIR
    unset LIBS
  cd ..
}

build_freetype() {
  download_and_unpack_file http://download.savannah.gnu.org/releases/freetype/freetype-2.5.5.tar.bz2 freetype-2.5.5
  cd freetype-2.5.5
  generic_configure "--with-png=yes --host=x86_64-w64-mingw32" # --build=x86_64-pc-cygwin"
#  cd src/tools
#    "/usr/bin/gcc -v apinames.c -o apinames.exe"
#    cp apinames.exe ../../objs
#  cd ../..
  do_make_install
#  export cpu_count=$original_cpu_count
  cd ..
  #generic_download_and_install http://download.savannah.gnu.org/releases/freetype/freetype-2.5.3.tar.gz freetype-2.5.3 "--with-png=no"
  sed -i.bak 's/Libs: -L${libdir} -lfreetype.*/Libs: -L${libdir} -lfreetype -lexpat -lpng -lz -lbz2/' "$PKG_CONFIG_PATH/freetype2.pc" # this should not need expat, but...I think maybe people use fontconfig's wrong and that needs expat? huh wuh? or dependencies are setup wrong in some .pc file?
  # possibly don't need the bz2 in there [bluray adds its own]...
#  export CFLAGS=${original_cflags}
}

build_vo_aacenc() {
  generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/vo-aacenc/vo-aacenc-0.1.3.tar.gz/download vo-aacenc-0.1.3
}

build_libcddb() {
  download_and_unpack_file http://sourceforge.net/projects/libcddb/files/latest/download libcddb-1.3.2
  cd libcddb-1.3.2
    apply_patch_p1 file://${top_dir}/0001-include-winsock2-before-windows.mingw.patch
    apply_patch_p1 file://${top_dir}/0002-fix-header-conflict.mingw.patch
    apply_patch_p1 file://${top_dir}/0003-silent-rules.mingw.patch
    apply_patch_p1 file://${top_dir}/0004-hack-around-dummy-alarm.mingw.patch
    apply_patch_p1 file://${top_dir}/0005-fix-m4-dir.all.patch
    apply_patch_p1 file://${top_dir}/0006-update-gettext-req.mingw.patch
    apply_patch_p1 file://${top_dir}/0007-link-to-libiconv-properly.mingw.patch
    cd lib
      apply_patch file://${top_dir}/cddb-1.3.2-lib-cddb_net.c.patch
    cd ..
#   The next line corrects a bad assumption about malloc when it is asked
#   the malloc zero
    generic_configure_make_install "ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes"
  cd ..
}

build_sdl() {
  # apparently ffmpeg expects prefix-sdl-config not sdl-config that they give us, so rename...
  hold_cflags="${CFLAGS}"
  export CFLAGS=-DDECLSPEC=  # avoid SDL trac tickets 939 and 282, not worried about optimizing yet
  generic_download_and_install http://www.libsdl.org/release/SDL-1.2.15.tar.gz SDL-1.2.15
  export CFLAGS="${hold_cflags}" # and reset it
  mkdir temp
  cd temp # so paths will work out right
  local prefix=$(basename $cross_prefix)
  local bin_dir=$(dirname $cross_prefix)
  sed -i.bak "s/-mwindows//" "$mingw_w64_x86_64_prefix/bin/sdl-config" # update this one too for good measure, ffmpeg can use either, not sure which one it defaults to...
  sed -i.bak "s/-mwindows//" "$PKG_CONFIG_PATH/sdl.pc" # allow ffmpeg to output anything to console: :|
  sed -i.bak "s/-lSDL *$/-lSDL  -lwinmm -lgdi32 -ldxguid/" "$PKG_CONFIG_PATH/sdl.pc" # mpv shared needs this linkage
  cp "$mingw_w64_x86_64_prefix/bin/sdl-config" "$bin_dir/${prefix}sdl-config" # this is the only mingw dir in the PATH so use it for now
  cd ..
  rmdir temp
}

#build_sdl2() {
#  # Building this for mpv but FIXME it always links libsdl(1) anyway. 
#  download_and_unpack_file https://www.libsdl.org/release/SDL2-2.0.3.tar.gz SDL2-2.0.3
#  cd SDL2-2.0.3
#    # DBL_EPSILON 21 Feb 2015 starts to come back "undefined". I have NO IDEA why.
#    grep -lr DBL_EPSILON src | xargs sed -i "s| DBL_EPSILON| 2.2204460492503131E-16|g"
#    generic_configure_make_install
#  cd ..
#}


build_sdl2() {
#  local old_hg_version
#  if [[ -d SDL ]]; then
#    cd SDL
#      echo "doing hg pull -u SDL"
#      old_hg_version=`hg --debug id -i`
#      hg pull -u || exit 1
#      hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
#  else
#    hg clone http://hg.libsdl.org/SDL || exit 1
#    cd SDL
#      old_hg_version=none-yet
#  fi
#  mkdir build
#
#  local new_hg_version=`hg --debug id -i`
#  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
#    echo "got upstream hg changes, forcing rebuild...SDL2"
#    apply_patch file://${top_dir}/SDL2-prevent-duplicate-d3d11-declarations.patch
#    cd build
#      rm already*
#      do_configure "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --disable-shared --enable-static --disable-render-d3d" "../configure" #3d3 disabled with --disable-render-d3d due to mingw-w64-4.0.0 and SDL disagreements
#      do_make_install  
#   cd ..
# else
#    echo "still at hg $new_hg_version SDL2"
#  fi
#  cd ..  

  generic_download_and_install "https://www.libsdl.org/tmp/SDL-2.0.4-9799.tar.gz" "SDL-2.0.4-9799" "--disable-render-d3d"

}



build_vim() {
  local old_hg_version
  if [[ -d vim ]]; then
    cd vim
      echo "doing hg pull -u vim"
      old_hg_version=`hg --debug id -i`
      hg pull -u || exit 1
      hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
  else
    hg clone http://vim.googlecode.com/hg vim || exit 1
    cd vim
      old_hg_version=none-yet
  fi
  
  local new_hg_version=`hg --debug id -i`
  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
    echo "got upstream hg changes, forcing rebuild...vim"
    cd src
      rm already*
#      apply_patch vim-Make_cyg_ming.mak.patch
      sed -i.bak 's/FEATURES=BIG/FEATURES=HUGE/' Make_cyg_ming.mak
      sed -i.bak 's/ARCH=i386/ARCH=x86-64/' Make_cyg_ming.mak
      sed -i.bak 's/CROSS=no/CROSS=yes/' Make_cyg_ming.mak
      sed -i.bak 's/WINDRES := windres/WINDRES := $(CROSS_COMPILE)windres/' Make_cyg_ming.mak
      echo "Now we are going to build vim."
      WINVER=0x0603 CROSS_COMPILE=${cross_prefix} make -f Make_ming.mak gvim.exe
      echo "Vim is built, but not installed."
      cp -fv gvim.exe vimrun.exe "${mingw_w64_x86_64_prefix}/bin"
    cd ..
  # Built but not yet installed
  else
    echo "still at hg $new_hg_version vim"
  fi
  cd ..
}


build_mpv() {
  do_git_checkout https://github.com/mpv-player/mpv.git mpv
  cd mpv
    ./bootstrap.py
    export DEST_OS=win32
    export TARGET=x86_64-w64-mingw32
    do_configure "configure -pp --prefix=${mingw_w64_x86_64_prefix} --enable-win32-internal-pthreads --disable-x11 --disable-lcms2 --enable-sdl1 --disable-sdl2 --disable-debug-build" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
    unset DEST_OS
    unset TARGET
  cd ..
}

build_faac() {
  generic_download_and_install http://downloads.sourceforge.net/faac/faac-1.28.tar.gz faac-1.28 "--with-mp4v2=no"
}

build_libsndfile() {
  generic_download_and_install http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.25.tar.gz libsndfile-1.0.25 "--enable-experimental"
}

build_libbs2b() {
  generic_download_and_install http://downloads.sourceforge.net/project/bs2b/libbs2b/3.1.0/libbs2b-3.1.0.tar.gz libbs2b-3.1.0 "ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes"
}

build_libgame-music-emu() {
  download_and_unpack_file  https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.0.tar.bz2 game-music-emu-0.6.0
  cd game-music-emu-0.6.0
    # sed -i.bak "s|SHARED|STATIC|" gme/CMakeLists.txt
    do_cmake_and_install
  cd ..
}

build_libdcadec() {
  do_git_checkout https://github.com/foo86/dcadec.git dcadec_git
  cd dcadec_git
    do_make_and_make_install "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar PREFIX=$mingw_w64_x86_64_prefix"
  cd ..
}

build_libwebp() {
  generic_download_and_install http://downloads.webmproject.org/releases/webp/libwebp-0.4.3.tar.gz libwebp-0.4.3
}

build_wavpack() {
  generic_download_and_install http://wavpack.com/wavpack-4.70.0.tar.bz2 wavpack-4.70.0
}


build_lame() {
  # generic_download_and_install http://sourceforge.net/projects/lame/files/lame/3.99/lame-3.99.5.tar.gz/download lame-3.99.5
  do_git_checkout https://github.com/rbrito/lame.git lame
  cd lame
  # For some reason, the definition of DBL_EPSILON has vanished
  grep -lr DBL_EPSILON libmp3lame | xargs sed -i "s|xmin, DBL_EPSILON|xmin, rh2|g"
  generic_configure_make_install
  cd ..
}

build_libMXFpp() {
  do_git_checkout git://git.code.sf.net/p/bmxlib/libmxfpp bmxlib-libmxfpp
  cd bmxlib-libmxfpp
  if [[ ! -f ./configure ]]; then
    ./autogen.sh
  fi
  generic_configure_make_install
  cd ..
}

build_mediainfo() {
		echo "compile MediaInfo_CLI"
		# rm -rf mediainfo
		# Mediainfo unfortunately uses svn, which takes a LOT of downloading; unfortunately, there is no
                # immediate way of knowing if the code has been updated.
                # So, we download it and check the MD5 of the downloaded archive, comparing it to anything that
                # has been compiled before. If they're the same, we don't compile.

#		a=`wget -qO- "http://sourceforge.net/projects/mediainfo/files/source/mediainfo/" | sed "s/<tbody>/\n<tbody>\n/g;s/<\/tbody>/\n<\/tbody>\n/g" | awk "/<tbody>/,/<\/tbody>/" | grep "tr.*title.*class.*folder" | sed "s/<tr.\.*title=\d034//g;s/\d034 class.*$//g" | sed "q1" | sed "s/%%20//g" | sed "s/ //g"`

#		b=`wget -qO- "http://sourceforge.net/projects/mediainfo/files/source/mediainfo/$a/" | sed "s/<tbody>/\n<tbody>\n/g;s/<\/tbody>/\n<\/tbody>\n/g" | awk "/<tbody>/,/<\/tbody>/" | grep "tr.*title.*class.*file" | sed "s/<tr.\.*title=\d034//g;s/\d034 class.*$//g" | grep "7z" | sed "s/ //g"`

#		wget --tries=20 --retry-connrefused --waitretry=2 -c -O mediainfo.7z "http://sourceforge.net/projects/mediainfo/files/source/mediainfo/$a/$b/download"
		
#		mkdir mediainfo

#		cd mediainfo
#		if [[ ! f ./mediainfo.md5 ]]; then
#		  md5sum ../mediainfo.7z > mediainfo.md5
#		fi
		
#		7za x ../mediainfo.7z
#		rm ../mediainfo.7z
                if [[ ! -d mediainfo ]]; then
		  mkdir mediainfo
		fi
		cd mediainfo
		do_svn_checkout http://svn.code.sf.net/p/mediainfo/code/MediaInfo/trunk MediaInfo
		do_svn_checkout http://svn.code.sf.net/p/mediainfo/code/MediaInfoLib/trunk MediaInfoLib
		do_svn_checkout http://svn.code.sf.net/p/zenlib/code/ZenLib/trunk ZenLib
                # Overcome a case-sensitivity issue
                sed -i.bak 's/Windows.h/windows.h/' MediaInfoLib/Source/MediaInfo/Reader/Reader_File.h
		sed -i.bak 's/Windows.h/windows.h/' MediaInfoLib/Source/MediaInfo/Reader/Reader_File.cpp
#		sed -i.bak '/#include <windows.h>/ a\#include <time.h>' ZenLib/Source/ZenLib/Ztring.cpp
		cd ZenLib/Project/GNU/Library
                generic_configure "--enable-shared=no --enable-static --prefix=$mingw_w64_x86_64_prefix --host=x86_64-w64-mingw32"
		sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
		do_make_install
		cd ../../../../MediaInfoLib/Project/GNU/Library
		do_configure "--enable-shared=no --enable-static --host=x86_64-w64-mingw32 --prefix=$mingw_w64_x86_64_prefix LDFLAGS=-static-libgcc --with-libcurl --with-libmms"
		sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
		do_make_install
		cd ../../../../MediaInfo/Project/GNU/CLI
		do_configure "--enable-static --host=x86_64-w64-mingw32 --prefix=$mingw_w64_x86_64_prefix --enable-staticlibs --enable-shared=no LDFLAGS=-static-libgcc"
		sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
		do_make_install
#                cd ../../../../..
		cd ../../../../..
#		echo "Now returned to `pwd`"
}

build_libtool() {
  generic_download_and_install http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz libtool-2.4.2 "--prefix=${mingw_w64_x86_64_prefix}/.."
}

build_exiv2() {
#  do_svn_checkout svn://dev.exiv2.org/svn/trunk exiv2
#  cd exiv2
  cpu_count=1 # svn_version.h gets written too early otherwise
  export LIBS="-lws2_32 -lwldap32"
#  make config
#  generic_configure_make_install "--enable-static=yes --enable-shared=no --without-ssh"
  generic_download_and_install http://www.exiv2.org/exiv2-0.24.tar.gz exiv2-0.24 "--enable-static=yes --enable-shared=no --without-ssh"
  unset LIBS
}

build_bmx() {
#  do_git_checkout git://git.code.sf.net/p/bmxlib/bmx bmxlib-bmx
#  cd bmxlib-bmx
#  if [[ ! -f ./configure ]]; then
#    ./autogen.sh
#  fi
#  generic_configure_make_install
#  cd ..
# bmx has added support for win32 mmap files using MSVC structured exceptions
# which GCC does not support. So we revert, for now, to the snapshot
# before this was added
  generic_download_and_install file://${top_dir}/bmxlib-bmx-15c92b198cb7378ccf54632718ed47a89aae1553.zip bmxlib-bmx-15c92b198cb7378ccf54632718ed47a89aae1553
}



build_liburiparser() {
  do_git_checkout git://git.code.sf.net/p/uriparser/git uriparser-git
  cd uriparser-git
  # This requires sys/socket.h, which mingw-w64 (Windows) doesn't have
  sed -i.bak 's/bin_PROGRAMS = uriparse/bin_PROGRAMS =/' Makefile.am
  if [[ ! -f ./configure ]]; then
    ./autogen.sh
  fi
  generic_configure_make_install "--disable-test --disable-doc"
  # Put back the change to allow git to update correctly
  sed -i.bak 's/bin_PROGRAMS =/bin_PROGRAMS = uriparse/' Makefile.am
  cd ..
}


build_zvbi() {
  export CFLAGS=-DPTW32_STATIC_LIB # seems needed XXX
  download_and_unpack_file http://sourceforge.net/projects/zapping/files/zvbi/0.2.35/zvbi-0.2.35.tar.bz2/download zvbi-0.2.35
  cd zvbi-0.2.35
    apply_patch file://${top_dir}/zvbi-win32.patch
    apply_patch file://${top_dir}/zvbi-ioctl.patch
    export LIBS=-lpng
    generic_configure " --disable-dvb --disable-bktr --disable-nls --disable-proxy --without-doxygen" # thanks vlc!
    unset LIBS
    cd src
      do_make_install 
    cd ..
#   there is no .pc for zvbi, so we add --extra-libs=-lpng to FFmpegs configure
#   sed -i 's/-lzvbi *$/-lzvbi -lpng/' "$PKG_CONFIG_PATH/zvbi.pc"
  cd ..
  export CFLAGS=$original_cflags # it was set to the win32-pthreads ones, so revert it
}

build_libmodplug() {
  generic_download_and_install http://sourceforge.net/projects/modplug-xmms/files/libmodplug/0.8.8.5/libmodplug-0.8.8.5.tar.gz/download libmodplug-0.8.8.5
  # unfortunately this sed isn't enough, though I think it should be [so we add --extra-libs=-lstdc++ to FFmpegs configure] http://trac.ffmpeg.org/ticket/1539
  sed -i.bak 's/-lmodplug.*/-lmodplug -lstdc++/' "$PKG_CONFIG_PATH/libmodplug.pc" # huh ?? c++?
  sed -i.bak 's/__declspec(dllexport)//' "$mingw_w64_x86_64_prefix/include/libmodplug/modplug.h" #strip DLL import/export directives
  sed -i.bak 's/__declspec(dllimport)//' "$mingw_w64_x86_64_prefix/include/libmodplug/modplug.h"
}

build_libcaca() {
  local cur_dir2=$(pwd)/libcaca
  do_git_checkout git://github.com/cacalabs/libcaca libcaca
  download_and_unpack_file http://ftp.netbsd.org/pub/pkgsrc/distfiles/libcaca-0.99.beta18.tar.gz libcaca-0.99.beta18
  cd libcaca-0.99.beta18
  # vsnprintf is defined both in libcaca and by mingw-w64-4.0.1 so we'll keep the system definition
  #apply_patch_p1 file://${top_dir}/libcaca-vsnprintf.patch
  #apply_patch_p1 file://${top_dir}/libcaca-signals.patch
  cd caca
    sed -i.bak "s/__declspec(dllexport)//g" *.h # get rid of the declspec lines otherwise the build will fail for undefined symbols
    sed -i.bak "s/__declspec(dllimport)//g" *.h 
  cd ..
  generic_configure_make_install "--libdir=$mingw_w64_x86_64_prefix/lib --disable-cxx --disable-csharp --disable-java --disable-python --disable-ruby --disable-imlib2 --disable-doc --disable-gl --disable-ncurses"
  cd ..
}


build_twolame() {
  generic_download_and_install http://sourceforge.net/projects/twolame/files/twolame/0.3.13/twolame-0.3.13.tar.gz/download twolame-0.3.13 "CPPFLAGS=-DLIBTWOLAME_STATIC"
}

build_regex() {
  download_and_unpack_file "http://sourceforge.net/projects/mingw/files/Other/UserContributed/regex/mingw-regex-2.5.1/mingw-libgnurx-2.5.1-src.tar.gz/download" mingw-libgnurx-2.5.1
  cd mingw-libgnurx-2.5.1
    # Patch for static version
    generic_configure
    apply_patch_p1 file://${top_dir}/libgnurx-1-build-static-lib.patch
    do_make "-f Makefile.mingw-cross-env libgnurx.a"
    x86_64-w64-mingw32-ranlib libgnurx.a 
    do_make "-f Makefile.mingw-cross-env install-static"
    # Some packages e.g. libcddb assume header regex.h is paired with libregex.a, not libgnurx.a
    cp $mingw_w64_x86_64_prefix/lib/libgnurx.a $mingw_w64_x86_64_prefix/lib/libregex.a
  cd ..
}

build_boost() { 
  download_and_unpack_file "http://downloads.sourceforge.net/project/boost/boost/1.58.0/boost_1_58_0.tar.gz" boost_1_58_0
  cd boost_1_58_0 
    local touch_name=$(get_small_touchfile_name already_configured "$configure_options $configure_name $LDFLAGS $CFLAGS") 
    if [ ! -f  "$touch_name" ]; then 
      ./bootstrap.sh --prefix=${mingw_w64_x86_64_prefix} || exit 1
      touch -- "$touch_name"
    else 
      echo "Already configured Boost libraries"
    fi
    local touch_name=$(get_small_touchfile_name already_build "$configure_options $configure_name $LDFLAGS $CFLAGS")
    if [ ! -f "$touch_name" ]; then
    # Create the custom build instructions
    # The following line is for CYGWIN
    # echo "using gcc : mxe : x86_64-w64-mingw32-g++.exe : <rc>x86_64-w64-mingw32-windres.exe <archiver>x86_64-w64-mingw32-ar.exe <ranlib>x86_64-w64-mingw32-ranlib.exe ;" > user-config.jam
    # The following lins is for GNU/Linux
    echo "using gcc : mxe : x86_64-w64-mingw32-g++ : <rc>x86_64-w64-mingw32-windres <archiver>x86_64-w64-mingw32-ar <ranlib>x86_64-w64-mingw32-ranlib ;" > user-config.jam
    # Configure and build in one step. ONLY the libraries necessary for mkvtoolnix are built.
      ./b2 --prefix=${mingw_w64_x86_64_prefix} -j 2 --ignore-site-config --user-config=user-config.jam address-model=64 architecture=x86 binary-format=pe link=static --target-os=windows threadapi=win32 threading=multi toolset=gcc-mxe --layout=tagged --disable-icu cxxflags='-std=c++11' --with-system --with-filesystem --with-regex --with-date_time install || exit 1
      touch -- "$touch_name"
    else
      echo "Already built and installed Boost libraries"
    fi
  cd ..  
}

build_mkvtoolnix() {
  do_git_checkout https://github.com/mbunkus/mkvtoolnix.git mkvtoolnix
  cd mkvtoolnix
    # Two libraries needed for mkvtoolnix
    git submodule init
    git submodule update
#    orig_ldflags=${LDFLAGS}
    # GNU ld uses a huge amount of memory here.
#    export LDFLAGS="-Wl,--hash-size=31"
    generic_configure_rake_install "--with-boost=${mingw_w64_x86_64_prefix} --with-boost-system=boost_system-mt --with-boost-filesystem=boost_filesystem-mt --with-boost-date-time=boost_date_time-mt --with-boost-regex=boost_regex-mt --without-curl --disable-qt"
#    export LDFLAGS=${orig_ldflags}
  cd ..
}

build_gavl() {
  do_svn_checkout svn://svn.code.sf.net/p/gmerlin/code/trunk/gavl gavl
  cd gavl
    generic_configure_make_install "--enable-shared=yes"
  cd ..
}

build_gomp() {
  do_svn_checkout https://github.com/gcc-mirror/gcc/trunk/libgomp gomp
  cd gomp
    autoreconf -fvi
    generic_configure_make_install
  cd ..
}

build_fdkaac-commandline() {
  do_git_checkout https://github.com/nu774/fdkaac.git fdkaac
  cd fdkaac
    if [[ ! -f "configure" ]]; then
    autoreconf -fiv || exit 1 
    fi
    generic_configure_make_install
  cd ..
}

build_SWFTools() {
  do_git_checkout git://github.com/matthiaskramm/swftools swftools
  cd swftools
    rm configure # Force regeneration of configure script to alleviate mingw-w64 conflicts
    aclocal -I m4
    autoconf
    sed -i.bak 's/$(INSTALL_MAN1);//' src/Makefile.in
    sed -i.bak 's/cd swfs;$(MAKE) $@//' Makefile.in
    generic_configure
    sed -i.bak 's/#define boolean int/typedef unsigned char boolean;/' config.h
    do_make_and_make_install
  cd ..
}

#build_cygwin() {
# Need code to automatically discover most recent snapshot
#  do_git_checkout https://github.com/mirror/cygwin.git cygwin || exit 1
#  cvs -z 4 -d :pserver:anoncvs:anoncvs@cygwin.com/cvs/src checkout cygwin
#  cvs -z 4 -d :pserver:anoncvs:anoncvs@cygwin.com/cvs/src checkout newlib
#  download_and_unpack_file ftp://sourceware.org/pub/newlib/newlib-2.2.0.20150225.tar.gz newlib-2.2.0.20150225 || exit 1
#  cd src
#   ln -s ../newlib-2.2.0.20150225/newlib newlib
    # This is going to be a Cygwin-native build, so use the normal Cygwin C compiler
#    export holding_path="${PATH}"
#    export PATH="/usr/bin:/bin:${mingw_compiler_path}/bin"
#    echo "PATH IS ${PATH}"
#      mkdir build
#      cd build
#        export cpu_count=1
#        do_configure "--prefix=${mingw_w64_x86_64_prefix}/x86_64_pc_cygwin --enable-shared=yes" "../configure"
#        do_make 
#        do_make_install
#        export cpu_count=$original_cpu_count
#    cd ../..
#    export PATH="${holding_path}"
#}

build_frei0r() {
  do_git_checkout git://git.dyne.org/frei0r.git frei0r
  cd frei0r
    # The next three patches cope with the missing definition of M_PI
    apply_patch file://${top_dir}/frei0r-lightgraffiti.cpp.patch
    apply_patch file://${top_dir}/frei0r-vignette.cpp.patch
    apply_patch file://${top_dir}/frei0r-partik0l.cpp.patch
    # The next patch fixes a compilation problem due to curly brackets
    apply_patch file://${top_dir}/frei0r-facedetect.cpp-brackets.patch
    # These are ALWAYS compiled as DLLs... there is no static library model in frei0r
    do_cmake "-DOpenCV_DIR=${OpenCV_DIR} -DOpenCV_INCLUDE_DIR=${OpenCV_INCLUDE_DIR} -DCMAKE_CXX_FLAGS=-std=c++14"
    do_make_install "-j1"
  cd ..
}

build_vidstab() {
  do_git_checkout https://github.com/georgmartius/vid.stab.git vid.stab # "430b4cffeb" # 0.9.8
  cd vid.stab
    sed -i.bak "s/SHARED/STATIC/g" CMakeLists.txt # static build-ify
    do_cmake "-DUSE_OMP:bool=off"
    do_make_install 
  cd ..
}

build_pkg-config() {
  cp -v /usr/bin/pkg-config ${mingw_w64_x86_64_prefix}/../bin/x86_64-w64-mingw32-pkg-config
}

build_opustools() {
  do_git_checkout https://git.xiph.org/opus-tools.git opus-tools
  cd opus-tools
  if [[ ! -f "configure" ]]; then
    ./autogen.sh
  fi
  generic_configure_make_install
  cd ..
}

build_libmms() {
  do_git_checkout git://git.code.sf.net/p/libmms/code libmms-code
  cd libmms-code
    generic_configure_make_install
  cd ..
}

build_curl() {
  generic_download_and_install http://curl.haxx.se/download/curl-7.42.1.tar.bz2 curl-7.42.1 "--enable-ipv6 --with-librtmp"
}

build_asdcplib() {
  export CFLAGS="-DKM_WIN32"
  export cpu_count=1
  download_and_unpack_file http://download.cinecert.com/asdcplib/asdcplib-1.12.60.tar.gz asdcplib-1.12.60
  cd asdcplib-1.12.60
    export LIBS="-lws2_32 -lcrypto -lssl -lgdi32"
    generic_configure "CXXFLAGS=-DKM_WIN32 CFLAGS=-DKM_WIN32 --with-openssl=${mingw_w64_x86_64_prefix} --with-expat=${mingw_w64_x86_64_prefix}"
    do_make "CXXFLAGS=-DKM_WIN32 CFLAGS=-DKM_WIN32"
    do_make_install
  cd .. 
  unset LIBS
  export CFLAGS=$original_cflags
  export cpu_count=$original_cpu_count
}

build_libtiff() {
  generic_download_and_install ftp://ftp.remotesensing.org/pub/libtiff/tiff-4.0.4beta.tar.gz tiff-4.0.4beta
}

build_opencl() {
# Method: get the headers, then create libOpenCL.a from the vendor-supplied OpenCL.dll
# on the compilation system.
# Get the headers from the source
  mkdir -p ${mingw_w64_x86_64_prefix}/include/CL && cd ${mingw_w64_x86_64_prefix}/include/CL
    wget --no-clobber http://www.khronos.org/registry/cl/api/1.2/cl_d3d10.h \
http://www.khronos.org/registry/cl/api/1.2/cl_d3d11.h \
http://www.khronos.org/registry/cl/api/1.2/cl_dx9_media_sharing.h \
http://www.khronos.org/registry/cl/api/1.2/cl_ext.h \
http://www.khronos.org/registry/cl/api/1.2/cl_gl_ext.h \
http://www.khronos.org/registry/cl/api/1.2/cl_gl.h \
http://www.khronos.org/registry/cl/api/1.2/cl.h \
http://www.khronos.org/registry/cl/api/1.2/cl_platform.h \
http://www.khronos.org/registry/cl/api/1.2/opencl.h \
http://www.khronos.org/registry/cl/api/1.2/cl.hpp \
http://www.khronos.org/registry/cl/api/1.2/cl_egl.h
  cd -
  cd ${top_dir}
# Use the installed OpenCL.dll to make libOpenCL.a
# This is an insecure method. Write something better! FIXME
  gendef ./OpenCL.dll
  x86_64-w64-mingw32-dlltool -l libOpenCL.a -d OpenCL.def -k -A
  mv libOpenCL.a ${mingw_w64_x86_64_prefix}/lib/libOpenCL.a
  cd -
}

build_lua() {
  # Needed for mpv to use YouTube URLs. mpv looks for it in pkg-config path so might be
  # best to compile our own mingw version
  download_and_unpack_file http://www.lua.org/ftp/lua-5.2.3.tar.gz lua-5.2.3
  cd lua-5.2.3
    apply_patch_p1 file://${top_dir}/lua-5.2.3-static-mingw.patch
    # Adjustments when not building on Cygwin
    sed -i.bak 's/-gcc.exe/-gcc/' Makefile
    sed -i.bak 's/-ar.exe/-ar/' Makefile
    sed -i.bak 's/-ranlib.exe/-ranlib/' Makefile
    sed -i.bak 's/-gcc.exe/-gcc/' src/Makefile
    sed -i.bak 's/-ar.exe/-ar/' src/Makefile
    sed -i.bak 's/-ranlib.exe/-ranlib/' src/Makefile
    do_make "posix"
    do_make_install "posix"
  cd ..
  # mpv player (and possibly others) need to detect an lua.pc pkgconfig file
  # One must expand variables, and awk will do this.
while read line; do eval echo \"$line\"; done > ${PKG_CONFIG_PATH}/lua.pc << "EOF"
V=5.2
R=5.2.3

prefix=${mingw_w64_x86_64_prefix}
INSTALL_BIN=${mingw_w64_x86_64_prefix}/bin
INSTALL_INC=${mingw_w64_x86_64_prefix}/include
INSTALL_LIB=${mingw_w64_x86_64_prefix}/lib
INSTALL_MAN=${mingw_w64_x86_64_prefix}/man/man1
INSTALL_LMOD=${mingw_w64_x86_64_prefix}/share/lua/5.3
INSTALL_CMOD=${mingw_w64_x86_64_prefix}/lib/lua/5.3
exec_prefix=${mingw_w64_x86_64_prefix}
libdir=${mingw_w64_x86_64_prefix}/lib
includedir=${mingw_w64_x86_64_prefix}/include

Name: Lua
Description: An Extensible Extension Language
Version: 5.2.3
Requires: 
Libs: -L${mingw_w64_x86_64_prefix}/lib -llua -lm
Cflags: -I${mingw_w64_x86_64_prefix}/include
EOF
}

build_sox() {
  do_git_checkout git://sox.git.sourceforge.net/gitroot/sox/sox sox
  cd sox
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv
  fi
  generic_configure_make_install
  cd ..
}

build_openssh() {
    generic_download_and_install http://mirror.bytemark.co.uk/pub/OpenBSD/OpenSSH/portable/openssh-7.1p1.tar.gz openssh-7.1p1 "LIBS=-lgdi32"
}


build_ffms2() {
  do_git_checkout https://github.com/FFMS/ffms2.git ffms2
  cd ffms2
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv
    fi
    apply_patch file://${top_dir}/ffms2.videosource.cpp.patch
    generic_configure_make_install "--disable-static --enable-shared"
  cd ..
}

build_flac() {
  do_git_checkout https://git.xiph.org/flac.git flac
  cd flac
  # microbench target hasn't been tested on many platforms yet
  sed -i.bak 's/microbench//' Makefile.am
  if [[ ! -f "configure" ]]; then
    ./autogen.sh
  fi
  generic_configure_make_install "--disable-shared --enable-static  --disable-doxygen-docs"
  cd ..
}

build_youtube-dl() {
  do_git_checkout https://github.com/rg3/youtube-dl youtube-dl
  cd youtube-dl
    do_make youtube-dl
    cp youtube-dl "${mingw_w64_x86_64_prefix}/bin/youtube-dl.py"
  cd ..
}

# build_cdrecord() {
#  download_and_unpack_bz2file http://downloads.sourceforge.net/project/cdrtools/alpha/cdrtools-3.01a27.tar.bz2 cdrtools-3.01
#  cd cdrtools-3.01
#    export holding_path="${PATH}"
#    export PATH="/usr/bin:/bin:${mingw_compiler_path}/bin"
#  apply_patch https://raw.githubusercontent.com/Warblefly/multimediaWin64/master/cdrtools-3.01a25_mingw.patch
# do_smake "STRIPFLAGS=-s K_ARCH=i386 M_ARCH=i386 P_ARCH=i386 ARCH=i386 OSNAME=mingw32_nt-6.2 CC=${cross_prefix}gcc.exe INS_BASE=$mingw_w64_x86_64_prefix"
# do_smake_install "STRIPFLAGS=-s K_ARCH=i386 M_ARCH=i386 P_ARCH=i386 ARCH=i386 OSNAME=mingw32_nt-6.2 CC=${cross_prefix}gcc.exe INS_BASE=$mingw_w64_x86_64_prefix"
#    do_smake "STRIPFLAGS=-s INS_BASE=${mingw_w64_x86_64_prefix}/x86_64_pc_cygwin"
#    do_smake_install "STRIPFLAGS=-s ${mingw_w64_x86_64_prefix}/x86_64_pc_cygwin"
#  cd .. 
#  export PATH="${holding_path}"
#}

#build_smake() { # This enables build of cdrtools. Jorg Schilling uses his own make system called smake
                # which first nust be compiled for the native Cygwin architecture. Mingw builds don't
                # work for me
#  download_and_unpack_bz2file http://downloads.sourceforge.net/project/s-make/smake-1.2.4.tar.bz2 smake-1.2.4
#  cd smake-1.2.4
#  orig_path=$PATH
#  export PATH=/bin:/usr/bin:/sbin:/usr/sbin
#  /usr/bin/make STRIPFLAGS=-s INS_BASE=${mingw_w64_x86_64_prefix}/.. || exit 1
#  /usr/bin/make install STRIPFLAGS=-s INS_BASE=${mingw_w64_x86_64_prefix}/.. || exit 1
#  export PATH="${orig_path}"
#  cd ..
#}

build_libcdio() {
  do_git_checkout http://git.savannah.gnu.org/r/libcdio.git libcdio
  cd libcdio
  if [[ ! -f "configure" ]]; then
    autoreconf -fvi
  fi
  touch ./doc/version.texi # Documentation isn't included but the Makefile still wants it
  touch src/cd-drive.1 src/cd-info.1 src/cd-read.1 src/iso-info.1 src/iso-read.1
  generic_configure_make_install "--disable-shared --enable-static"
  cd ..  
}

build_makemkv() { # THIS IS NOT WORKING - MAKEMKV NEEDS MORE THAN MINGW OFFERS
  download_and_unpack_file http://www.makemkv.com/download/makemkv-oss-1.8.13.tar.gz makemkv-oss-1.8.13
  cd makemkv-oss-1.8.13
  sed -i.bak 's/,-z,/,/' Makefile.in
  generic_configure "--disable-gui"
  sed -i.bak 's/#include <alloca.h>/#include <malloc.h>/' libmmbd/src/mmconn.cpp
  do_make_install
  generic_download_and_install http://www.makemkv.com/download/makemkv-bin-1.8.13.tar.gz makemkv-bin-1.8.13
  cd ..
}

build_vlc() {
  do_git_checkout https://github.com/videolan/vlc.git vlc_git
  cd vlc_git
    if [[ ! -f "configure" ]]; then
      ./bootstrap
    fi 
    export DVDREAD_LIBS='-ldvdread -ldvdcss -lpsapi'
    do_configure "--disable-libgcrypt --disable-a52 --host=$host_target --disable-lua --disable-mad --enable-qt --disable-sdl --disable-mod --disable-static --enable-shared" # don't have lua mingw yet, etc. [vlc has --disable-sdl [?]] x265 disabled until we care enough... Looks like the bluray problem was related to the BLURAY_LIBS definition. [not sure what's wrong with libmod]
    rm -f `find . -name *.exe` # try to force a rebuild...though there are tons of .a files we aren't rebuilding as well FWIW...:|
    rm -f already_ran_make* # try to force re-link just in case...
    do_make
  # do some gymnastics to avoid building the mozilla plugin for now [couldn't quite get it to work]
  #sed -i.bak 's_git://git.videolan.org/npapi-vlc.git_https://github.com/rdp/npapi-vlc.git_' Makefile # this wasn't enough...
    sed -i.bak "s/package-win-common: package-win-install build-npapi/package-win-common: package-win-install/" Makefile
    sed -i.bak "s/.*cp .*builddir.*npapi-vlc.*//g" Makefile
    make package-win-common # not do_make, fails still at end, plus this way we get new vlc.exe's
    echo "
     created a file like ${PWD}/vlc-2.2.0-git/vlc.exe
"

  cd ..
}

build_mplayer() {
 # pre requisites
  build_libdvdread
  build_libdvdnav
  build_libdvdcss
  download_and_unpack_bz2file http://www.mplayerhq.hu/MPlayer/releases/mplayer-export-snapshot.tar.bz2 mplayer
  cd mplayer
  do_git_checkout https://github.com/FFmpeg/FFmpeg ffmpeg
#  export LDFLAGS='-lpthread -ldvdread -ldvdcss' # not compat with newer dvdread possibly? huh wuh?
#  export CFLAGS=-DHAVE_DVDCSS_DVDCSS_H
  do_configure  "--enable-cross-compile --host-cc=${cross_prefix}gcc --cc=${cross_prefix}gcc --windres=${cross_prefix}windres --ranlib=${cross_prefix}ranlib --ar=${cross_prefix}ar --as=${cross_prefix}as --nm=${cross_prefix}nm --enable-runtime-cpudetection --enable-static"


#  do_configure "--enable-cross-compile --host-cc=${cross_prefix}gcc --cc=${cross_prefix}gcc --windres=${cross_prefix}windres --ranlib=${cross_prefix}ranlib --ar=${cross_prefix}ar --as=${cross_prefix}as --nm=${cross_prefix}nm --enable-runtime-cpudetection --extra-cflags=$CFLAGS --with-dvdnav-config=$mingw_w64_x86_64_prefix/bin/dvdnav-config --disable-w32threads --enable-pthreads --extra-libs=-lpthread --enable-debug --enable-ass-internal" # haven't reported the ldvdcss thing, think it's to do with possibly it not using dvdread.pc [?] XXX check with trunk
#  unset LDFLAGSexport CFLAGS=$original_cflags
#  sed -i.bak "s/HAVE_PTHREAD_CANCEL 0/HAVE_PTHREAD_CANCEL 1/g" config.h # mplayer doesn't set this up right?
#  touch -t 201203101513 config.h # the above line change the modify time for config.h--forcing a full rebuild *every time* yikes!
 # try to force re-link just in case...
  rm *.exe
  rm already_ran_make* # try to force re-link just in case...
  do_make
  cp mplayer.exe mplayer_debug.exe
  ${cross_prefix}strip mplayer.exe
  echo "built ${PWD}/{mplayer,mencoder,mplayer_debug}.exe"
#  CPPFLAGS='-DFRIBIDI_ENTRY="" ' ./configure --prefix=$mingw_w64_x86_64_prefix --bindir=$mingw_w64_x86_64_prefix/bin --cc=gcc --extra-cflags='-DPTW32_STATIC_LIB -O3 -std=gnu99 -DLIBTWOLAME_STATIC -DAL_LIBTYPE_STATIC' --extra-libs='-lxml2 -llzma -lfreetype -lz -lbz2 -liconv -lws2_32 -lpthread -lwinpthread -lpng -ldvdcss -lOpenAL32 -lwinmm -lole32' --extra-ldflags='-Wl,--allow-multiple-definition' --enable-static --enable-openal --enable-runtime-cpudetection --enable-ass-internal --enable-bluray --disable-dvdread-internal --disable-libdvdcss-internal --disable-gif $faac
		
  #make
  #make install
  cd ..
}

build_mp4box() { # like build_gpac
  # This script only builds the gpac_static lib plus MP4Box. Other tools inside
  # specify revision until this works: https://sourceforge.net/p/gpac/discussion/287546/thread/72cf332a/
  do_svn_checkout https://svn.code.sf.net/p/gpac/code/trunk/gpac mp4box_gpac
  cd mp4box_gpac
  # are these tweaks needed? If so then complain to the mp4box people about it?
  # sed -i "s/has_dvb4linux=\"yes\"/has_dvb4linux=\"no\"/g" configure
  # sed -i "s/`uname -s`/MINGW32/g" configure
  # XXX do I want to disable more things here?
  sed -i.bak 's#bin/gcc/MP4Box#bin/gcc/MP4Box.exe#' Makefile
  sed -i.bak 's#bin/gcc/MP42TS#bin/gcc/MP42TS.exe#' Makefile
  sed -i.bak 's/	$(MAKE) installdylib/#	$(MAKE) installdylib/' Makefile
#  sed -i.bak 's/-DDIRECTSOUND_VERSION=0x0500/-DDIRECTSOUND_VERSION=0x0800/' src/Makefile
  generic_configure_make_install "--verbose --static-mp4box --enable-static-bin --target-os=MINGW32 --cross-prefix=x86_64-w64-mingw32- --prefix=${mingw_w64_x86_64_prefix} --static-mp4box --extra-libs=-lz --enable-all" 
#  do_make
  # I seem unable to pass 3 libs into the same config line so do it with sed...
#  sed -i.bak "s/EXTRALIBS=.*/EXTRALIBS=-lws2_32 -lwinmm -lz/g" config.mak
  # The next two lines remove two #defines in config.h that redefine something in MinGW-64
#  sed -i.bak '/#define ftello64 ftell/d' config.h
#  sed -i.bak '/#define fseeko64 fseek/d' config.h
#  cd src
#  rm already_
#  do_make "CC=${cross_prefix}gcc AR=${cross_prefix}ar RANLIB=${cross_prefix}ranlib PREFIX= STRIP=${cross_prefix}strip"
#  cd ..
#  rm ./bin/gcc/MP4Box* # try and force a relink/rebuild of the .exe
#  cd applications/mp4box
#  rm already_ran_make*
#  do_make "CC=${cross_prefix}gcc AR=${cross_prefix}ar RANLIB=${cross_prefix}ranlib PREFIX= STRIP=${cross_prefix}strip"
#  cd ../..
  # copy it every time just in case it was rebuilt...
#  cp ./bin/gcc/MP4Box ./bin/gcc/MP4Box.exe # it doesn't name it .exe? That feels broken somehow...
#  echo "built $(readlink -f ./bin/gcc/MP4Box.exe)"
#  cp ./bin/gcc/MP4Box.exe $mingw_w64_x86_64_prefix/bin/MP4Box.exe
  cd ..
}


build_libMXF() {
  #download_and_unpack_file http://sourceforge.net/projects/ingex/files/1.0.0/libMXF/libMXF-src-1.0.0.tgz "libMXF-src-1.0.0"
  #cd libMXF-src-1.0.0
  #apply_patch https://raw.githubusercontent.com/rdp/ffmpeg-windows-build-helpers/master/patches/libMXF.diff
  #do_make "MINGW_CC_PREFIX=$cross_prefix"
#  do_git_checkout git://git.code.sf.net/p/bmxlib/libmxf bmxlib-libmxf
  download_and_unpack_file file://${top_dir}/bmxlib-libmxf-353c344ec81315e8936f54ed753bcff00dd783b4.zip bmxlib-libmxf-353c344ec81315e8936f54ed753bcff00dd783b4
#  cd bmxlib-libmxf
  cd bmxlib-libmxf-353c344ec81315e8936f54ed753bcff00dd783b4
    cd tools/MXFDump
    if [[ ! -e patch_done ]]; then
      echo "applying patch to bmxlib-libmxf"
      MXFPATCH="
--- MXFDump.cpp 2014-09-24 08:46:22.840096500 +0100
+++ MXFDump-patched.cpp 2014-09-24 09:28:00.964403200 +0100
@@ -89,6 +89,9 @@
 #elif defined(__GNUC__) && defined(__sparc__) && defined(__sun__)
 #define MXF_COMPILER_GCC_SPARC_SUNOS
 #define MXF_OS_UNIX
+#elif defined(__GNUC__) && defined(__x86_64__) && defined(__MINGW64__)
+#define MXF_COMPILER_GCC_INTEL_WINDOWS
+#define MXF_OS_WINDOWS
 #else
 #error \"Unknown compiler\"
 #endif"
      echo "$MXFPATCH" | patch
      touch patch_done
    else
      echo "patch for MXFDump.exe already applied"
    fi
    cd ../..
  if [[ ! -f ./configure ]]; then
    ./autogen.sh
  fi
  generic_configure_make_install
  #
  # Manual equivalent of make install.  Enable it if desired.  We shouldn't need it in theory since we never use libMXF.a file and can just hand pluck out the *.exe files...
  #
  # cp libMXF/lib/libMXF.a $mingw_w64_x86_64_prefix/lib/libMXF.a
  # cp libMXF++/libMXF++/libMXF++.a $mingw_w64_x86_64_prefix/lib/libMXF++.a
  # mv libMXF/examples/writeaviddv50/writeaviddv50 libMXF/examples/writeaviddv50/writeaviddv50.exe
  # mv libMXF/examples/writeavidmxf/writeavidmxf libMXF/examples/writeavidmxf/writeavidmxf.exe
  # cp libMXF/examples/writeaviddv50/writeaviddv50.exe $mingw_w64_x86_64_prefix/bin/writeaviddv50.exe
  # cp libMXF/examples/writeavidmxf/writeavidmxf.exe $mingw_w64_x86_64_prefix/bin/writeavidmxf.exe
  cd ..
}

build_imagemagick()
{
#  do_svn_checkout https://subversion.imagemagick.org/subversion/ImageMagick/trunk ImageMagick
#  cd ImageMagick
    # Must turn off X. configure picks it up otherwise
#    apply_patch file:///home/john/source/buildingffmpeg/ImageMagick-libjpeg-boolean.patch
#    apply_patch file:///home/john/source/buildingffmpeg/ImageMagick-mingw-w64.patch
#    generic_configure_make_install "--without-x"
#  cd ..
  generic_download_and_install http://www.imagemagick.org/download/ImageMagick.tar.gz ImageMagick-6.9.1-10
}

build_graphicsmagick() {
  local old_hg_version
  if [[ -d GM ]]; then
    cd GM
      echo "doing hg pull -u GM"
      old_hg_version=`hg --debug id -i`
     hg pull -u || exit 1
     hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
  else
    hg clone http://hg.code.sf.net/p/graphicsmagick/code GM || exit 1
    cd GM
      old_hg_version=none-yet
  fi
  mkdir build

  local new_hg_version=`hg --debug id -i`
  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
    echo "got upstream hg changes, forcing rebuild...GraphicsMagick"
    cd build
      rm already*
#      generic_download_and_install ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/snapshots/GraphicsMagick-1.4.020150919.tar.xz GraphicsMagick-1.4.020150919 "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-magick-compat --disable-shared --enable-static --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix}/include CPPFLAGS=-I${mingw_w64_x86_64_prefix}" 
      do_configure "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-magick-compat --disable-shared --enable-static --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix}/include CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
      do_make_install || exit 1
    cd ..
  else
    echo "still at hg $new_hg_version GraphicsMagick"
  fi
  cd ..
}

build_libdecklink() {
  if [[ ! -f $mingw_w64_x86_64_prefix/include/DeckLinkAPI_i.c ]]; then
    curl https://raw.githubusercontent.com/rdp/ffmpeg-windows-build-helpers/master/patches/DeckLinkAPI.h > $mingw_w64_x86_64_prefix/include/DeckLinkAPI.h  || exit 1
    curl https://raw.githubusercontent.com/rdp/ffmpeg-windows-build-helpers/master/patches/DeckLinkAPI_i.c > $mingw_w64_x86_64_prefix/include/DeckLinkAPI_i.c.tmp  || exit 1
    curl https://raw.githubusercontent.com/jp9000/obs-studio/master/plugins/decklink/mac/decklink-sdk/DeckLinkAPIVersion.h > $mingw_w64_x86_64_prefix/include/DeckLinkAPIVersion.h  || exit 1
    mv $mingw_w64_x86_64_prefix/include/DeckLinkAPI_i.c.tmp $mingw_w64_x86_64_prefix/include/DeckLinkAPI_i.c
  fi
}

build_ffmpeg() {
  local type=$1
  local shared=$2
  local git_url="https://github.com/FFmpeg/FFmpeg.git"
  local output_dir="ffmpeg_git"

  # FFmpeg + libav compatible options
  # add libpsapi to enable libdlfcn for Windows to work, thereby enabling frei0r plugins
  local extra_configure_opts="--enable-libsoxr --enable-fontconfig --enable-libass --enable-libutvideo --enable-libbluray --enable-iconv --enable-libtwolame --extra-cflags=-DLIBTWOLAME_STATIC --enable-libzvbi --enable-libcaca --enable-libmodplug --extra-libs=-lstdc++ --extra-libs=-lpsapi --enable-opengl --extra-libs=-lz --extra-libs=-lpng --enable-libvidstab --enable-libx265 --enable-decklink --extra-libs=-loleaut32 --enable-libcdio --enable-libbluray "

  if [[ $type = "libav" ]]; then
    # libav [ffmpeg fork]  has a few missing options?
    git_url="https://github.com/libav/libav.git"
    output_dir="libav_git"
    final_install_dir=`pwd`/${output_dir}.installed
    extra_configure_opts="--prefix=$final_install_dir" # don't install libav to the system
  fi

  extra_configure_opts="$extra_configure_opts --extra-cflags=$CFLAGS --extra-version=COMPILED_BY_JohnWarburton" # extra-cflags is not needed, but adds it to the console output which I lke

  # can't mix and match --enable-static --enable-shared unfortunately, or the final executable seems to just use shared if the're both present
  if [[ $shared == "shared" ]]; then
    output_dir=${output_dir}_shared
    do_git_checkout $git_url ${output_dir}
    final_install_dir=`pwd`/${output_dir}.installed
    extra_configure_opts="--enable-shared --disable-static $extra_configure_opts"
    # avoid installing this to system?
    extra_configure_opts="$extra_configure_opts --prefix=$final_install_dir"
  else
    do_git_checkout $git_url $output_dir
    extra_configure_opts="--enable-shared --disable-static --disable-debug $extra_configure_opts" # --pkg-config-flags=--static
  fi
  cd $output_dir
  
  if [ "$bits_target" = "32" ]; then
   local arch=x86
  else
   local arch=x86_64
  fi

# --extra-cflags=$CFLAGS, though redundant, just so that FFmpeg lists what it used in its "info" output

  config_options="--arch=$arch --target-os=mingw32 --cross-prefix=$cross_prefix --pkg-config=pkg-config --disable-doc --enable-opencl --enable-gpl --enable-libtesseract --enable-libx264 --enable-avisynth --enable-libxvid --enable-libmp3lame --enable-version3 --enable-zlib --enable-librtmp --enable-libvorbis --enable-libtheora --enable-libspeex --enable-libopenjpeg --enable-gnutls --enable-libgsm --enable-libfreetype --enable-libopus --disable-w32threads --enable-frei0r --enable-filter=frei0r --enable-libvo-aacenc --enable-bzlib --enable-libxavs --extra-cflags=-DPTW32_STATIC_LIB --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-libschroedinger --enable-libvpx --enable-libilbc --enable-libwavpack --enable-libwebp --enable-libgme --enable-libdcadec --enable-libbs2b --enable-libmfx --enable-d3d11va --enable-dxva2 --prefix=$mingw_w64_x86_64_prefix $extra_configure_opts --extra-cflags=$CFLAGS" # other possibilities: --enable-w32threads --enable-libflite
  if [[ "$non_free" = "y" ]]; then
    config_options="$config_options --enable-nonfree --enable-libfdk-aac --disable-libfaac --enable-decoder=aac" # To use fdk-aac in VLC, we need to change FFMPEG's default (faac), but I haven't found how to do that... So I disabled it. This could be an new option for the script? -- faac deemed too poor quality and becomes the default -- add it in and uncomment the build_faac line to include it 
    # other possible options: --enable-openssl --enable-libaacplus
  else
    config_options="$config_options"
  fi

  if [[ "$native_build" = "y" ]]; then
    config_options="$config_options --disable-runtime-cpudetect"
    # TODO --cpu=host ... ?
  else
    config_options="$config_options --enable-runtime-cpudetect"
  fi
  # sed -i 's/openjpeg-1.5/openjpeg-2.1/' configure # change library path for updated libopenjpeg
  export PKG_CONFIG="pkg-config" # --static
  export LDFLAGS="" # "-static" 
  do_configure "$config_options"
  unset PKG_CONFIG
  unset LDFLAGS
  rm -f */*.a */*.dll *.exe # just in case some dependency library has changed, force it to re-link even if the ffmpeg source hasn't changed...
  rm already_ran_make*
  echo "doing ffmpeg make $(pwd)"
  do_make "V=1"
  do_make_install "V=1" # install ffmpeg to get libavcodec libraries to be used as dependencies for other things, like vlc [XXX make this a parameter?] or install shared to a local dir

  # build ismindex.exe, too, just for fun 
  make tools/ismindex.exe

  sed -i.bak 's/-lavutil -lm.*/-lavutil -lm -lpthread/' "$PKG_CONFIG_PATH/libavutil.pc" # XXX patch ffmpeg itself
  sed -i.bak 's/-lswresample -lm.*/-lswresample -lm -lsoxr/' "$PKG_CONFIG_PATH/libswresample.pc" # XXX patch ffmpeg
  echo "Done! You will find $bits_target bit $shared binaries in $(pwd)/{ffmpeg,ffprobe,ffplay,avconv,avprobe}*.exe"
  cd ..
}

find_all_build_exes() {
  found=""
# NB that we're currently in the sandbox dir
  for file in `find . -name ffmpeg.exe` `find . -name ffmpeg_g.exe` `find . -name ffplay.exe` `find . -name MP4Box.exe` `find . -name mplayer.exe` `find . -name mencoder.exe` `find . -name avconv.exe` `find . -name avprobe.exe` `find . -name x264.exe` `find . -name writeavidmxf.exe` `find . -name writeaviddv50.exe`; do
    found="$found $(readlink -f $file)"
  done

  # bash glob fails here again?
  for file in `find . -name vlc.exe | grep -- -`; do
    found="$found $(readlink -f $file)"
  done
  echo $found # pseudo return value...
}

build_dependencies() {
  echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH" # debug
  build_win32_pthreads # vpx etc. depend on this--provided by the compiler build script now, so shouldn't have to build our own
  build_libtool
  build_pkg-config # because MPV likes to see a mingw version of pkg-config
  build_iconv # Because Cygwin's iconv is buggy, and loops on certain character set conversions
  build_libdlfcn # ffmpeg's frei0r implentation needs this <sigh>
  build_zlib # rtmp depends on it [as well as ffmpeg's optional but handy --enable-zlib]
  build_bzlib2 # in case someone wants it [ffmpeg uses it]
  build_libpng # for openjpeg, needs zlib
  build_gmp # for libnettle
  build_libnettle # needs gmp
#  build_iconv # mplayer I think needs it for freetype [just it though], vlc also wants it.  looks like ffmpeg can use it too...not sure what for :)
  build_gnutls # needs libnettle, can use iconv it appears
  build_openssl
  # build_gomp   # Not yet.
  build_gavl # Frei0r has this as an optional dependency
  build_libutvideo
  #build_libflite # too big for the ffmpeg distro...
  build_sdl # needed for ffplay to be created
  build_sdl2
  build_libopus
  build_libopencore
  build_libogg
  build_boost # needed for mkv tools
  build_libspeex # needs libogg for exe's
  build_libvorbis # needs libogg
  build_libtheora # needs libvorbis, libogg
  build_orc
  build_libschroedinger # needs orc
  build_regex # needed by ncurses and cddb among others
  build_ncurses
  build_freetype # uses bz2/zlib seemingly
  build_libexpat
  build_libxml2
  build_libxslt
  build_libgpg-error # Needed by libgcrypt 
  build_libgcrypt # Needed by libxmlsec 
  build_libxmlsec
  build_libbluray # needs libxml2, freetype [FFmpeg, VLC use this, at least]
  build_libopenjpeg
  build_libopenjpeg2
  build_libjpeg_turbo # mplayer can use this, VLC qt might need it? [replaces libjpeg],
                      # Place after other jpeg libraries so headers are over-written
  build_libdvdcss
  build_libdvdread # vlc, mplayer use it. needs dvdcss
  build_libdvdnav # vlc, mplayer use this
  build_libtiff
  build_libxvid
  build_libxavs
  build_libsoxr
  build_libx264
  build_libx265
  build_asdcplib
  build_lame
  build_vidstab
  build_libcaca
  build_libmodplug # ffmepg and vlc can use this
  build_zvbi
  # build_libcddb # Circular dependency here!
  build_libcdio
  build_libcdio-paranoia
  build_libcddb # Circular dependency
  build_libvpx
  build_vo_aacenc
  build_libdecklink
  build_liburiparser
  build_libilbc
  build_libmms
  build_flac
  if [[ -d gsm-1.0-pl13 ]]; then # this is a TERRIBLE kludge because sox mustn't see libgsm
    cd gsm-1.0-pl13
    make uninstall
    cd ..
    rm $mingw_w64_x86_64_prefix/lib/libgsm.a # because make uninstall in gsm-1.0-pl13 
                                             # doesn't actually remove the installed library
  fi
  build_libfftw
  build_libsndfile
  build_vamp-sdk
  build_libsamplerate # for librubberband
  build_libbs2b
  build_wavpack
  build_libdcadec
  build_libgame-music-emu
  build_sox # This is a problem: it must be built before libgsm is created otherwise libgsm clashes with libsndfile
  build_libgsm
  build_twolame
  build_fontconfig # needs expat, needs freetype (at least uses it if available), can use iconv, but I believe doesn't currently
  build_libfribidi
  build_libass # needs freetype, needs fribidi, needs fontconfig
  build_intel_quicksync_mfx
  build_opencl
#  build_libopenjpeg
#  build_libopenjpeg2
  build_libwebp
  build_SWFTools
  build_opencv
  build_frei0r
  build_leptonica
  build_tesseract
  if [[ "$non_free" = "y" ]]; then
    build_fdk_aac
    # build_faac # not included for now, too poor quality :)
    # build_libaacplus # if you use it, conflicts with other AAC encoders <sigh>, so disabled :)
  fi
  build_librtmp # needs gnutls [or openssl...] and curl depends on this too
#  build_smake # This is going to be useful one day
  build_lua
  build_ladspa # Not a real build: just copying the API header file into place
  build_librubberband # for mpv
  build_vim
}

build_apps() {
  # now the things that use the dependencies...
#  build_less
#  build_coreutils
  build_opustools
  build_curl # Needed for mediainfo to read Internet streams or file, also can get RTMP streamss
  build_gdb # Really useful, and the correct version for Windows executables
  build_mediainfo
  if [[ $build_libmxf = "y" ]]; then
    build_libMXF
    build_libMXFpp
    build_bmx
  #  build_makemkv
  fi
  if [[ $build_mp4box = "y" ]]; then
    build_mp4box
  fi
  build_exiv2
#  build_cdrecord # NOTE: just now, cdrecord doesn't work on 64-bit mingw. It scans the emulated SCSI bus but no more.
  build_lsdvd
  build_fdkaac-commandline
  build_qt
  build_youtube-dl
# build_qt5
  build_mkvtoolnix
  build_opendcp
#  build_openssh
#  build_dvdbackup
  if [[ $build_ffmpeg_shared = "y" ]]; then
    build_ffmpeg ffmpeg shared
  fi
  if [[ $build_ffmpeg_static = "y" ]]; then
    build_ffmpeg ffmpeg
  fi
  if [[ $build_libav = "y" ]]; then
    build_ffmpeg libav
  fi
  build_ffms2
  build_mpv
  # build_opencv # We place it here because opencv has an interface to FFmpeg
  if [[ $build_vlc = "y" ]]; then
    build_vlc # NB requires ffmpeg static as well, at least once...so put this last :)
  fi
  build_graphicsmagick
#  build_vlc
}

# set some parameters initial values
cur_dir="$(pwd)/sandbox"
top_dir="$(pwd)"
cpu_count="$(grep -c processor /proc/cpuinfo)" # linux
if [ -z "$cpu_count" ]; then
  cpu_count=`sysctl -n hw.ncpu | tr -d '\n'` # OS X
  if [ -z "$cpu_count" ]; then
    echo "warning, unable to determine cpu count, defaulting to 1"
    cpu_count=1 # else default to just 1, instead of blank, which means infinite 
  fi
fi
original_cpu_count=$cpu_count # save it away for some that revert it temporarily
gcc_cpu_count=1 # allow them to specify more than 1, but default to the one that's most compatible...
build_ffmpeg_static=y
build_ffmpeg_shared=n
build_libav=n
build_libmxf=y
build_mp4box=y
build_mplayer=n
build_vlc=n
git_get_latest=y
prefer_stable=n
#disable_nonfree=n # have no value to force prompt
unset CFLAGS # I think this resets it...we don't want any linux CFLAGS seeping through...they can set this via --cflags=  if they want it set to anything
original_cflags= # no export needed, this is just a local copy

# parse command line parameters, if any
while true; do
  case $1 in
    -h | --help ) echo "available options [with defaults]: 
      --build-ffmpeg-shared=n 
      --build-ffmpeg-static=y 
      --gcc-cpu-count=1x [number of cpu cores set it higher than 1 if you have multiple cores and > 1GB RAM, this speeds up cross compiler build. FFmpeg build uses number of cores regardless.] 
      --disable-nonfree=y (set to n to include nonfree like libfdk-aac) 
      --sandbox-ok=n [skip sandbox prompt if y] 
      --rebuild-compilers=y (prompts you which compilers to build, even if you already have some)
      --defaults|-d [skip all prompts, just build ffmpeg static with some reasonable defaults like no git updates] 
      --build-libmxf=n [builds libMXF, libMXF++, writeavidmxfi.exe and writeaviddv50.exe from the BBC-Ingex project] 
      --build-mp4box=n [builds MP4Box.exe from the gpac project] 
      --build-mplayer=n [builds mplayer.exe and mencoder.exe] 
      --build-vlc=n [builds a [rather bloated] vlc.exe] 
      --build-choice=[multi,win32,win64] [default prompt, or skip if you already have one built, multi is both win32 and win64]
      --build-libav=n [builds libav.exe, an FFmpeg fork] 
      --cflags= [default is empty, compiles for generic cpu, see README]
      --git-get-latest=y [do a git pull for latest code from repositories like FFmpeg--can force a rebuild if changes are detected]
      --prefer-stable=y build a few libraries from releases instead of git master
      --high-bitdepth=y Enable high bit depth for x264 (10 bits) and x265 (10 and 12 bits, x64 build. Not officially supported on x86 (win32), but can be enabled by editing x265/source/CMakeLists.txt. See line 155).
       "; exit 0 ;;
    --sandbox-ok=* ) sandbox_ok="${1#*=}"; shift ;;
    --gcc-cpu-count=* ) gcc_cpu_count="${1#*=}"; shift ;;
    --build-libmxf=* ) build_libmxf="${1#*=}"; shift ;;
    --build-mp4box=* ) build_mp4box="${1#*=}"; shift ;;
    --git-get-latest=* ) git_get_latest="${1#*=}"; shift ;;
    --build-mplayer=* ) build_mplayer="${1#*=}"; shift ;;
    --build-libav=* ) build_libav="${1#*=}"; shift ;;
    --cflags=* ) 
       echo "removing old .exe's, in case cflags has changed"
       for file in $(find_all_build_exes); do
         echo "deleting $file in case it isn't rebuilt with new different cflags, which could cause confusion"
         echo "also deleting $(dirname $file)/already_ran_make*"
         rm $(dirname $file)/already_ran_make*
         rm $(dirname $(dirname $file))/already_ran_make* # vlc is packaged somewhere nested 2 deep
         rm $file
       done
       export CFLAGS="${1#*=}"; original_cflags="${1#*=}"; echo "setting cflags as $original_cflags"; shift ;;
    --build-vlc=* ) build_vlc="${1#*=}"; shift ;;
    --disable-nonfree=* ) disable_nonfree="${1#*=}"; shift ;;
    -d         ) gcc_cpu_count=$cpu_count; disable_nonfree="y"; sandbox_ok="y"; build_choice="multi"; git_get_latest="n" ; shift ;;
    --defaults ) gcc_cpu_count=$cpu_count; disable_nonfree="y"; sandbox_ok="y"; build_choice="multi"; git_get_latest="n" ; shift ;;
    --build-choice=* ) build_choice="${1#*=}"; shift ;;
    --build-ffmpeg-static=* ) build_ffmpeg_static="${1#*=}"; shift ;;
    --build-ffmpeg-shared=* ) build_ffmpeg_shared="${1#*=}"; shift ;;
    --rebuild-compilers=* ) rebuild_compilers="${1#*=}"; shift ;;
    --prefer-stable=* ) prefer_stable="${1#*=}"; shift ;;
    --high-bitdepth=* ) high_bitdepth="${1#*=}"; shift ;;
    -- ) shift; break ;;
    -* ) echo "Error, unknown option: '$1'."; exit 1 ;;
    * ) break ;;
  esac
done

intro # remember to always run the intro, since it adjust pwd
check_missing_packages
install_cross_compiler 

export PKG_CONFIG_LIBDIR= # disable pkg-config from reverting back to and finding system installed packages [yikes]


original_path="$PATH"
if [ -d "mingw-w64-i686" ]; then # they installed a 32-bit compiler
  echo "Building 32-bit ffmpeg..."
  host_target='i686-w64-mingw32'
  mingw_w64_x86_64_prefix="$cur_dir/mingw-w64-i686/$host_target"
  export PATH="$cur_dir/mingw-w64-i686/bin:$original_path"
  export PKG_CONFIG_PATH="$cur_dir/mingw-w64-i686/i686-w64-mingw32/lib/pkgconfig"
  bits_target=32
  cross_prefix="$cur_dir/mingw-w64-i686/bin/i686-w64-mingw32-"
  mkdir -p win32
  cd win32
  build_dependencies
  build_apps
  cd ..
fi

if [ -d "mingw-w64-x86_64" ]; then # they installed a 64-bit compiler
  echo "Building 64-bit ffmpeg..."
  host_target='x86_64-w64-mingw32'
  mingw_w64_x86_64_prefix="$cur_dir/mingw-w64-x86_64/$host_target"
  export PATH="$cur_dir/mingw-w64-x86_64/bin:$original_path"
  export PKG_CONFIG_PATH="$cur_dir/mingw-w64-x86_64/x86_64-w64-mingw32/lib/pkgconfig"
  export mingw_compiler_path="$cur_dir/mingw-w64-x86_64"
  mkdir -p x86_64
  bits_target=64
  cross_prefix="$cur_dir/mingw-w64-x86_64/bin/x86_64-w64-mingw32-"
  # Make a link to system pkg-config program because some compiles look for it as a cross-compiler version of pkg-config
  ln -s /usr/bin/pkg-config ${cross_prefix}pkg-config.exe
  cd x86_64
  build_dependencies
  build_apps
  cd ..
fi

echo "Stripping all binaries..."
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/bin/*.exe
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/bin/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/lib/frei0r-1/*.dll
echo "Binaries are stripped. Debugging versions of FFmpeg programs ending _g"
echo "are in build directory."
#echo "searching for some local exes..."
#for file in $(find_all_build_exes); do
#  echo "built $file"
#done
echo "done!"


