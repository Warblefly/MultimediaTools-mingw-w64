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
  local check_packages=('cmp' 'bzip2' 'nvcc' 'rsync' 'sshpass' 'curl' 'pkg-config' 'make' 'gettext' 'git' 'svn' 'cmake' 'gcc' 'autoconf' 'libtool' 'automake' 'yasm' 'cvs' 'flex' 'bison' 'makeinfo' 'g++' 'ed' 'hg' 'patch' 'pax' 'gperf' 'ruby' 'doxygen' 'xsltproc' 'autogen' 'rake' 'autopoint' 'wget' 'zip' 'gtkdocize' 'python-config' 'ant' 'sdl-config' 'sdl2-config' 'gyp' 'mm-common-prepare' 'sassc' 'nasm' 'ragel' 'gengetopt' 'asn1Parser' 'ronn' 'docbook2x-man'  'intltool-update' 'gtk-update-icon-cache' 'gdk-pixbuf-csource' 'interdiff' 'orcc' 'luac' 'makensis' 'swig' 'meson')
  for package in "${check_packages[@]}"; do
    type -P "$package" >/dev/null || missing_packages=("$package" "${missing_packages[@]}")
  done

  if [[ -n "${missing_packages[@]}" ]]; then
    clear
    echo "Could not find the following execs (svn is actually package subversion, autopoint is gettext or gettext-devel, sassc is libsass, makeinfo is actually package texinfo if you're missing them): ${missing_packages[@]}"
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
  if [[ -f "mingw-w64-i686/compiler.done" || -f "x86_64-w64-mingw32/compiler.done" ]]; then
   echo "MinGW-w64 compiler of some type or other already installed, not re-installing..."
   if [[ $rebuild_compilers != "y" ]]; then
     return # early exit, they already have some type of cross compiler built.
   fi
  fi

  if [[ -z $build_choice ]]; then
    pick_compiler_flavors
  fi
  if [[ -f mingw-w64-build ]]; then
    rm mingw-w64-build || exit 1
  fi
#  curl https://raw.githubusercontent.com/Zeranoe/mingw-w64-build/master/mingw-w64-build -O || exit 1
#  chmod u+x mingw-w64-build
#  apply_patch file://${top_dir}/build-mingw-updates.patch
  unset CFLAGS # don't want these for the compiler itself since it creates executables to run on the local box
  # pthreads version to avoid having to use cvs for it
  echo "building cross compile gcc [requires internet access]"
# Quick patch to update mingw to 4.0.4
#  sed -i.bak "s/mingw_w64_release_ver='3.3.0'/mingw_w64_release_ver='4.0.4'/" mingw-w64-build-3.6.6
#  sed -i.bak "s/gcc_release_ver='4.9.2'/gcc_release_ver='7.2.0'/" mingw-w64-build-3.6.6
#  sed -i.bak "s/mpfr_release_ver='3.1.2'/mpfr_release_ver='3.1.5'/" mingw-w64-build-3.6.6
#  sed -i.bak "s/binutils_release_ver='2.25'/binutils_release_ver='2.29'/" mingw-w64-build-3.6.6
#  sed -i.bak "s/cloog_release_ver='0.18.1'/cloog_release_ver='0.18.1'/" mingw-w64-build-3.6.6
#  sed -i.bak "s/isl_release_ver='0.12.2'/isl_release_ver='0.18'/" mingw-w64-build-3.6.6
#  sed -i.bak "s/gmp_release_ver='6.0.0a'/gmp_release_ver='6.1.2'/" mingw-w64-build-3.6.6
#  sed -i.bak "s/gmp-6\.0\.0/gmp-6.1.2/" mingw-w64-build-3.6.6
#  sed -i.bak "s/--enable-lto/--enable-lto --enable-libgomp/" mingw-w64-build-3.6.6
#  sed -i.bak "s!//gcc\.gnu\.org/svn/gcc/trunk!//gcc.gnu.org/svn/gcc/branches/gcc-7-branch!" mingw-w64-build-3.6.6
#  apply_patch file://${top_dir}/mingw-w64-build-isl_fix.patch
#  apply_patch file://${top_dir}/mingw-w64-build-gcc.patch
#  sed -i.bak "s|ln -s '../include' './include'|mkdir include|" mingw-w64-build-3.6.6
#  sed -i.bak "s|ln -s '../lib' './lib'|mkdir lib|" mingw-w64-build-3.6.6
#  sed -i.bak "s/--enable-threads=win32/--enable-threads=posix/" mingw-w64-build-3.6.6
# Gendef compilation throws a char-as-array-index error when invoked with "--target=" : "--host" avoids this.
#  sed -i.bak 's#gendef/configure" --build="$system_type" --prefix="$mingw_w64_prefix" --target#gendef/configure" --build="$system_type" --prefix="$mingw_w64_prefix" --host#' mingw-w64-build-3.6.6
#  ./mingw-w64-build-3.6.6 --gcc-langs=c,c++,fortran --default-configure --mingw-w64-ver=git --gcc-ver=svn --pthreads-w32-ver=2-9-1 --cpu-count=$gcc_cpu_count --build-type=$build_choice --enable-gendef --enable-widl --binutils-ver=2.29 --verbose || exit 1 # --disable-shared allows c++ to be distributed at all...which seemed necessary for some random dependency...
#  ./mingw-w64-build x86_64
  ${top_dir}/toolchain.sh
  #mv bld ${top_dir}/sandbox/x86_64-w64-mingw32
  export CFLAGS=$original_cflags # reset it
# We need to move the plain cross-compiling versions of bintools out of the way
# because exactly the same binaries exist with the host triplet prefix
#  rm ${mingw_w64_x86_64_prefix}/bin/objdump ${mingw_w64_x86_64_prefix}/bin/ar ${mingw_w64_x86_64_prefix}/bin/ranlib ${mingw_w64_x86_64_prefix}/bin/objcopy ${mingw_w64_x86_64_prefix}/bin/dlltool ${mingw_w64_x86_64_prefix}/bin/nm ${mingw_w64_x86_64_prefix}/bin/strip ${mingw_w64_x86_64_prefix}/bin/as ${mingw_w64_x86_64_prefix}/bin/ld.bfd ${mingw_w64_x86_64_prefix}/bin/ld
  # A couple of multimedia-related files need cases changing because of QT5 includes
  cd x86_64-w64-mingw32/x86_64-w64-mingw32/include
    ln -s evr9.h Evr9.h
    ln -s mferror.h Mferror.h
#    cp -v ${top_dir}/dxgi*.h .
#    apply_patch file://${top_dir}/d3d11.h.patch
    apply_patch file://${top_dir}/cfgmgr32.h.patch
    apply_patch file://${top_dir}/devpkey.h.patch
#    apply_patch file://${top_dir}/sal.h.patch
#    apply_patch file://${top_dir}/dxgitype-missing.patch
#     cp -v ${top_dir}/dxgi1_3.h .
#     apply_patch file://${top_dir}/dxgi1_3.h.patch
#     cp -v ${top_dir}/dxgi1_6.h .
#     cp -v ${top_dir}/dxgi1_4.h .
# This is needed for vlc, and is still missing in trunk mingw-w64
#    apply_patch file://${top_dir}/mingw-w64-headers-processor_format.patch
  cd ../../..
  if [ -d x86_64-w64-mingw32 ]; then
    touch x86_64-w64-mingw32/compiler.done
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
     rm -v `find ./ -name "already*"`
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
  local configure_env="$3"
  local configure_noclean=""
  if [[ "$configure_name" = "" ]]; then
    configure_name="./configure"
  fi
  local cur_dir2=$(pwd)
  local english_name=$(basename $cur_dir2)
  local touch_name=$(get_small_touchfile_name already_configured "$configure_options $configure_name $LDFLAGS $CFLAGS")
  if [ ! -f "$touch_name" ]; then
    if [ "$configure_noclean" != "noclean" ]; then
      make clean # just in case
    fi
    #make uninstall # does weird things when run under ffmpeg src
    if [ ! -f ${configure_name} ]; then
      if [ -f bootstrap.sh ]; then
        ./bootstrap.sh
      elif [ -f bootstrap ]; then
        ./bootstrap
      elif [ -f autogen.sh ]; then
        ./autogen.sh
      elif [ -f autogen ]; then
        ./autogen
      else
        autoreconf -fvi
      fi
    fi
    rm -f already_* # reset
    echo "configuring $english_name ($PWD) as $ PATH=$PATH ${configure_env} $configure_name $configure_options"
    "$configure_name" $configure_options || exit 1
    touch -- "$touch_name"
    make clean # just in case
  else
    echo "already configured $(basename $cur_dir2)"
  fi
}

do_meson() {
    local configure_options="$1"
    local configure_name="$2"
    local configure_env="$3"
    local configure_noclean=""
    if [[ "$configure_name" = "" ]]; then
        configure_name="meson"
    fi
    local cur_dir2=$(pwd)
    local english_name=$(basename $cur_dir2)
    local touch_name=$(get_small_touchfile_name already_built "$configure_options $configure_name $LDFLAGS $CFLAGS")
    if [ ! -f "$touch_name" ]; then
        if [ "$configure_noclean" != "noclean" ]; then
            make clean # just in case
        fi
        rm -f already_* # reset
        echo "Using meson: $english_name ($PWD) as $ PATH=$PATH ${configure_env} $configure_name $configure_options"
        #env
        ${configure_env} "$configure_name" $configure_options || exit 1
        touch -- "$touch_name"
        make clean # just in case
    else
        echo "Already used meson $(basename $cur_dir2)"
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
    make $extra_make_options || exit 1
    touch $touch_name || exit 1 # only touch if the build was OK
  else
    echo "already did make $(basename "$cur_dir2")"
  fi
}

do_make_clean() {
  local extra_make_options="$1 -j $cpu_count"
  local cur_dir2=$(pwd)
  local touch_name=$(get_small_touchfile_name already_ran_make_clean "$extra_make_options")

  if [ ! -f $touch_name ]; then
    echo
    echo "making clean $cur_dir2 as $ PATH=$PATH make clean $extra_make_options"
    echo
    make $extra_make_options clean || exit 1
    touch $touch_name || exit 1
  else
    echo "already did make clean $(basename "$cur_dir2")"
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
    rake $extra_make_options || exit 1
    touch $touch_name || exit 1 # only touch if the build was OK
  else
    echo "already did make $(basename "$cur_dir2")"
  fi
}

do_drake() {
  local extra_make_options="$1 -j $cpu_count"
  local cur_dir2=$(pwd)
  local touch_name=$(get_small_touchfile_name already_ran_drake "$extra_make_options")

  if [ ! -f $touch_name ]; then
    echo
    echo "draking $cur_dir2 as $ PATH=$PATH drake $extra_make_options"
    echo
    drake $extra_make_options || exit 1
    touch $touch_name || exit 1 # only touch if the build was OK
  else
    echo "already did drake $(basename "$cur_dir2")"
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
    ${mingw_w64_x86_64_prefix}/../bin/smake $extra_make_options || exit 1
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
    make install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}

do_smake_install() {
  local extra_make_options="$1"
  do_smake "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "smake installing $cur_dir2 as $ PATH=$PATH smake install $extra_make_options"
    ${mingw_w64_x86_64_prefix}/../bin/smake install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}


do_cmake() {
  extra_args=$1
  source_dir=$2
  local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")

  if [ ! -f $touch_name ]; then
    local cur_dir2=$(pwd)
    export CMAKE_INCLUDE_PATH="$mingw_w64_x86_64_prefix/include"
    export CMAKE_PREFIX_PATH="$mingw_w64_x86_64_prefix"
    orig_PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"
    export PKG_CONFIG_PATH="${mingw_w64_x86_64_prefix}/lib/pkgconfig"
    export PKG_CONFIG_LIBDIR="${mingw_w64_x86_64_prefix}/lib/pkgconfig"
    echo doing cmake in $cur_dir2 with PATH=$PATH  with extra_args=$extra_args like this:
    echo cmake $source_dir $extra_args -DBUILD_SHARED_LIBS=1 -DBUILD_STATIC_LIBS=0 -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_Fortran_COMPILER:FILEPATH=${cross_prefix}gfortran -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix || exit 1
    cmake $source_dir $extra_args -DBUILD_SHARED_LIBS=1 -DBUILD_STATIC_LIBS=0 -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix || exit 1
    touch $touch_name || exit 1
    unset CMAKE_INCLUDE_PATH
    unset CMAKE_PREFIX_PATH
  fi
}

do_cmake_static() {
   extra_args=$1
   source_dir=$2
   local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")

   if [ ! -f $touch_name ]; then
     local cur_dir2=$(pwd)
     export CMAKE_INCLUDE_PATH="$mingw_w64_x86_64_prefix/include"
     export CMAKE_PREFIX_PATH="$mingw_w64_x86_64_prefix"
     echo doing cmake in $cur_dir2 with PATH=$PATH  with extra_args=$extra_args like this:
     echo cmake $source_dir $extra_args -DBUILD_SHARED_LIBS=0 -DBUILD_STATIC_LIBS=1 -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_Fortran_COMPILER:FILEPATH=${cross_prefix}gfortran -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix || exit 1
     cmake $source_dir $extra_args -DBUILD_SHARED_LIBS=0 -DBUILD_STATIC_LIBS=1 -DENABLE_STATIC_RUNTIME=1 -DENABLE_SHARED_RUNTIME=0 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix || exit 1
     touch $touch_name || exit 1
   fi
 }


apply_patch() {
 local url=$1
 local patch_name=$(basename $url)
 local patch_reverted_name="$patch_name.reverted"
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
   rm -v $patch_reverted_name
   rm already_ran* # if it's a new patch, reset everything too, in case it's really really really new
 else
   echo "patch $patch_name already applied"
 fi
}

revert_patch() {
 local url=$1
 local patch_name=$(basename $url)
 local patch_reverted_name="$patch_name.reverted"
 local patch_done_name="$patch_name.done"
 if [[ ! -e $patch_reverted_name ]]; then
   if [[ -f $patch_name ]]; then
    rm $patch_name || exit 1
   fi
   curl $url -O || exit 1
   echo "reverting patch $patch_name"
   cat $patch_name
   patch -p0 -R < "$patch_name" || exit 1
   touch $patch_reverted_name || exit 1
   rm -v $patch_done_name || exit 1
   rm already_ran* # if it's a new patch, reset everything too, in case it's really really really new
 else
   echo "patch $patch_name already reverted"
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
    tar --keep-directory-symlink -xvf "$output_name" || unzip "$output_name" || exit 1
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

generic_meson() {
    local extra_configure_options="$1"
    mkdir -pv build
    do_meson "--prefix=${mingw_w64_x86_64_prefix} --libdir=${mingw_w64_x86_64_prefix}/lib --buildtype release --strip --default-library shared --cross-file ${top_dir}/meson-cross.mingw.txt $extra_configure_options . build"
}

generic_configure() {
  local extra_configure_options="$1"
#  do_configure "--host=$host_target --prefix=$mingw_w64_x86_64_prefix --disable-shared --enable-static $extra_configure_options"
  do_configure "--host=$host_target --prefix=$mingw_w64_x86_64_prefix --enable-shared --disable-static $extra_configure_options"
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

generic_configure_drake_install() {
  generic_configure "$1"
  do_drake_and_drake_install
}

generic_meson_ninja_install() {
    generic_meson "$1"
    do_ninja_and_ninja_install
}

do_ninja_and_ninja_install() {
    local extra_ninja_options="$1"
    do_ninja "$extra_ninja_options"
    local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_ninja_options")
    if [ ! -f $touch_name ]; then
        echo "ninja installing $(pwd) as $ PATH=$PATH ninja -C build install $extra_make_options"
        ninja -C build install || exit 1
        touch $touch_name || exit 1
    fi
}


do_ninja() {
       local extra_make_options=" -j $cpu_count"
       local cur_dir2=$(pwd)
       local touch_name=$(get_small_touchfile_name already_ran_make "${extra_make_options}")

       if [ ! -f $touch_name ]; then
          echo
          echo "ninja-ing $cur_dir2 as $ PATH=$PATH ninja -C build "${extra_make_options}"
          echo
          ninja -C build "${extra_make_options} || exit 1
          touch $touch_name || exit 1 # only touch if the build was OK
       else
          echo "already did ninja $(basename "$cur_dir2")"
       fi
}

do_make_and_make_install() {
  local extra_make_options="$1"
  do_make "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "make installing $(pwd) as $ PATH=$PATH make install $extra_make_options"
    make install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}

do_rake_and_rake_install() {
  local extra_make_options="$1"
  do_rake "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_make_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "rake installing $(pwd) as $ PATH=$PATH rake install $extra_make_options"
    rake install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}

do_drake_and_drake_install() {
  local extra_make_options="$1"
  do_drake "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_drake_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "drake installing $(pwd) as $ PATH=$PATH drake install $extra_make_options"
    drake install $extra_make_options || exit 1
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
    echo cmake –G”Unix Makefiles” . -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args
    cmake –G”Unix Makefiles” . -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
    touch $touch_name || exit 1
  fi
  do_make_and_make_install
}

do_cleanup() {
# Removes all files in, and under, directory except those which
# prevent re-making
  echo "Running do_cleanup in $(pwd)..."
  find . !  \( -name 'already_*' -o -name 'unpacked.successfully' -o -name '*patch.done' \) -type f -exec rm -rf {} +
}

build_libx265() {
  do_git_checkout https://github.com/videolan/x265.git x265 #1388601db0d23f8d8c3259886e9fcb747c1d5b52
  cd x265
    apply_patch file://${top_dir}/x265-CMakeVersion.patch
#    apply_patch file://${top_dir}/x265-headers-revert.patch
  cd ..
  cd x265/source
    local cmake_params="-DENABLE_SHARED=ON -DENABLE_STATIC=OFF -DENABLE_HDR10_PLUS=ON -DENABLE_ASSEMBLY=ON -DHIGH_BIT_DEPTH=1 -DCMAKE_C_FLAGS=-fpermissive -DCMAKE_CXX_FLAGS=-fpermissive"
    #if [[ $high_bitdepth == "y" ]]; then
    #  cmake_params="$cmake_params -DHIGH_BIT_DEPTH=ON -DMAIN12=ON" # Enable 10 bits (main10) and 12 bits (???) per pixels profiles.
    #  if grep "DHIGH_BIT_DEPTH=0" CMakeFiles/cli.dir/flags.make; then
    #    rm already_ran_cmake_* #Last build was not high bitdepth. Forcing rebuild.
    #  fi
    #else
    #  if grep "DHIGH_BIT_DEPTH=1" CMakeFiles/cli.dir/flags.make; then
    #    rm already_ran_cmake_* #Last build was high bitdepth. Forcing rebuild.
    #  fi
    #fi
#  apply_patch_p1 file://${top_dir}/x265-missing-bool.patch
  # Fixed by x265 developers now
    do_cmake "$cmake_params"
  # x265 seems to fail on parallel builds
#    export cpu_count=1
    do_make_install

#    export cpu_count=$original_cpu_count
  cd ../..
  # We must remove the x265.exe executable because FFmpeg gets linked against it. I do not understand this.
  # Furthermore, this makes x265.exe as an executable completely unuseable.
#  cp -v ${mingw_w64_x86_64_prefix}/bin/libx265.dll ${mingw_w64_x86_64_prefix}/bin/x265.exe
}

#x264_profile_guided=y

build_libx264() {
  do_git_checkout https://github.com/mirror/x264.git x264
  cd x264
  local configure_flags="--host=$host_target --disable-static --enable-shared --cross-prefix=$cross_prefix --prefix=$mingw_w64_x86_64_prefix --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac --bit-depths=all --chroma-format=all" # --enable-win32thread --enable-debug shouldn't hurt us since ffmpeg strips it anyway I think

#  if [[ $high_bitdepth == "y" ]]; then
#    configure_flags="$configure_flags --bit-depth=10" # Enable 10 bits (main10) per pixels profile.
#    if grep -q "HIGH_BIT_DEPTH 0" config.h; then
#      rm already_configured_* #Last build was not high bitdepth. Forcing reconfigure.
#    fi
#  else
#    if grep -q "HIGH_BIT_DEPTH 1" config.h; then
#      rm already_configured_* #Last build was high bitdepth. Forcing reconfigure.
#    fi
#  fi

#  if [[ $x264_profile_guided = y ]]; then
    # TODO more march=native here?
    # TODO profile guided here option, with wine?
#    do_configure "$configure_flags"
#    curl http://samples.mplayerhq.hu/yuv4mpeg2/example.y4m.bz2 -O || exit 1
#    rm example.y4m # in case it exists already...
#    bunzip2 example.y4m.bz2 || exit 1
    # XXX does this kill git updates? maybe a more general fix, since vid.stab does also?
#    sed -i.bak "s_\\, ./x264_, wine ./x264_" Makefile # in case they have wine auto-run disabled http://askubuntu.com/questions/344088/how-to-ensure-wine-does-not-auto-run-exe-files
#    do_make_install "fprofiled VIDS=example.y4m" # guess it has its own make fprofiled, so we don't need to manually add -fprofile-generate here...

#  else
  do_configure "$configure_flags"
  do_make_install

#  fi
  cd ..
}

build_librtmp() {
  #  download_and_unpack_file http://rtmpdump.mplayerhq.hu/download/rtmpdump-2.3.tgz rtmpdump-2.3 # has some odd configure failure
  #  cd rtmpdump-2.3/librtmp

  do_git_checkout git://git.ffmpeg.org/rtmpdump rtmpdump # 883c33489403ed360a01d1a47ec76d476525b49e # trunk didn't build once...this one i sstable
  cd rtmpdump
    sed -i.bak 's/SYS=posix/SYS=mingw/' Makefile
    sed -i.bak 's/SYS=posix/SYS=mingw/' librtmp/Makefile
    cd librtmp
      do_make_install "CRYPTO=GNUTLS OPT=-O2 CROSS_COMPILE=$cross_prefix SHARED=yes prefix=$mingw_w64_x86_64_prefix SYS=mingw"
      #make install CRYPTO=GNUTLS OPT='-O2 -g' "CROSS_COMPILE=$cross_prefix" SHARED=no "prefix=$mingw_w64_x86_64_prefix" || exit 1
      sed -i.bak 's/-lrtmp -lz/-lrtmp -lwinmm -lz/' "$PKG_CONFIG_PATH/librtmp.pc"
    cd ..
   # TODO do_make here instead...
    make SYS=mingw CRYPTO=GNUTLS OPT=-O2 CROSS_COMPILE=$cross_prefix SHARED=yes LIB_GNUTLS="`pkg-config --libs gnutls` -lz" || exit 1
   # The makefile doesn't install
    cp -fv rtmpdump.exe rtmpgw.exe rtmpsrv.exe rtmpsuck.exe "${mingw_w64_x86_64_prefix}/bin"

  cd ..
}

build_pthread_stubs() {
    do_git_checkout git://anongit.freedesktop.org/xcb/pthread-stubs pthread-stubs
    cd pthread-stubs
        generic_configure_make_install
    cd ..
}

build_drm() {
    do_git_checkout git://anongit.freedesktop.org/mesa/drm drm
    cd drm
        generic_configure_make_install
    cd ..
}


build_qt() {
  export QT_VERSION="5.13.1"
  export QT_SOURCE="qt-source"
  export QT_BUILD="qt-build"
#  orig_cpu_count=$cpu_count
#  export cpu_count=1
  if [ ! -f qt.built ]; then
    download_and_unpack_file http://download.qt.io/official_releases/qt/5.13/5.13.1/single/qt-everywhere-src-5.13.1.tar.xz "qt-everywhere-src-${QT_VERSION}"
    cd "qt-everywhere-src-${QT_VERSION}"
#      apply_patch file://${top_dir}/qt-permissive.patch
    apply_patch file://${top_dir}/qt5-skip-mapboxglnative.patch
    apply_patch file://${top_dir}/qt-pkg-config.patch
    apply_patch file://${top_dir}/qt-include.patch
    apply_patch file://${top_dir}/qt-evrdefs.patch
    # Change a type for updates in ANGLE project
    grep -rl "EGL_PLATFORM_ANGLE_DEVICE_TYPE_WARP_ANGLE" ./ | xargs sed -i.bak 's/EGL_PLATFORM_ANGLE_DEVICE_TYPE_WARP_ANGLE/EGL_PLATFORM_ANGLE_DEVICE_TYPE_D3D_WARP_ANGLE/g'
    cd ..
    mkdir -p "${QT_BUILD}"
    ln -vs "qt-everywhere-src-${QT_VERSION}" "${QT_SOURCE}"
    cd "${QT_SOURCE}"
      echo "QMAKE_LINK_OBJECT_MAX = 10" >> qtbase/mkspecs/win32-g++/qmake.conf
      echo "QMAKE_LINK_OBJECT_SCRIPT = object_script" >> qtbase/mkspecs/win32-g++/qmake.conf
    cd ..
    cd "${QT_BUILD}"
      export PKG_CONFIG=${mingw_w64_x86_64_prefix}/../bin/x86_64-w64-mingw32-pkg-config
      export PKG_CONFIG_LIBDIR=${mingw_w64_x86_64_prefix}/lib/pkgconfig
      export PKG_CONFIG_SYSROOT_DIR=${mingw_w64_x86_64_prefix}/
      do_configure "-xplatform win32-g++ -prefix ${mingw_w64_x86_64_prefix} -hostprefix ${mingw_w64_x86_64_prefix}/../ -opensource  -qt-freetype -confirm-license -accessibility -nomake examples -nomake tests -skip qtwebglplugin -release -strip -openssl -opengl dynamic -device-option CROSS_COMPILE=$cross_prefix -force-pkg-config -device-option PKG_CONFIG=x86_64-w64-mingw32-pkg-config -device-option PKG_CONFIG_LIBDIR=${mingw_w64_x86_64_prefix}/lib/pkgconfig -device-option PKG_CONFIG_SYSROOT_DIR=${mingw_w64_x86_64_prefix} -pkg-config -webengine-proprietary-codecs -no-static -shared -no-use-gold-linker -D MINGW_HAS_SECURE_API -D _WIN32_IE=0x0A00 -v -skip qtactiveqt" "../qt-everywhere-src-${QT_VERSION}/configure" # "noclean" # -skip qtactiveqt
      # For sone reason, the compiler doesn't set the include path properly!
      do_make || exit 1
      do_make_install || exit 1
    cd ..
    # Qt, when building only the release libraries, retains pkgconfig files that refer to
    # the debug libraries. We have not build the debug libraries. These references must
    # therefore be changed to point to the release libraries.
    /usr/bin/python3 ${top_dir}/fix-Qt-non-debug.py ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    touch "qt.built"
#    rm -rf $QT_SOURCE $QT_BUILD
    # QT's build tree takes up over 24GB of space. We don't need to see this again because
    # we're not using a frequently-updated Git version
#    echo "Removing QT-${QT_VERSION} build tree..."
#    rm -rf ${QT_BUILD}
#    echo "QT-${QT_VERSION} build tree now removed."
      # The Qt libraries are sometimes searched for in the wrong place. So let's copythem
      # to where they're sometimes expected
  else

    echo "Skipping QT build... already completed."
    # Remove the debug versions of libQt5 libraries
    rm -v ${mingw_w64_x86_64_prefix}/bin/Qt5*d.dll
  fi
  ln -sv ${mingw_w64_x86_64_prefix}/include/QtCore/5.12.3/QtCore/private ${mingw_w64_x86_64_prefix}/include/QtCore/private
  ln -sv ${mingw_w64_x86_64_prefix}/bin/Qt*.dll ${mingw_w64_x86_64_prefix}/../bin
  ln -sv ${mingw_w64_x86_64_prefix}/plugins ${mingw_w64_x86_64_prefix}/../plugins
  sed -i.bak 's! /libQt5Core\.a! -lQt5Core!' ${mingw_w64_x86_64_prefix}/lib/qtmain.prl
  unset QT_VERSION
  unset QT_SOURCE
  unset QT_BUILD
#  export cpu_count=$orig_cpu_count
  unset PKG_CONFIG
}

build_kf5_config() {
    download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kconfig-5.46.0.tar.xz kconfig-5.46.0
    cd kconfig-5.46.0
        do_cmake
        ${top_dir}/correct_headers.sh
        do_make
        do_make_install
    cd ..
}

build_kf5_coreaddons() {
    download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kcoreaddons-5.46.0.tar.xz kcoreaddons-5.46.0
    cd kcoreaddons-5.46.0
        do_cmake
        ${top_dir}/correct_headers.sh
        do_make
        do_make_install
    cd ..
}

build_libaec() {
	do_git_checkout https://github.com/erget/libaec.git libaec
	cd libaec
		do_cmake
		do_make
		do_make_install
	cd ..
}

build_gctpc() {
	download_and_unpack_file ftp://ftp.fau.de/macports/distfiles/gctpc/gctpc20.tar.Z gctpc
	cd gctpc/source
		apply_patch file://${top_dir}/gctpc-makefile.patch
		export cpu_count=1
		do_make 
		cp geolib.a ${mingw_w64_x86_64_prefix}/lib/libgeo.a
		cp proj.h ${mingw_w64_x86_64_prefix}/include/proj.h
		export cpu_count=8
	cd ../..
}

build_wgrib2() {
	download_and_unpack_file ftp://ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/wgrib2_nolib.tgz.v2.0.8 grib2
	cd grib2
		apply_patch file://${top_dir}/grib2-makefile.patch
		cp ${mingw_w64_x86_64_prefix}/include/proj.h wgrib2/proj.h
		do_make
		cp wgrib2/wgrib2.exe ${mingw_w64_x86_64_prefix}/bin
	cd ..
}

build_kf5_itemmodels() {
     download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kitemmodels-5.46.0.tar.xz kitemmodels-5.46.0
     cd kitemmodels-5.46.0
         do_cmake
         ${top_dir}/correct_headers.sh
         do_make
         do_make_install
     cd ..
 }

build_kf5_itemviews() {
	download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kitemviews-5.46.0.tar.xz kitemviews-5.46.0
        cd kitemviews-5.46.0
            do_cmake
            ${top_dir}/correct_headers.sh
            do_make
            do_make_install
        cd ..
}

build_kf5_codecs() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kcodecs-5.46.0.tar.xz kcodecs-5.46.0
          cd kcodecs-5.46.0
              do_cmake
              ${top_dir}/correct_headers.sh
              do_make
              do_make_install
          cd ..
}


build_kf5_guiaddons() {
       download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kguiaddons-5.46.0.tar.xz kguiaddons-5.46.0
           cd kguiaddons-5.46.0
               do_cmake
               ${top_dir}/correct_headers.sh
               do_make
               do_make_install
           cd ..
}

build_kf5_i18n() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/ki18n-5.46.0.tar.xz ki18n-5.46.0
          cd ki18n-5.46.0
              do_cmake
              ${top_dir}/correct_headers.sh
              do_make
              do_make_install
          cd ..
}

build_kf5_widgetsaddons() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kwidgetsaddons-5.46.0.tar.xz kwidgetsaddons-5.46.0
          cd kwidgetsaddons-5.46.0
              do_cmake
              ${top_dir}/correct_headers.sh
              do_make
              do_make_install
          cd ..
}

build_kf5_configwidgets() {
     download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kconfigwidgets-5.46.0.tar.xz kconfigwidgets-5.46.0
         cd kconfigwidgets-5.46.0
             apply_patch file://${top_dir}/kconfigwidgets-cross.patch
             do_cmake
             ${top_dir}/correct_headers.sh
             do_make
             do_make_install
         cd ..
}

build_kf5_auth() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kauth-5.46.0.tar.xz kauth-5.46.0
          cd kauth-5.46.0
              do_cmake
              ${top_dir}/correct_headers.sh
              do_make
              do_make_install
          cd ..
 }

build_kf5_archive() {
        download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/karchive-5.46.0.tar.xz karchive-5.46.0
            cd karchive-5.46.0
                do_cmake
                ${top_dir}/correct_headers.sh
                do_make
                do_make_install
            cd ..
 }

build_kf5_iconthemes() {
       download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kiconthemes-5.46.0.tar.xz kiconthemes-5.46.0
           cd kiconthemes-5.46.0
               do_cmake
               ${top_dir}/correct_headers.sh
               do_make
               do_make_install
           cd ..
}

build_kf5_completion() {
     download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kcompletion-5.46.0.tar.xz kcompletion-5.46.0
     cd kcompletion-5.46.0
         do_cmake
         ${top_dir}/correct_headers.sh
         do_make
         do_make_install
     cd ..
}

build_kf5_windowsystem() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kwindowsystem-5.46.0.tar.xz kwindowsystem-5.46.0
      cd kwindowsystem-5.46.0
          do_cmake
          ${top_dir}/correct_headers.sh
          do_make
          do_make_install
      cd ..
}

build_kf5_crash() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kcrash-5.46.0.tar.xz kcrash-5.46.0
      cd kcrash-5.46.0
          do_cmake
          ${top_dir}/correct_headers.sh
          do_make
          do_make_install
      cd ..
}

build_kf5_dbusaddons() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kdbusaddons-5.46.0.tar.xz kdbusaddons-5.46.0
      cd kdbusaddons-5.46.0
          do_cmake
          ${top_dir}/correct_headers.sh
          do_make
          do_make_install
      cd ..
}

build_kf5_service() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kservice-5.46.0.tar.xz kservice-5.46.0
      cd kservice-5.46.0
          do_cmake "-DBUILD_TESTING=OFF"
          ${top_dir}/correct_headers.sh
          do_make
          do_make_install
      cd ..
}

build_kf5_sonnet() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/sonnet-5.46.0.tar.xz sonnet-5.46.0
      cd sonnet-5.46.0
          do_cmake
          ${top_dir}/correct_headers.sh
          do_make
          do_make_install
      cd ..
}

build_kf5_textwidgets() {
     download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/ktextwidgets-5.46.0.tar.xz ktextwidgets-5.46.0
     cd ktextwidgets-5.46.0
         do_cmake
         ${top_dir}/correct_headers.sh
         do_make
         do_make_install
     cd ..
}

build_kf5_attica() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/attica-5.46.0.tar.xz attica-5.46.0
      cd attica-5.46.0
          do_cmake
          ${top_dir}/correct_headers.sh
          do_make
          do_make_install
      cd ..
}

build_kf5_globalaccel() {
       download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kglobalaccel-5.46.0.tar.xz kglobalaccel-5.46.0
       cd kglobalaccel-5.46.0
           do_cmake
           ${top_dir}/correct_headers.sh
           do_make
           do_make_install
       cd ..
 }

build_kf5_xmlgui() {
    download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/kxmlgui-5.46.0.tar.xz kxmlgui-5.46.0
    cd kxmlgui-5.46.0
        #apply_patch file://${top_dir}/kxmlgui-header.patch
        do_cmake # "-DCMAKE_INCLUDE_PATH=${mingw_w64_x86_64_prefix}/include/QtCore/5.10.1 -DCMAKE_VERBOSE_MAKEFILE=1"
        ${top_dir}/correct_headers.sh
        do_make "V=1"
        do_make_install
    cd ..
}

build_kf5_solid() {
     download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/solid-5.46.0.tar.xz solid-5.46.0
     cd solid-5.46.0
         do_cmake
         ${top_dir}/correct_headers.sh
         do_make "V=1"
         do_make_install
     cd ..
}

build_kf5_threadweaver() {
      download_and_unpack_file https://download.kde.org/stable/frameworks/5.46/threadweaver-5.46.0.tar.xz threadweaver-5.46.0
      cd threadweaver-5.46.0
          do_cmake
          ${top_dir}/correct_headers.sh
          do_make "V=1"
          do_make_install
      cd ..
}

build_digikam() {
	do_git_checkout git://anongit.kde.org/digikam.git digikam
    cd digikam
      do_cmake "-DENABLE_QWEBENGINE:BOOL=ON -DDIGIKAMSC_COMPILE_PO=OFF -DDIGIKAMSC_COMPILE_DOC=OFF"
	cd ..
}

#build_qt() {
## This is quite a minimal installation to try to shorten a VERY long compile.
## It's needed for OpenDCP and may well be extended to other programs later.
#  unset CFLAGS
#  download_and_unpack_file http://download.qt.io/archive/qt/4.8/4.8.6/qt-everywhere-opensource-src-4.8.6.tar.gz qt-everywhere-opensource-src-4.8.6
#  cd qt-everywhere-opensource-src-4.8.6
#    apply_patch_p1 file://${top_dir}/qplatformdefs.h.patch
#    apply_patch_p1 file://${top_dir}/qfiledialog.cpp.patch
#    # vlc's configure options...mostly
##    do_configure "-static -release -fast -no-exceptions -no-stl -no-sql-sqlite -no-qt3support -no-gif -no-libmng -qt-libjpeg -no-libtiff -no-qdbus -no-openssl -no-webkit -sse -no-script -no-multimedia -no-phonon -opensource -no-scripttools -no-opengl -no-script -no-scripttools -no-declarative -no-declarative-debug -opensource -no-s60 -host-little-endian -confirm-license -xplatform win32-g++ -device-option CROSS_COMPILE=$cross_prefix -prefix $mingw_w64_x86_64_prefix -prefix-install -nomake examples"
#    do_configure "-release -static -no-exceptions -no-sql-sqlite -no-scripttools -no-script -no-accessibility -no-qt3support -no-multimedia -no-audio-backend -no-phonon -no-phonon-backend -no-declarative -no-declarative-debug -no-s60 -host-little-endian -no-webkit -xplatform win32-g++ -no-cups -no-dbus -nomake tests -nomake docs -nomake tools -opensource -confirm-license -nomake demos -nomake examples -no-libmng -device-option CROSS_COMPILE=$cross_prefix -prefix $mingw_w64_x86_64_prefix -prefix-install"
#    if [ ! -f 'already_qt_maked_k' ]; then
#      do_make # sub-src might make the build faster? # complains on mng? huh?
#      do_make_install
#      touch 'already_qt_maked_k'
#    fi
#    # vlc needs an adjust .pc file? huh wuh?
##    sed -i.bak 's/Libs: -L${libdir} -lQtGui/Libs: -L${libdir} -lcomctl32 -lqjpeg -lqtaccessiblewidgets -lQtGui/' "$PKG_CONFIG_PATH/QtGui.pc" # sniff
#  cd ..
#  export CFLAGS=$original_cflags
#}

build_libsoxr() {
  #download_and_unpack_file http://sourceforge.net/projects/soxr/files/soxr-0.1.1-Source.tar.xz soxr-0.1.1-Source # not /download since apparently some tar's can't untar it without an extension?
  do_git_checkout git://git.code.sf.net/p/soxr/code "soxr-code"
  cd soxr-code
    do_cmake "-DHAVE_WORDS_BIGENDIAN_EXITCODE=0  -DBUILD_SHARED_LIBS:bool=on -DBUILD_STATIC_LIBS:bool=off -DBUILD_TESTS:BOOL=OFF"
    do_make_install

  cd ..
}

build_googletest() {
  do_git_checkout https://github.com/google/googletest.git googletest
  cd googletest
    do_cmake "-DBUILD_SHARED_LIBS=ON"
    do_make_install
    # Must leave this behind. movit needs to see the source.
    # do_make_clean
  cd ..
}

build_mlt() {
  do_git_checkout https://github.com/mltframework/mlt.git mlt # 18b8609
  cd mlt
#    apply_patch file://${top_dir}/mlt-mingw-sandbox.patch
    export CXX=x86_64-w64-mingw32-g++
    export CROSS=x86_64-w64-mingw32-
    export CC=x86_64-w64-mingw32-gcc
    orig_cflags="${CFLAGS}"
    export CFLAGS=-DUSE_MLT_POOL
#    apply_patch file://${top_dir}/mlt-rtaudio.patch
    # The --avformat-ldextra option must contain all the libraries that
    # libavformat.dll is linked against. These we obtain by reading libavformat.pc
    # from the pkgconfig directory
    avformat_ldextra=`pkg-config --static --libs-only-l libavformat`
    apply_patch file://${top_dir}/mlt-melt.patch
#    do_configure "--prefix=${mingw_w64_x86_64_prefix} --enable-gpl --enable-gpl3 --disable-gtk2 --target-os=mingw --target-arch=x86_64 --libdir=${mingw_w64_x86_64_prefix}/bin/lib --datadir=${mingw_w64_x86_64_prefix}/bin/share --mandir=${mingw_w64_x86_64_prefix}/share/man --avformat-swscale --avformat-ldextra=${avformat_ldextra}"
    generic_configure_make_install "LIBS=-lole32 --enable-gpl --enable-gpl3 --target-os=mingw --target-arch=x86_64 --prefix=${mingw_w64_x86_64_prefix} --libdir=${mingw_w64_x86_64_prefix}/bin/lib --datadir=${mingw_w64_x86_64_prefix}/bin/share --mandir=${mingw_w64_x86_64_prefix}/share/man --disable-opengl"
#    apply_patch file://${top_dir}/mlt-rtaudio.patch
#    do_make
#    do_make_install
    # The Makefiles don't use Autotools, and put the binaries in the wrong places with
    # no executable extension for 'melt.exe'
    # Also, the paths are not correct for Windows execution. So we must move things
    mv -v ${mingw_w64_x86_64_prefix}/melt.exe ${mingw_w64_x86_64_prefix}/bin/melt.exe
    mv -v ${mingw_w64_x86_64_prefix}/libmlt* ${mingw_w64_x86_64_prefix}/bin/

    unset CXX
    unset CROSS
    unset CC
    export CFLAGS=${orig_cflags}
  cd ..
}

build_DJV() {
#  download_and_unpack_file http://gallery.johnwarburton.net/djv-git-a7104da34d8a273de457b3225f77de35ccb4a63e.tar.xz djv-git-a7104da34d8a273de457b3225f77de35ccb4a63e

  do_git_checkout https://github.com/sobotka/djv-view.git DJV ffmpeg-fixes
  cd DJV
#  cd djv-git-a7104da34d8a273de457b3225f77de35ccb4a63e
    # Patch to get around Mingw-w64's difficult-to-follow handling of strerror_s()
    apply_patch file://${top_dir}/djv-djvFileInfo.cpp.patch
    # Patch to use g++ equivalents of possibly missing environment manipulation functions
    apply_patch file://${top_dir}/djv-djvSystem.cpp.patch
    # Non-portable patch to restore missing #define-s of these math constants
    # that have lately disappeared in Mingw-w64
    apply_patch file://${top_dir}/djv-FFmpeg.patch
    # Use #define pulled from FFmpeg source code
    sed -i.bak 's/FLT_EPSILON/1.19209290e-07F/' lib/djvCore/djvMath.cpp
    sed -i.bak 's/DBL_EPSILON/2.2204460492503131e-16/' lib/djvCore/djvMath.cpp
    # FFmpeg's headers have changed. DJV hasn't caught up yet
    sed -i.bak 's/ PIX_FMT_RGBA/ AV_PIX_FMT_RGBA/' plugins/djvFFmpegPlugin/djvFFmpegLoad.cpp
    # Replace a MSVC function that isn't yet in Mingw-w64
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_VER)/' lib/djvCore/djvStringUtil.h
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_VER)/' plugins/djvJpegPlugin/djvJpegLoad.cpp
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_VER)/' plugins/djvJpegPlugin/djvJpegSave.cpp
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_VER)/' plugins/djvPngPlugin/djvPngLoad.cpp
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_VER)/' plugins/djvPngPlugin/djvPngSave.cpp
    # Don't make dvjFileBrowserTest or, indeed, any tests
    sed -i.bak 's/enable_testing()/#enable_testing()/' CMakeLists.txt
    sed -i.bak 's/add_subdirectory(djvFileBrowserTest)/#add_subdirectory(djvFileBrowserTest)/' tests/CMakeLists.txt
    # Change Windows' backslashes to forward slashes to allow MinGW compilation
    # Remember that . and \ need escaping with \, which makes this hard to read
    sed -i.bak 's!\.\.\\\\.\.\\\\etc\\\\Windows\\\\djv_view.ico!../../etc/Windows/djv_view.ico!' bin/djv_view/win.rc
    do_cmake "-DBUILD_SHARED_LIBS=true -DCMAKE_VERBOSE_MAKEFILE=YES -DENABLE_STATIC_RUNTIME=0 -DCMAKE_PREFIX_PATH=${mingw_w64_x86_64_prefix} -DCMAKE_C_FLAGS=-D__STDC_CONSTANT_MACROS -DCMAKE_CXX_FLAGS=-D__STDC_CONSTANT_MACROS -DCMAKE_SUPPRESS_REGENERATION=TRUE"
    ${top_dir}/correct_headers.sh
#    orig_cpu_count=$cpu_count
#    export cpu_count=1
    do_make "V=1"
#    export cpu_count=$orig_cpu_count
    # The whole DJV suite is now in two directories: build/bin and build/lib.
    # bin contains programs and their necessary DLLs, lib contains plugins and development libraries.
    # We need to copy the executables and their companion DLLs to our bin distribution directory
    # and the plugins (for now)
    cp -v build/bin/* "${mingw_w64_x86_64_prefix}/bin/"
    # The plugins are needed for the many file formats DJV can play
    cp -v build/lib/*dll "${mingw_w64_x86_64_prefix}/bin/"
    # We must rename these plugins to remove the initial "lib". The Cmake Windows packager
    # normally does this, but we're not using it.
    for library in ${mingw_w64_x86_64_prefix}/bin/libdjv*Plugin*dll; do
      dllname=$(basename $library)
      cut_dllname=${dllname:3}
      mv -v ${library} ${mingw_w64_x86_64_prefix}/bin/${cut_dllname}
    done

  cd ..
}

build_DJVnew() {
	do_git_checkout https://github.com/darbyjohnston/DJV.git DJV 2.0.5
	cd DJV
		apply_patch file://${top_dir}/DJVnew.patch
		find . -name 'CMakeLists.txt' -exec sed -i.bak 's/CXX_STANDARD 11/CXX_STANDARD 20/' {} \;
		cp -v ${top_dir}/FindOTIO.cmake cmake/Modules/
		do_cmake "-DDJV_THIRD_PARTY=FALSE -DCMAKE_VERBOSE_MAKEFILE=ON" && ${top_dir}/correct_headers.sh		
		do_make "V=1"
		do_make_install "V=1"
		# The DLLs need to be installed, too
		cp -v build/bin/*dll ${mingw_w64_x86_64_prefix}/bin/
	cd ..
}

build_openblas() {
  do_git_checkout https://github.com/xianyi/OpenBLAS.git OpenBLAS
  cd OpenBLAS
    apply_patch file://${top_dir}/OpenBLAS-makefile.patch
    # Now alter the Makefile.rules to point to the installation directory
    sed -i.bak 's!# PREFIX = /opt/OpenBLAS!PREFIX = '"${mingw_w64_x86_64_prefix}"'!' Makefile.rule
    do_make
    do_make_install

  cd ..
}

build_opencv() {
  do_git_checkout https://github.com/opencv/opencv.git "opencv" 2bd0844be39a799d100e1ac00833ca946a7bfbf7 #3.4 # 2.4
  cd opencv
  # This is only used for a couple of frei0r filters. Surely we can switch off more options than this?
  # WEBP is switched off because it triggers a Cmake bug that removes #define-s of EPSILON and variants
  # This needs more work
  # NOT YET: CMAKE_LIBRARY_PATH needs to find the installed Qt5 libraries
  # Because MinGW has no native Posix threads, we use the Boost emulation and must link the Boost libraries

#    apply_patch file://${top_dir}/opencv-mutex-boost.patch
#    apply_patch file://${top_dir}/opencv-boost-thread.patch
#    apply_patch file://${top_dir}/opencv-wrong-slash.patch
    apply_patch file://${top_dir}/opencv-location.patch
    apply_patch file://${top_dir}/opencv-strict.patch
    mkdir -pv build
    cd build
      do_cmake ".. -DWITH_IPP=OFF -DWITH_EIGEN=ON -DWITH_VFW=ON -DWITH_DSHOW=ON -DOPENCV_ENABLE_NONFREE=ON -DWITH_GTK=ON -DWITH_WIN32UI=ON -DWITH_DIRECTX=ON -DBUILD_SHARED_LIBS=ON -DBUILD_opencv_apps=ON -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DBUILD_WITH_DEBUG_INFO=OFF -DBUILD_JASPER=OFF -DBUILD_JPEG=OFF -DBUILD_OPENEXR=OFF -DBUILD_PNG=OFF -DBUILD_TIFF=OFF -DBUILD_ZLIB=OFF -DENABLE_SSE41=ON -DENABLE_SSE42=ON -DWITH_WEBP=OFF -DBUILD_EXAMPLES=ON -DINSTALL_C_EXAMPLES=ON -DWITH_OPENGL=ON -DINSTALL_PYTHON_EXAMPLES=ON -DCMAKE_CXX_FLAGS=-DMINGW_HAS_SECURE_API=1 -DCMAKE_C_FLAGS=-DMINGW_HAS_SECURE_API=1 -DOPENCV_LINKER_LIBS=boost_thread-mt-x64;boost_system-mt-x64 -DCMAKE_VERBOSE=ON -DINSTALL_TO_MANGLED_PATHS=OFF" && ${top_dir}/correct_headers.sh
      sed -i.bak "s|DBL_EPSILON|2.2204460492503131E-16|g" modules/imgproc/include/opencv2/imgproc/types_c.h
      do_make_install
#      cp -v ${mingw_w64_x86_64_prefix}/lib/libopencv_core320.dll.a ${mingw_w64_x86_64_prefix}/lib/libopencv_core.dll.a
#      cp -v ${mingw_w64_x86_64_prefix}/lib/libopencv_imgproc320.dll.a ${mingw_w64_x86_64_prefix}/lib/libopencv_imgproc.dll.a
#      cp -v ${mingw_w64_x86_64_prefix}/lib/libopencv_objdetect320.dll.a ${mingw_w64_x86_64_prefix}/lib/libopencv_objdetect320.dll.a
#      cp -v ${mingw_w64_x86_64_prefix}/lib/libopencv_highgui320.dll.a ${mingw_w64_x86_64_prefix}/lib/libopencv_highgui320.dll.ai
# OpenCV puts its binaries in a particular place which we need to modify.
#    export OpenCV_DIR=${mingw_w64_x86_64_prefix}
#    export OpenCV_INCLUDE_DIR="${OpenCV_DIR}/include"
#    export OpenCV_INCLUDE
# Not sure why the pkgconfig file doesn't get installed...
    cp -v unix-install/opencv.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    # Undo this patch, which often prevents updating
  #  cp -v CMakeLists.txt.orig CMakeLists.txt
  #  rm -v opencv-boost-thread.patch.done

    cd ..
  cd ..
  # This helps frei0r find opencv
}

build_cunit() {
  generic_download_and_install https://github.com/Linaro/libcunit/releases/download/2.1-3/CUnit-2.1-3.tar.bz2 CUnit-2.1-3 "--disable-shared --enable-static"
  cd CUnit-2.1-3

  cd ..
}

build_libspatialaudio() {
  do_git_checkout https://github.com/videolabs/libspatialaudio.git libspatialaudio # 5420ba0c660236bd319da94fe9bec7d38c13705b
  cd libspatialaudio
    apply_patch file://${top_dir}/libspatialaudio-install.patch
    do_cmake "-DCMAKE_SHARED_LINKER_FLAGS=-lz -DCMAKE_VERBOSE_MAKEFILE=ON"
    do_make_install "V=1"

  cd ..
}

build_libmysofa() {
  do_git_checkout https://github.com/hoene/libmysofa.git libmysofa #"Branch_v0.4(Windows)"
  cd libmysofa
#    apply_patch file://${top_dir}/libmysofa-zlib.patch
    cd src/tests
  #    sed -i.bak 's/CUnit\.h/Cunit\.h/' tests.c
  #    sed -i.bak 's/CUnit\.h/Cunit\.h/' tests.h
    cd ../..
    apply_patch file://${top_dir}/libmysofa-shared.patch
    do_cmake "-DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=ON"
    do_make
    do_make_install

  cd ..
}

build_opendcp() {
# There are quite a few patches because I prefer to build this as a static program,
# whereas the author, understandably, created it as a dynamically-linked program.
  do_git_checkout https://github.com/tmeiczin/opendcp.git opendcp qt5-port
  cd opendcp
    export CMAKE_LIBRARY_PATH="${mingw_w64_x86_64_prefix}/lib"
    export CMAKE_INCLUDE_PATH="${mingw_w64_x86_64_prefix}/include:${mingw_w64_x86_64_prefix}/include/openjpeg-2.1"
    export CMAKE_CXX_FLAGS="-fopenmp"
    export CMAKE_C_FLAGS="-fopenmp"
    export cpu_count=1
    apply_patch file://${top_dir}/opendcp-win32.cmake.patch
    apply_patch file://${top_dir}/opendcp-libopendcp-CMakeLists.txt.patch
    apply_patch file://${top_dir}/opendcp-CMakeLists.txt.patch
#    apply_patch file://${top_dir}/opendcp-libav.patch
#    apply_patch file://${top_dir}/opendcp-brackets.patch
#    apply_patch file://${top_dir}/opendcp-CMakeLists.txt-static.patch
#    apply_patch file://${top_dir}/opendcp-libasdcp-KM_prng.cpp.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.openjpeg-2.1.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.libs.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.windres.patch
#    apply_patch file://${top_dir}/opendcp-packages-CMakeLists.txt-static.patch
    # I don't know why, but dirent_win.h from asdcplib is referenced but does not appear.
    cp -v ../asdcplib-2.7.19/src/dirent_win.h libasdcp
    do_cmake "-DINSTALL_LIB=ON -DLIB_INSTALL_PATH=${mingw_w64_x86_64_prefix}/lib -DENABLE_XMLSEC=ON -DENABLE_GUI=ON -DBUILD_SHARED=ON -DBUILD_STATIC=OFF -DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_OPENMP=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF"
    sed -i.bak 's/-isystem /-I/g' gui/CMakeFiles/opendcp.dir/includes_CXX.rsp
    do_make_install
    cp -v ${mingw_w64_x86_64_prefix}/lib/libopencv_core2413.dll.a ${mingw_w64_x86_64_prefix}/lib/libopencv_core.dll.a
    cp -v ${mingw_w64_x86_64_prefix}/lib/libopencv_imgproc2413.dll.a ${mingw_w64_x86_64_prefix}/lib/libopencv_imgproc.dll.a
    unset CMAKE_C_FLAGS
    unset CMAKE_CXX_FLAGS
    unset CMAKE_LIBRARY_PATH
    unset CMAKE_INCLUDE_PATH
    export cpu_count=$original_cpu_count

  cd ..
}

build_dcpomatic() {
#do_git_checkout https://github.com/cth103/dcpomatic.git dcpomatic 9cff6ec974a4d0270091fe5c753483b0d53ecd46
#  do_git_checkout git://git.carlh.net/git/dcpomatic.git dcpomatic # 9cff6ec974a4d0270091fe5c753483b0d53ecd46 # bfb7e79c958036e77a7ffe33310d8c0957848602 # 591dc9ed8fc748d5e594b337d03f22d897610eff #5c712268c87dd318a6f5357b0d8f7b8a8b7764bb # 591dc9ed8fc748d5e594b337d03f22d897610eff #fe8251bb73765b459042b0fa841dae2d440487fd #4ac1ba47652884a647103ec49b2de4c0b6e60a9 # v2.13.0
  download_and_unpack_file "https://dcpomatic.com/dl.php?id=source&version=2.15.45" dcpomatic-2.15.45
  cd dcpomatic-2.15.45
#    apply_patch file://${top_dir}/dcpomatic-wscript.patch
#    apply_patch file://${top_dir}/dcpomatic-audio_ring_buffers.h.patch
##    apply_patch file://${top_dir}/dcpomatic-ffmpeg.patch
    apply_patch file://${top_dir}/dcpomatic-boost.patch
    apply_patch file://${top_dir}/dcpomatic-gl.patch
    apply_patch file://${top_dir}/dcpomatic-src-wx-wscript.patch
    apply_patch file://${top_dir}/dcpomatic-unicode.patch
    apply_patch file://${top_dir}/dcpomatic-rc.patch
    apply_patch file://${top_dir}/dcpomatic-display.patch
##    apply_patch file://${top_dir}/dcpomatic-test-wscript.patch
##    apply_patch file://${top_dir}/dcpomatic-libsub.patch
##    apply_patch file://${top_dir}/dcpomatic-LogColorspace.patch
     # M_PI is missing in mingw-w64
    sed -i.bak 's/M_PI/3.14159265358979323846/g' src/lib/audio_filter.cc
     # The RC file looks for wxWidgets 3.0 rc, but it's 3.1 in our build
#    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic.rc
#    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic_batch.rc
#    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic_server.rc
#    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic_kdm.rc
    export CFLAGS="-fpermissive" # -DBOOST_ASIO_DISABLE_STD_FUTURE=1"
    env
    do_configure "configure WINRC=x86_64-w64-mingw32-windres CXX=x86_64-w64-mingw32-g++ -v -pp --static-dcpomatic --prefix=${mingw_w64_x86_64_prefix} --target-windows --check-cxx-compiler=gxx --disable-tests" "./waf"
    ./waf build -v || exit 1
    ./waf install || exit 1
    # ./waf clean || exit 1
    export CFLAGS="${original_cflags}"
  cd ..
}

build_gcal() {
  generic_download_and_install http://ftp.gnu.org/gnu/gcal/gcal-4.1.tar.xz gcal-4.1
  cd gcal-4.1

  cd ..
}

build_unbound() {
  generic_download_and_install https://www.unbound.net/downloads/unbound-latest.tar.gz unbound-1.10.0 "CFLAGS=-O1 libtool=${mingw_w64_x86_64_prefix}/bin/libtool --with-ssl=${mingw_w64_x86_64_prefix} --with-libunbound-only --with-libexpat=${mingw_w64_x86_64_prefix}"
}

build_libxavs() {
  do_svn_checkout https://svn.code.sf.net/p/xavs/code/trunk xavs
  cd xavs
    export LDFLAGS='-lm'
    generic_configure "--disable-asm --cross-prefix=$cross_prefix" # see https://github.com/rdp/ffmpeg-windows-build-helpers/issues/3
    unset LDFLAGS
    do_make_install "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar PREFIX=$mingw_w64_x86_64_prefix RANLIB=$(echo $cross_prefix)ranlib STRIP=$(echo $cross_prefix)strip"
  cd ..
}

build_libxavs2() {
    do_git_checkout https://github.com/pkuvcl/xavs2.git xavs2
    cd xavs2/build/linux
        generic_configure "--cross-prefix=$cross_prefix"
        do_make_install
    cd ../../..
}

build_libpng() {
  download_and_unpack_file http://prdownloads.sourceforge.net/libpng/libpng-1.6.37.tar.xz?download libpng-1.6.37
  cd libpng-1.6.37
    # DBL_EPSILON 21 Feb 2015 starts to come back "undefined". I have NO IDEA why.
    #grep -lr DBL_EPSILON contrib | xargs sed -i "s| DBL_EPSILON| 2.2204460492503131E-16|g"
    generic_configure_make_install "--enable-shared"
    sed -i.bak 's/-lpng16.*$/-lpng16 -lz/' "$PKG_CONFIG_PATH/libpng.pc"
    sed -i.bak 's/-lpng16.*$/-lpng16 -lz/' "$PKG_CONFIG_PATH/libpng16.pc"

  cd ..
}

build_libopenjpeg() {
# FFmpeg doesn't yet take Openjpeg 2 so we compile version 1 here.
  download_and_unpack_file https://github.com/uclouvain/openjpeg/archive/version.1.5.2.tar.gz openjpeg-version.1.5.2
  cd openjpeg-version.1.5.2
    # The CMakeFile include forces /usr/include, which is no use for Mingw builds at all.
#    sed  -i.bak "s|-I/usr/include||" applications/mj2/CMakeFiles/extract_j2k_from_mj2.dir/includes_C.rsp
    # export CFLAGS="$CFLAGS -DOPJ_STATIC" # see https://github.com/rdp/ffmpeg-windows-build-helpers/issues/37
    # MUST install pkgconfig files for other programs to see
    apply_patch file://${top_dir}/libopenjpeg-cmake-pkgconfig.patch
    do_cmake "-DBUILD_CODEC:bool=off -DBUILD_VIEWER:bool=OFF -DBUILD_MJ2:bool=OFF -DBUILD_JPWL:bool=OFF -DBUILD_JPIP:bool=OFF -DBUILD_TESTS:BOOL=OFF -DBUILD_SHARED_LIBS:BOOL=ON -DBUILD_STATIC_LIBS:BOOL=OFF -DCMAKE_VERBOSE_MAKEFILE=OFF"
    do_make_install
   # export CFLAGS=$original_cflags # reset it
    # Copy to an expected name the pkgconfig file
    cp -v ${mingw_w64_x86_64_prefix}/lib/pkgconfig/libopenjpeg1.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig/libopenjpeg.pc

  cd ..
}

build_lcms2() {
  do_git_checkout https://github.com/mm2/Little-CMS.git lcms2 # 5d91cf48902068b5049a7f9961fa23a267d0c93e
  cd lcms2
    generic_configure_make_install

  cd ..
}

build_libopenjpeg2() {
  do_git_checkout https://github.com/uclouvain/openjpeg.git openjpeg2
#  download_and_unpack_file "http://downloads.sourceforge.net/project/openjpeg.mirror/2.1.0/openjpeg-2.1.0.tar.gz" openjpeg-2.1.0
  cd openjpeg2
    export CFLAGS="$CFLAGS" # -DOPJ_STATIC"
    do_cmake "-D_BUILD_SHARED_LIBS:BOOL=ON -DBUILD_VIEWER:bool=OFF -DBUILD_MJ2:bool=OFF -DBUILD_JPWL:bool=OFF -DBUILD_JPIP:bool=OFF -DBUILD_TESTS:bool=OFF -DBUILD_SHARED_LIBS:bool=ON -DBUILD_STATIC_LIBS:BOOL=OFF -DBUILD_CODEC:bool=ON -DBUILD_PKGCONFIG_FILES:bool=ON"
    do_make_install

    export CFLAGS=$original_cflags
  cd ..
}

build_libvpx() {
  if [[ $prefer_stable = "y" ]]; then
    download_and_unpack_file http://webm.googlecode.com/files/libvpx-v1.3.0.tar.bz2 libvpx-v1.3.0
    cd libvpx-v1.3.0
  else
    do_git_checkout https://chromium.googlesource.com/webm/libvpx "libvpx_git" # "nextgenv2"
    cd libvpx_git
    apply_patch file://${top_dir}/libvpx-vp8-common-threading-h-mingw.patch
  fi
  export CROSS="$cross_prefix"
  do_configure "--target=x86_64-win64-gcc --prefix=$mingw_w64_x86_64_prefix --disable-unit-tests --disable-encode-perf-tests --disable-decode-perf-tests --enable-vp9-temporal-denoising --enable-postproc --enable-vp9-postproc --enable-multithread --enable-error-concealment --enable-runtime-cpu-detect --enable-webm-io --enable-libyuv  --disable-avx512 --enable-multi-res-encoding"
#    do_configure "--extra-cflags=-DPTW32_STATIC_LIB --target=x86_64-win64-gcc --prefix=$mingw_w64_x86_64_prefix --enable-static --disable-shared --disable-unit-tests --disable-encode-perf-tests --disable-decode-perf-tests --enable-vp10 --enable-vp10-encoder --enable-vp10-decoder --enable-vp9-highbitdepth --enable-vp9-temporal-denoising --enable-postproc --enable-vp9-postproc"
    # libvpx only supports static building on MinGW platform
#    do_configure "--target=x86_64-win64-gcc --prefix=$mingw_w64_x86_64_prefix --enable-static --disable-unit-tests --disable-encode-perf-tests --disable-decode-perf-tests --enable-vp9-temporal-denoising --enable-postproc --enable-vp9-postproc --enable-multithread" # --enable-vp10 --enable-vp10-encoder --enable-vp10-decoder"
  do_make_install
  # Now create the shared library
  ${cross_prefix}gcc -shared -o libvpx-1.dll -Wl,--out-implib,libvpx.dll.a -Wl,--whole-archive,libvpx.a,--no-whole-archive -lpthread || exit 1
  cp -v libvpx-1.dll $mingw_w64_x86_64_prefix/bin/libvpx-1.dll
  cp -v libvpx.dll.a $mingw_w64_x86_64_prefix/lib/libvpx.dll.a
  # This is a hack. The libvpx.a file needs to survive a make clean, so that there isn't a problem
  # with remaking the shared library when this procedure is called but the tree has received
  # no updates.
  tempfile=$(mktemp /tmp/multimedia-compile.XXXXXXXXXX)
  echo "We will copy libvpx.a to $tempfile now."
  cp -v libvpx.a $tempfile

  cp -v $tempfile libvpx.a && rm $tempfile
  unset CROSS
  cd ..
}

build_libutvideo() {
# SUPERSEDED BY NATIVE CODE AND NO LONGER COMPILED
#  download_and_unpack_file http://umezawa.dyndns.info/archive/utvideo/utvideo-12.2.1-src.zip utvideo-12.2.1
#  cd utvideo-12.2.1
#    apply_patch file://${top_dir}/utv.diff
#    sed -i.bak "s|Format.o|DummyCodec.o|" GNUmakefile
#    do_make_install "CROSS_PREFIX=$cross_prefix DESTDIR=$mingw_w64_x86_64_prefix prefix=" # prefix= to avoid it adding an extra /usr/local to it yikes
#  cd ..
  do_git_checkout https://github.com/qyot27/libutvideo.git libutvideo
  cd libutvideo
    # Utvideo calculates its version but it must be done with a program that runs on
    # the HOST, not on the target
    sed -i.bak 's/$CC -o version$EXE version.c/gcc -o version version.c/' configure
    sed -i.bak 's/version$EXE/version/' configure
    do_configure "--enable-pic --enable-shared --disable-static --enable-asm=x64 --host=x86_64-w64-mingw32 --cross-prefix=x86_64-w64-mingw32- --prefix=${mingw_w64_x86_64_prefix}"
    do_make
    do_make_install

    # Unfortunately, the version gets hardcoded into the filename of the .a file
    cp -fv ${mingw_w64_x86_64_prefix}/lib/libutvideo-15.1.0.dll.a ${mingw_w64_x86_64_prefix}/lib/libutvideo.dll.a
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

build_libx262() {
  do_git_checkout http://git.videolan.org/git/x262.git x262
  cd x262
    generic_configure "--host=$host_target --enable-static --disable-shared --cross-prefix=$cross_prefix --prefix=$mingw_w64_x86_64_prefix --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac --disable-win32thread"
    do_make
    # We ONLY need the x262.exe binary, because the version of libx264 it incorporates is not up-to-date.
    # Therefore, to use its MPEG2 video encoding capability, data must be piped to the x262.exe program
    # and it cannot be linked as a library into FFmpeg, even though FFmpeg is ready for it.
    #
    # The best solution would be to merge the up-to-date x264 tree with the x262 tree but I haven't the time.
    echo "Now copying ONLY the x262.exe binary."
    cp x262.exe ${mingw_w64_x86_64_prefix}/bin/x262.exe

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

build_doxygen() {
  download_and_unpack_file https://github.com/doxygen/doxygen/archive/Release_1_8_17.tar.gz doxygen-Release_1_8_17
  cd doxygen-Release_1_8_17
#    sed -i.bak 's/WIN32/MSVC/' CMakeLists.txt
#    sed -i.bak 's/if (win_static/if (win_static AND MSVC/' CMakeLists.txt
    apply_patch file://${top_dir}/doxygen-cmake.patch
#    apply_patch file://${top_dir}/doxygen-fix-casts.patch
    do_cmake "-DCMAKE_VERBOSE_MAKEFILE=ON" # -DICONV_INCLUDE_DIR=$mingw_w64_x86_64_prefix/include
    do_make_install  "V=1"

  cd ..
}

build_libflite() {
#  download_and_unpack_file http://www.speech.cs.cmu.edu/flite/packed/flite-1.4/flite-1.4-release.tar.bz2 flite-1.4-release
#  cd flite-1.4-release
   download_and_unpack_file http://download.sipxcom.org/pub/sipXecs/libs/flite-2.0.0-release.tar.bz2 flite-2.0.0-release
   cd flite-2.0.0-release
#     apply_patch file://${top_dir}/flite_64.diff
     sed -i.bak "s|i386-mingw32-|$cross_prefix|" configure*
     generic_configure "CFLAGS=-fcommon"
     apply_patch file://${top_dir}/flite-remove-inline.patch
     do_make
     make install # it fails in error..
     # Now create the shared library
     cp -v ./build/x86_64-mingw32/lib/libflite.a .
     ${cross_prefix}gcc -shared -o libflite.dll -Wl,--out-implib,libflite.dll.a -Wl,--whole-archive,libflite.a,--no-whole-archive -lpthread || echo "Files cleaned already. No problem."
     cp -v ./build/x86_64-mingw32/lib/*.a $mingw_w64_x86_64_prefix/lib
     cp -v libflite.dll.a $mingw_w64_x86_64_prefix/lib
     cp -v libflite.dll $mingw_w64_x86_64_prefix/bin

   cd ..
}

build_libgsm() {
  download_and_unpack_file http://www.quut.com/gsm/gsm-1.0.13.tar.gz gsm-1.0-pl13
  cd gsm-1.0-pl13
  apply_patch file://${top_dir}/libgsm.patch # for openssl to work with it, I think?
  # not do_make here since this actually fails [in error]
  make CC=${cross_prefix}gcc AR=${cross_prefix}ar RANLIB=${cross_prefix}ranlib INSTALL_ROOT=${mingw_w64_x86_64_prefix}
  cp lib/libgsm.a $mingw_w64_x86_64_prefix/lib || exit 1
  mkdir -vp $mingw_w64_x86_64_prefix/include/gsm
  cp inc/gsm.h $mingw_w64_x86_64_prefix/include/gsm || exit 1
  cd ..
}

build_libopus() {
#  download_and_unpack_file http://downloads.xiph.org/releases/opus/opus-1.2-alpha.tar.gz opus-1.2-alpha
  do_git_checkout https://github.com/xiph/opus.git opus
  cd opus
#  cd opus-1.2-alpha
#     apply_patch file://${top_dir}/opus-nostatic.patch # one test doesn't work with a shared library
#    apply_patch file://${top_dir}/opus11.patch # allow it to work with shared builds
    generic_configure_make_install "--enable-custom-modes --enable-asm --enable-ambisonics --enable-update-draft"

  cd ..
}

build_libdvdread() {
  build_libdvdcss
  do_git_checkout https://code.videolan.org/videolan/libdvdread.git libdvdread
#  download_and_unpack_file http://download.videolan.org/pub/videolan/libdvdread/5.0.3/libdvdread-5.0.3.tar.bz2 libdvdread-5.0.3
  cd libdvdread
  # Need this to help libtool not object
  sed -i.bak 's/libdvdread_la_LDFLAGS = -version-info $(DVDREAD_LTVERSION)/libdvdread_la_LDFLAGS = -version-info $(DVDREAD_LTVERSION) -no-undefined/' Makefile.am
  generic_configure "--with-libdvdcss CFLAGS=-DHAVE_DVDCSS_DVDCSS_H LDFLAGS=-ldvdcss" # vlc patch: "--enable-libdvdcss" # XXX ask how I'm *supposed* to do this to the dvdread peeps [svn?]
  #apply_patch https://raw.githubusercontent.com/rdp/ffmpeg-windows-build-helpers/master/patches/dvdread-win32.patch # has been reported to them...
  do_make_install
  #sed -i "s/-ldvdread.*/-ldvdread -ldvdcss/" $mingw_w64_x86_64_prefix/bin/dvdread-config # ??? related to vlc patch, above, probably
  sed -i.bak 's/-ldvdread.*/-ldvdread -ldvdcss/' "$PKG_CONFIG_PATH/dvdread.pc"

  cd ..
}

build_libdvdnav() {
  do_git_checkout https://code.videolan.org/videolan/libdvdnav.git libdvdnav
#  download_and_unpack_file http://download.videolan.org/pub/videolan/libdvdnav/5.0.3/libdvdnav-5.0.3.tar.bz2 libdvdnav-5.0.3
  cd libdvdnav
 # if [[ ! -f ./configure ]]; then
 #   ./autogen.sh
  #fi
  sed -i.bak 's/libdvdnav_la_LDFLAGS = /libdvdnav_la_LDFLAGS = -no-undefined /' Makefile.am
  autoreconf -vfi
  generic_configure
  do_make_install

  cd ..
}

build_libdvdcss() {
  do_git_checkout http://code.videolan.org/videolan/libdvdcss.git libdvdcss
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
  download_and_unpack_file ftp://sourceware.org/pub/gdb/releases/gdb-8.2.1.tar.xz gdb-8.2.1
  cd gdb-8.2.1
#    cd readline
#    generic_configure_make_install
#   cd ..
  generic_configure_make_install "--with-system-readline --enable-tui --enable-plugins --with-expat --with-lzma"

  cd ..
  unset LIBS
}

build_readline() {
  do_git_checkout git://git.savannah.gnu.org/readline.git readline
  cd readline
    rm configure
    #apply_patch file://${top_dir}/readline-mingw32.patch
    generic_configure_make_install "--without-curses"

  cd ..
}

build_ASIOSDK() {
  download_and_unpack_file http://www.steinberg.net/sdk_downloads/asiosdk2.3.zip ASIOSDK2.3
}

build_portaudio_with_jack() {
#  download_and_unpack_file http://www.portaudio.com/archives/pa_stable_v19_20140130.tgz portaudio
  do_git_checkout https://git.assembla.com/portaudio.git portaudio_with_jack
  cd portaudio_with_jack
    # Code doesn't recognize mingw-w64 as a Windows platform compiler
#    apply_patch file://${top_dir}/portaudio-pa_win_wasapi.c.patch
    apply_patch file://${top_dir}/portaudio.patch
#    apply_patch file://${top_dir}/portaudio-1-fixes-crlf.patch
#    apply_patch file://${top_dir}/portaudio.patch
    rm configure
    generic_configure_make_install "--disable-dependency-tracking --with-jack --with-host_os=mingw --disable-cxx --with-winapi=asio,wmme,directx,wasapi --with-asiodir=../ASIOSDK2.3  --with-dxdir=${mingw_w64_x86_64_prefix}" # "ac_cv_path_AR=x86_64-w64-mingw32-ar"
      # Lots of useful test programs
    cp -v bin/*exe ${mingw_w64_x86_64_prefix}/bin/
    # For some reason, libportaudio.dll.a doesn't get installed
    cp -v libs/.libs/libportaudio.dll.a ${mingw_w64_x86_64_prefix}/lib/

  cd ..
}

build_portaudio_without_jack() {
#  download_and_unpack_file http://www.portaudio.com/archives/pa_stable_v19_20140130.tgz portaudio
  do_git_checkout https://git.assembla.com/portaudio.git portaudio_without_jack
  cd portaudio_without_jack
    # Code doesn't recognize mingw-w64 as a Windows platform compiler
#    apply_patch file://${top_dir}/portaudio-pa_win_wasapi.c.patch
    apply_patch file://${top_dir}/portaudio.patch
#    apply_patch file://${top_dir}/portaudio-1-fixes-crlf.patch
#    apply_patch file://${top_dir}/portaudio.patch
    rm configure
    generic_configure_make_install "--disable-dependency-tracking --without-jack --with-host_os=mingw --disable-cxx --with-winapi=asio,wmme,directx,wasapi --with-asiodir=../ASIOSDK2.3 --with-dxdir=${mingw_w64_x86_64_prefix}" # "ac_cv_path_AR=x86_64-w64-mingw32-ar"
      # Lots of useful test programs
    cp -v bin/*exe ${mingw_w64_x86_64_prefix}/bin/
    # For some reason, libportaudio.dll.a doesn't get installed
    cp -v libs/.libs/libportaudio.dll.a ${mingw_w64_x86_64_prefix}/lib/

  cd ..
}

build_jack() {
  do_git_checkout https://github.com/jackaudio/jack2.git jack2 394e02b2bb87ed8dfb0341f274c5b41aded8efdc
#  download_and_unpack_file https://dl.dropboxusercontent.com/u/28869550/jack-1.9.10.tar.bz2 jack-1.9.10
  cd jack2
    if [ ! -f "jack.built" ] ; then
#      apply_patch file://${top_dir}/jack-1-fixes.patch
      apply_patch file://${top_dir}/jack2-win32.patch
      export AR=x86_64-w64-mingw32-ar
      export CC=x86_64-w64-mingw32-gcc
      export CXX=x86_64-w64-mingw32-g++
      export CXXFLAGS_ORIG=${CXXFLAGS}
      export CXXFLAGS="-DMINGW_HAS_SECURE_API=1 -D__USE_MINGW_ANSI_STDIO=1"
#      export cpu_count=1
      do_configure "configure --prefix=${mingw_w64_x86_64_prefix} --platform=win32 -ppp" "./waf"
      ./waf build || exit 1
      ./waf install || exit 1
      # The Jack development libraries are now in /bin. They should be in /lib
      cp -v ${mingw_w64_x86_64_prefix}/bin/libjack*.dll.a ${mingw_w64_x86_64_prefix}/lib/
      cp -v ${mingw_w64_x86_64_prefix}/bin/jack*.dll.a ${mingw_w64_x86_64_prefix}/lib/
      # The Jack development libraries are, strangely, placed into a subdirectory of lib
#      echo "Placing the Jack development libraries in the expected place..."
#      cp -v ${mingw_w64_x86_64_prefix}/lib/jack/*dll.a ${mingw_w64_x86_64_prefix}/lib
      # Copy Jack's own DLL that requires registration
      cp -v windows/Setup/src/64bits/JackRouter.dll ${mingw_w64_x86_64_prefix}/bin
      cp -v windows/Setup/src/32bits/JackRouter.dll ${mingw_w64_x86_64_prefix}/bin/JackRouter32.dll
      cp -v windows/Setup/src/64bits/JackRouter.ini ${mingw_w64_x86_64_prefix}/bin
      cp -v ${mingw_w64_x86_64_prefix}/bin/libjack-0.dll ${mingw_w64_x86_64_prefix}/bin/libjack64.dll
      export CXXFLAGS=${CXXFLAGS_ORIG}
#      export cpu_count=$original_cpu_count
      # Because of what we have just done,
      # bizarrely, jack installs ANOTHER libportaudio over the real libportaudio DLL export library
      # So we must replae it now.
#      cp -v ../portaudio/libs/.libs/libportaudio.dll.a ${mingw_w64_x86_64_prefix}/lib/i
      touch jack.built
    fi
    unset AR
    unset CC
    unset CXX
    export CXXFLAGS=${CXXFLAGS_ORIG}
  cd ..
}

build_sord() {
   do_git_checkout http://git.drobilla.net/sord.git sord 44afb527ce74d6ec6f9d8b769ad8459cacdc2fec
   cd sord
     export AR=x86_64-w64-mingw32-ar
     export CC=x86_64-w64-mingw32-gcc
     export CXX=x86_64-w64-mingw32-g++
     export CXXFLAGS_ORIG=${CXXFLAGS}
     export CXXFLAGS=-DMINGW_HAS_SECURE_API=1
     do_configure "configure --prefix=${mingw_w64_x86_64_prefix} -ppp" "./waf"
     ./waf build || exit 1
     ./waf install || exit 1
   cd ..
   unset AR
   unset CC
   unset CXX
   export CXXFLAGS=${CXXFLAGS_ORIG}


}

build_sratom() {
  do_git_checkout http://git.drobilla.net/sratom.git sratom de6492738adf1794bf5fa39c1fe1ebbd167727ac
  cd sratom
    export AR=x86_64-w64-mingw32-ar
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
    export CXXFLAGS_ORIG=${CXXFLAGS}
    export CXXFLAGS=-DMINGW_HAS_SECURE_API=1
    do_configure "configure --prefix=${mingw_w64_x86_64_prefix} -ppp" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
  cd ..
  unset AR
  unset CC
  unset CXX
  export CXXFLAGS=${CXXFLAGS_ORIG}
}

build_serd() {
  do_git_checkout http://git.drobilla.net/serd.git serd 683d47cb7fddf5447de76cdf80041b6b230de93c
  cd serd
    export AR=x86_64-w64-mingw32-ar
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
    export CXXFLAGS_ORIG=${CXXFLAGS}
    export CXXFLAGS=-DMINGW_HAS_SECURE_API=1
    do_configure "configure --prefix=${mingw_w64_x86_64_prefix} -ppp" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
  cd ..
  unset AR
  unset CC
  unset CXX
  export CXXFLAGS=${CXXFLAGS_ORIG}

}

build_lv2() {
  # Release version
  do_git_checkout https://github.com/drobilla/lv2.git lv2 9b7bfdd92d9a12b0d7db59f0ec0bb790fb827406 # 0fa4d4847eb6d5bb0f58da889933c94c37ecb730
  cd lv2
    export AR=x86_64-w64-mingw32-ar
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
    export CXXFLAGS_ORIG=${CXXFLAGS}
    export CXXFLAGS=-DMINGW_HAS_SECURE_API=1
    apply_patch file://${top_dir}/lv2-link.patch
    do_configure "configure --no-coverage --prefix=${mingw_w64_x86_64_prefix} -ppp" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
  cd ..
  unset AR CC CXX
  export CXXFLAGS=${CXXFLAGS_ORIG}
}

build_lilv() {
  do_git_checkout http://git.drobilla.net/lilv.git lilv c1637b46f9ff960f58dcf2bb3b69bff231f8acfd # a9edaabf0926a18dd96fae30c7206fd8eadb0fdc
  cd lilv
    export AR=x86_64-w64-mingw32-ar
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
    export CXXFLAGS_ORIG=${CXXFLAGS}
    export CXXFLAGS=-DMINGW_HAS_SECURE_API=1
    do_configure "configure --prefix=${mingw_w64_x86_64_prefix} -ppp" "./waf"
    apply_patch file://${top_dir}/lilv-mingw.patch
    ./waf build || exit 1
    ./waf install || exit 1
  cd ..
  unset AR CC CXX
  export CXXFLAGS=${CXXFLAGS_ORIG}
  ln -vs ${mingw_w64_x86_64_prefix}/include/lilv-0/lilv ${mingw_w64_x86_64_prefix}/include/lilv
}


build_leptonica() {
  do_git_checkout https://github.com/DanBloomberg/leptonica.git leptonica f1ebb73bf939bca13570c35db8cc656d2735c1d7
  cd leptonica
    generic_configure_make_install "LIBS=-lopenjpeg --disable-silent-rules --without-libopenjpeg"

  cd ..
#  generic_download_and_install http://www.leptonica.com/source/leptonica-1.73.tar.gz leptonica-1.73 "LIBS=-lopenjpeg --disable-silent-rules --without-libopenjpeg"
}

build_libpopt() {
  download_and_unpack_file https://fossies.org/linux/misc/popt-1.16.tar.gz popt-1.16
  cd popt-1.16
    apply_patch file://${top_dir}/popt-get-w32-console-maxcols.patch
    apply_patch file://${top_dir}/popt-no-uid.patch
    generic_configure_make_install

  cd ..
}


build_termcap() {
  download_and_unpack_file ftp://ftp.gnu.org/gnu/termcap/termcap-1.3.1.tar.gz termcap-1.3.1
  cd termcap-1.3.1
    rm configure
    generic_configure "--host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32 --enable-install-termcap"
    do_make
    # We make our own DLL from the static library
    x86_64-w64-mingw32-gcc -shared -Wl,--out-implib,libtermcap.dll.a -o libtermcap-0.dll termcap.o tparam.o version.o
    install libtermcap-0.dll "${mingw_w64_x86_64_prefix}/bin"
    install libtermcap.dll.a "${mingw_w64_x86_64_prefix}/lib"
  cd ..
}

build_ncurses() {
  export PATH_SEPARATOR=";"
  old_term=$TERM
  export TERM="#win32con"
  echo "mkdir -v -p ${mingw_w64_x86_64_prefix}/share/terminfo"
  mkdir -v -p ${mingw_w64_x86_64_prefix}/share/terminfo
  if [[ ! -f terminfo.src ]]; then
    wget http://invisible-island.net/datafiles/current/terminfo.src.gz
    gunzip terminfo.src.gz
  fi
  download_and_unpack_file ftp://ftp.invisible-island.net/ncurses/current/ncurses-6.2-20200215.tgz ncurses-6.2-20200215
 # generic_configure "--build=x86_64-pc-linux --host=x86_64-w64-mingw32 --with-libtool --disable-termcap --enable-widec --enable-term-driver --enable-sp-funcs --without-ada --with-debug=no --with-shared=yes --with-normal=no --enable-database --with-progs --enable-interop --with-pkg-config-libdir=${mingw_w64_x86_64_prefix}/lib/pkgconfig --enable-pc-files"
  cd ncurses-6.2-20200215
#    apply_patch file://${top_dir}/ncurses-rx.patch
#    rm configure
    generic_configure "LIBS=-lgnurx --build=x86_64-pc-linux --host=x86_64-w64-mingw32 --disable-termcap --enable-widec --enable-term-driver --enable-sp-funcs --without-ada --without-cxx-binding --with-debug=no --with-shared=yes --with-normal=no --enable-database --with-probs --enable-interop --with-pkg-config-libdir=${mingw_w64_x86_64_prefix}/lib/pkgconfig --enable-pc-files --disable-static --enable-shared"
    apply_patch file://${top_dir}/ncurses-rx.patch
    do_make
#    do_make "dlls"
    do_make_install

  cd ..
  unset PATH_SEPARATOR
  export TERM=${old_term}
}

build_coreutils() {
  generic_download_and_install http://ftp.gnu.org/gnu/coreutils/coreutils-8.23.tar.xz coreutils-8.23

}

build_less() {
  generic_download_and_install https://ftp.gnu.org/gnu/less/less-487.tar.gz less-487

}

build_dvdbackup() {
	download_and_unpack_file http://downloads.sourceforge.net/dvdbackup/dvdbackup-0.4.2.tar.xz dvdbackup-0.4.2
	cd dvdbackup-0.4.2
	#  bzr branch lp:dvdbackup
#  cd dvdbackup
		export ac_cv_func_malloc_0_nonnull=yes
		if [[ ! -f "configure" ]]; then
		    autoreconf -fiv || exit 1 # failure here, OS X means "you need libtoolize" perhaps? http://betterlogic.com/roger/2014/12/ilbc-cross-compile-os-x-mac-woe/
		fi
		sed -i.bak 's/mkdir(targetname, 0777)/mkdir(targetname)/' src/main.c
		generic_configure_make_install "ac_cv_func_malloc_0_nonnull=yes LIBS=-ldvdcss"
		unset ac_cv_func_malloc_0_nonnull
  	cd ..
}

build_libopencore() {
  generic_download_and_install https://launchpad.net/ubuntu/+archive/primary/+files/opencore-amr_0.1.3.orig.tar.gz opencore-amr-0.1.3
  cd opencore-amr-0.1.3

  cd ..
  generic_download_and_install https://launchpad.net/ubuntu/+archive/primary/+files/vo-amrwbenc_0.1.3.orig.tar.gz vo-amrwbenc-0.1.3
  cd vo-amrwbenc-0.1.3

  cd ..
}

# NB this is kind of worse than just using the one that comes from the zeranoe script, since this one requires the -DPTHREAD_STATIC everywhere...
build_win32_pthreads() {
  download_and_unpack_file ftp://sourceware.org/pub/pthreads-win32/pthreads-w32-2-9-1-release.tar.gz   pthreads-w32-2-9-1-release
#  download_and_unpack_file https://downloads.sourceforge.net/project/pthreads4w/pthreads4w-code-v2.10.0-rc.zip pthreads4w-code-02fecc211d626f28e05ecbb0c10f739bd36d6442
  cd pthreads-w32-2-9-1-release
#  cd pthreads4w-code-02fecc211d626f28e05ecbb0c10f739bd36d6442
#    do_make "clean GC-static CROSS=$cross_prefix" # NB no make install
     do_make "clean GC-inlined CROSS=$cross_prefix"
    cp -v libpthreadGC2.a $mingw_w64_x86_64_prefix/lib/libpthread.a || exit 1
    cp -v pthreadGC2.dll $mingw_w64_x86_64_prefix/bin/pthread.dll || exit 1
    cp -v pthreadGC2.dll $mingw_w64_x86_64_prefix/lib/libpthread.dll || exit 1
    cp -v pthreadGC2.dll $mingw_w64_x86_64_prefix/lib/libpthreadGC2.dll || exit 1
    cp -v pthreadGC2.dll $mingw_w64_x86_64_prefix/lib/pthreadGC2.dll || exit 1
    cp -v pthread.def $mingw_w64_x86_64_prefix/lib/pthread.def || exit 1
#   Just in case anyone tries to link to the wrong library name
    cp -v pthreadGC2.dll $mingw_w64_x86_64_prefix/bin/pthreadGC2.dll || exit 1
#    cp libpthreadGC2.a $mingw_w64_x86_64_prefix/lib/libpthreads.a || exit 1
    cp pthread.h sched.h semaphore.h $mingw_w64_x86_64_prefix/include || exit 1
  cd ..
}

build_libdlfcn() {
  do_git_checkout https://github.com/dlfcn-win32/dlfcn-win32.git dlfcn-win32 # 23d77533b3277a9f722e66484f3ed5b702c7bbda
  cd dlfcn-win32
    ./configure --enable-shared --enable-static --cross-prefix=$cross_prefix --prefix=$mingw_w64_x86_64_prefix
    do_make_install

  cd ..
}

build_rsync() {
  do_git_checkout https://github.com/AndyA/rsync.git rsync
  cd rsync
    generic_configure_make_install

  cd ..
}

build_libjpeg_turbo() {
#  do_git_checkout https://github.com/libjpeg-turbo/libjpeg-turbo libjpeg-turbo #1.5.x
  download_and_unpack_file https://downloads.sourceforge.net/project/libjpeg-turbo/2.0.4/libjpeg-turbo-2.0.4.tar.gz libjpeg-turbo-2.0.4
  cd libjpeg-turbo-2.0.4
#    apply_patch file://${top_dir}/libjpeg-turbo-simd-yasm.patch
    do_cmake "-DENABLE_STATIC=FALSE -DENABLE_SHARED=TRUE -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=AMD64 -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres"
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
  do_git_checkout http://github.com/xiph/ogg.git ogg
  cd ogg
    generic_configure_make_install "--enable-static"

  cd ..
#  generic_download_and_install http://downloads.xiph.org/releases/ogg/libogg-1.3.2.tar.gz libogg-1.3.2
}

build_jackmix() {
  do_git_checkout https://github.com/kampfschlaefer/jackmix.git jackmix qt5
  cd jackmix
#    apply_patch file://${top_dir}/jackmix-qt5.patch
    scons
    do_make
  cd ..
}

build_libvorbis() {
  generic_download_and_install http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.5.tar.gz libvorbis-1.3.5
  cd libvorbis-1.3.5

  cd ..
}

build_libspeex() {
  do_git_checkout https://github.com/xiph/speex.git speex
  cd speex
    generic_configure_make_install "LIBS=-lwinmm --enable-binaries"

  cd ..
#  generic_download_and_install http://downloads.xiph.org/releases/speex/speex-1.2rc2.tar.gz speex-1.2rc2 "LIBS=-lwinmm --enable-binaries"
}

build_libspeexdsp() {
  do_git_checkout https://github.com/xiph/speexdsp.git speexdsp
  cd speexdsp
    generic_configure_make_install

  cd ..
#  generic_download_and_install http://downloads.xiph.org/releases/speex/speexdsp-1.2rc3.tar.gz speexdsp-1.2rc3
}

build_libtheora() {
#  original_cpu_count=$cpu_count
#  cpu_count=1 # can't handle it
#  download_and_unpack_file http://downloads.xiph.org/releases/theora/libtheora-1.2.0alpha1.tar.gz libtheora-1.2.0alpha1
#  cd libtheora-1.2.0alpha1
#    download_config_files
#    cd examples
#    apply_patch https://raw.githubusercontent.com/Warblefly/multimediaWin64/master/encoder_example.c.patch
#    cd ..
    do_svn_checkout http://svn.xiph.org/trunk/theora theora
    cd theora
      apply_patch file://${top_dir}/theora-examples-encoder_example.c.patch
      # .def files of theora use CRLF line terminators, which makes the most recent
      # GNU binutils trigger a linker error
      # ...ldd: .libs/libtheoradec-1.dll.def:3: syntax error
      sed -i -e 's#\r##g' win32/xmingw32/libtheoradec-all.def
      sed -i -e 's#\r##g' win32/xmingw32/libtheoraenc-all.def
      generic_configure_make_install "--disable-examples" # Without this, one-time builds fail

    cd ..
  #generic_download_and_install http://downloads.xiph.org/releases/theora/libtheora-1.2.0alpha1.tar.gz libtheora-1.2.0alpha1
#  cpu_count=$original_cpu_count
}

build_sqlite() {
    generic_download_and_install https://sqlite.org/2019/sqlite-autoconf-3280000.tar.gz sqlite-autoconf-3280000 #  https://www.sqlite.org/snapshot/sqlite-snapshot-201811291200.tar.gz sqlite-snapshot-201811291200
}

build_medialibrary() {
	# New name change not reflected yet in VLC player
	do_git_checkout https://code.videolan.org/videolan/medialibrary.git medialibrary #42c330b4e38062c7a773f7c5ad4ff0c0a6984a08 # a86453015164df65b7dbcdbc01cf4220daffc8aa # 8ad8de92f159c9af63c876230062bdea9d18ed04 #21fa816f7e3ee4ae20b565c2665641ee91431234
	cd medialibrary
		git submodule init
		git submodule update
		# Header not included
		apply_patch file://${top_dir}/medialibrary.patch
		generic_configure_make_install "--without-libvlc"
	cd ..
}

build_libopenshotaudio() {
	do_git_checkout https://github.com/OpenShot/libopenshot-audio.git libopenshot-audio
	cd libopenshot-audio
		apply_patch file://${top_dir}/libopenshot-audio.patch
		mkdir -p build
		cd build
			do_cmake ../ && ${top_dir}/correct_headers.sh
			do_make
			do_make_install
		cd ..
	cd ..
}		

build_libopenshot() {
	do_git_checkout https://github.com/OpenShot/libopenshot.git libopenshot
	cd libopenshot
		mkdir -p build
		cd build
			do_cmake ../ "-DLIBOPENSHOT_AUDIO_INCLUDE_DIR=${mingw_w64_x86_64_prefix}/include/libopenshot-audio -DUNITTEST++_INCLUDE_DIR=${mingw_w64_x86_64_prefix}/include/UnitTest++" 
			${top_dir}/correct_headers.sh 
			do_make
			do_make_install
		cd ..
	cd ..
}

build_unittest() {
	do_git_checkout https://github.com/unittest-cpp/unittest-cpp.git unittest-cpp
	cd unittest-cpp
		do_cmake -DUTPP_INCLUDE_TESTS_IN_BUILD=OFF
		do_make
		do_make_install
	cd ..
}

build_libfilezilla() {
do_svn_checkout https://svn.filezilla-project.org/svn/libfilezilla/trunk libfilezilla 
    cd libfilezilla
        #apply_patch file://${top_dir}/libfilezilla-typo.patch
        export CC=x86_64-w64-mingw32-gcc
        export CXX=x86_64-w64-mingw32-g++
        export WINDRES=x86_64-w64-mingw32-windres
#        export orig_cpu_count=$cpu_count
#        export cpu_count=1
        generic_configure_make_install "--disable-shared --enable-static"
#        generic_download_and_install https://download.filezilla-project.org/libfilezilla/libfilezilla-0.19.3.tar.bz2 libfilezilla-0.19.3 "--disable-shared --enable-static"
        unset CC
        unset CXX
        unset WINDRES
#        export cpu_count=$orig_cpu_count
    cd ..
}

build_filezilla() {

  do_svn_checkout https://svn.filezilla-project.org/svn/FileZilla3/trunk filezilla #9530 #9450 # 9262 # 9056
#  download_and_unpack_file "https://dl3.cdn.filezilla-project.org/client/FileZilla_3.46.3_src.tar.bz2?h=oLc72s8yghgbX19g_lnNNw&x=1580289968" filezilla-3.46.3
  cd filezilla
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
    export WINDRES=x86_64-w64-mingw32-windres
#    export orig_cpu_count=$cpu_count
#    export cpu_count=1
    #env
    #apply_patch file://{$top_dir}/filezilla-install.patch
    #export CFLAGS="-g -O0 -Wall"
    rm -vf configure Makefile.in config.in
    apply_patch file://${top_dir}/filezilla-wxWidgets.patch
    apply_patch file://${top_dir}/filezilla-wx31.patch
    generic_configure_make_install "--disable-dependency-tracking"
#    unset CFLAGS
#   generic_download_and_install https://download.filezilla-project.org/client/FileZilla_3.44.2_src.tar.bz2 filezilla-3.44.2
    #unset CFLAGS
    unset CC
    unset CXX
    unset WINDRES
#   export cpu_count=$orig_cpu_count
  cd ..
}


build_libfribidi() {
  # generic_download_and_install http://fribidi.org/download/fribidi-0.19.5.tar.bz2 fribidi-0.19.5 # got report of still failing?
  #  download_and_unpack_file http://fribidi.org/download/fribidi-0.19.7.tar.bz2 fribidi-0.19.7
  download_and_unpack_file https://ftp.osuosl.org/pub/blfs/conglomeration/fribidi/fribidi-1.0.5.tar.bz2 fribidi-1.0.5
  cd fribidi-1.0.5
    # make it export symbols right...
#    apply_patch file://${top_dir}/fribidi.diff
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
  generic_download_and_install https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.gz libass-0.14.0
  sed -i.bak 's/-lass -lm/-lass -lfribidi -lfontconfig -lfreetype -lexpat -lpng -lm/' "$PKG_CONFIG_PATH/libass.pc"
}

build_gmp() {
  download_and_unpack_file https://gmplib.org/download/gmp/gmp-6.1.2.tar.bz2 gmp-6.1.2
  cd gmp-6.1.2
#    export CC_FOR_BUILD=/usr/bin/gcc
#    export CPP_FOR_BUILD=usr/bin/cpp
    apply_patch file://${top_dir}/gmp-exeext.patch
    rm configure
    rm Makefile.in
    rm config.in
    generic_configure "ABI=$bits_target --disable-static --enable-shared"
#    unset CC_FOR_BUILD
#    unset CPP_FOR_BUILD
    do_make_install

  cd ..
}

build_orc() {
#	download_and_unpack_file http://download.videolan.org/contrib/orc-0.4.18.tar.gz orc-0.4.18
#	  cd orc-0.4.18
#		  apply_patch file://${top_dir}/orc-no-examples.patch
#		  rm configure Makefile.in
#		  generic_configure_make_install
#	  cd ..
	download_and_unpack_file https://github.com/GStreamer/orc/archive/0.4.30.tar.gz orc-0.4.30
	cd orc-0.4.30
	apply_patch file://${top_dir}/orc-cc.patch
		generic_meson_ninja_install
	cd ..
}

build_libxml2() {
  do_git_checkout https://github.com/GNOME/libxml2.git libxml2
#  download_and_unpack_file https://github.com/GNOME/libxml2/archive/v2.9.9-rc2.tar.gz libxml2-2.9.9-rc2
  cd libxml2 # -2.9.9-rc2
    # Remove libxml2 autogen because it sets variables that interfere with our cross-compile
#    rm -v autogen.sh
    generic_configure_make_install "LIBS=-lws2_32 --without-python --enable-ipv6"
    sed -i.bak 's/-lxml2.*$/-lxml2 -lws2_32/' "$PKG_CONFIG_PATH/libxml-2.0.pc" # Shared applications need Winsock
#    cp -v ${mingw_w64_x86_64_prefix}/bin/xml2-config ${mingw_w64_x86_64_prefix}/bin/x86_64-w64-mingw32-xml2-config

  cd ..
#  generic_download_and_install ftp://xmlsoft.org/libxml2/libxml2-2.9.2.tar.gz libxml2-2.9.2 "--without-python"
}

build_libxslt() {
  do_git_checkout https://github.com/GNOME/libxslt.git libxslt
#  cd libxslt-1.1.28/libxslt
#      apply_patch https://raw.githubusercontent.com/Warblefly/multimediaWin64/master/libxslt-security.c.patch
#    cd ..
    export LIBS="-lxml2"
    export LDFLAGS="-L${mingw_w64_x86_64_prefix}/lib"
  cd libxslt
#    export CFLAGS="-DLIBXML_STATIC -DLIBXSLT_STATIC -DLIBEXSLT_STATIC"
    sed -i.bak 's/doc \\/ \\/' Makefile.am
    # The Makefile.am forgets that libtool can't build a shared plugin library without -no-undefined
    sed -i.bak 's/xmlsoft_org_xslt_testplugin_la_LDFLAGS = -module -avoid-version -rpath $(plugindir)/xmlsoft_org_xslt_testplugin_la_LDFLAGS = -module -avoid-version -rpath $(plugindir) -no-undefined/' tests/plugins/Makefile.am
    generic_configure_make_install "--disable-silent-rules --without-python --with-libxml-src=../libxml2"

    unset CFLAGS
    unset LIBS
    unset LDFLAGS
  cd ..
}

build_libxmlsec() {
#  download_and_unpack_file http://www.aleksey.com/xmlsec/download/xmlsec1-1.2.25.tar.gz xmlsec1-1.2.25
  do_git_checkout https://github.com/lsh123/xmlsec.git xmlsec
  cd xmlsec
    apply_patch file://${top_dir}/xmlsec1-x509.patch
    export GCRYPT_LIBS=-lgcrypt
    export LIBS=-lgcrypt
    CFLAGS_ORIG=${CFLAGS}
    #env
    rm autogen.sh
#    generic_configure_make_install "LIBS=-lgcrypt --disable-silent-rules GCRYPT_LIBS=-lgcrypt --with-gcrypt=${mingw_w64_x86_64_prefix} --disable-silent-rules --enable-docs=no"
    generic_configure_make_install "LIBS=-lcrypt32 CFLAGS=-DGPGRT_ENABLE_ES_MACROS --disable-silent-rules --enable-docs=no --disable-mscng"


    unset LIBS
    unset GCRYPT_LIBS
  cd ..
}

build_libaacs() {
  do_git_checkout https://code.videolan.org/videolan/libaacs.git libaacs
  cd libaacs
    generic_configure_make_install "CFLAGS=-DGPGRT_ENABLE_ES_MACROS --with-libgcrypt-prefix=${mingw_w64_x86_64_prefix} --with-gpg-error-prefix=${mingw_w64_x86_64_prefix}"
  cd ..
}

build_libbdplus() {
  do_git_checkout http://code.videolan.org/videolan/libbdplus.git libbdplus
  cd libbdplus
    apply_patch file://${top_dir}/libbdplus-dirs_win32.c.patch
    generic_configure_make_install "CFLAGS=-DGPGRT_ENABLE_ES_MACROS --with-libaacs --with-libgcrypt-prefix=${mingw_w64_x86_64_prefix} --with-gpg-error-prefix=${mingw_w64_x86_64_prefix}"

  cd ..
}

build_libbluray() {
  do_git_checkout https://code.videolan.org/videolan/libbluray.git libbluray  #e0bfb98d042d0c907fa8a78f8fa2e3c3515d5ff9
  cd libbluray
    git submodule init
    git submodule update
    cd contrib/libudfread
    # Overcome invalid detection of MSVC when using MinGW
    apply_patch file://${top_dir}/libudfread-udfread-c.patch
    cd ../..
    #apply_patch file://${top_dir}/libbluray-java.patch
    generic_configure_make_install "--disable-silent-rules --disable-bdjava-jar" #"--disable-bdjava"

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

build_icu() {
  # First, build native ICU, whose build tools are required by cross-compiled ICU
  # Luckily, we do this only once per build.
  if [ ! -f icu.built ]; then
    download_and_unpack_file https://kent.dl.sourceforge.net/project/icu/ICU4C/62.1/icu4c-62_1-src.tgz icu
    holding_path=$PATH
    export PATH=$original_path
    mv icu icu_native
    cd icu_native
      #apply_patch file://${top_dir}/icu_native-xlocale.patch
      cd source
      #env
      # These might be set. They shouldn't be.
        unset AR
        unset LD
        unset CC
        unset CXX
        do_configure
        do_make || exit 1
      # Don't install this
    cd ../..
    export PATH=$holding_path
    download_and_unpack_file https://kent.dl.sourceforge.net/project/icu/ICU4C/62.1/icu4c-62_1-src.tgz icu
    mv icu icu_plain
    cd icu_plain
      # ICU 58.2 uses a pair of locale-related functiont that don't occur in mingw yet
      #apply_patch file://${top_dir}/icu-59.patch
    cd ..
    cd icu_plain/source
        export CFLAGS_ORIG=${CFLAGS}
        export CXXFLAGS_ORIG=${CXXFLAGS}
        export CFLAGS="-fpermissive -DWINVER=0x0A00 -DMINGW_HAS_SECURE_API=1"
        export CXXFLAGS="-fpermissive -DWINVER=0x0A00 -DMINGW_HAS_SECURE_API=1"
        generic_configure_make_install "--host=x86_64-w64-mingw32 --with-cross-build=${top_dir}/sandbox/x86_64/icu_native/source"
        export CFLAGS=${CFLAGS_ORIG}
        export CXXFLAGS=${CXXFLAGS_ORIG}
      cd ..

    cd ..
    touch icu.built
  else
    echo "ICU is already built."
  fi
  # The ICU libraries are made without the prefix 'lib'. Also, the version is missing from the link library. Let's correct that.
  cp -v ${mingw_w64_x86_64_prefix}/lib/icudt.dll ${mingw_w64_x86_64_prefix}/lib/libicudt.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icudt62.dll ${mingw_w64_x86_64_prefix}/lib/libicudt62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuin.dll ${mingw_w64_x86_64_prefix}/lib/libicuin.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuin62.dll ${mingw_w64_x86_64_prefix}/lib/libicuin62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuio.dll ${mingw_w64_x86_64_prefix}/lib/libicuio.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuio62.dll ${mingw_w64_x86_64_prefix}/lib/libicuio62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutest.dll ${mingw_w64_x86_64_prefix}/lib/libicutest.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutest62.dll ${mingw_w64_x86_64_prefix}/lib/libicutest62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutu.dll ${mingw_w64_x86_64_prefix}/lib/libicutu.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutu62.dll ${mingw_w64_x86_64_prefix}/lib/libicutu62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuuc.dll ${mingw_w64_x86_64_prefix}/lib/libicuuc.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuuc61.dll ${mingw_w64_x86_64_prefix}/lib/libicuuc62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicudt.dll.a ${mingw_w64_x86_64_prefix}/lib/libicudt62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicuin.dll.a ${mingw_w64_x86_64_prefix}/lib/libicuin62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicuio.dll.a ${mingw_w64_x86_64_prefix}/lib/libicuio62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicutest.dll.a ${mingw_w64_x86_64_prefix}/lib/libicutest62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicutu.dll.a ${mingw_w64_x86_64_prefix}/lib/libicutu62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicuuc.dll.a ${mingw_w64_x86_64_prefix}/lib/libicuuc62.dll.a
}

build_icu_with_iculehb() {
  # Native ICU has already been built
  if [ ! -f icu-hb.built ]; then
    download_and_unpack_file https://kent.dl.sourceforge.net/project/icu/ICU4C/62.1/icu4c-62_1-src.tgz icu
    cd icu
      # ICU 58.2 uses a pair of locale-related functiont that don't occur in mingw yet
      #apply_patch file://${top_dir}/icu-59.patch
    cd ..
    cd icu/source
        export CFLAGS_ORIG=${CFLAGS}
        export CXXFLAGS_ORIG=${CXXFLAGS}
        export CFLAGS="-fpermissive -DWINVER=0x0A00 -DMINGW_HAS_SECURE_API=1"
        export CXXFLAGS="-fpermissive -DWINVER=0x0A00 -DMINGW_HAS_SECURE_API=1"
        generic_configure_make_install "--enable-extras --enable-icuio --enable-layoutex --host=x86_64-w64-mingw32 --with-cross-build=${top_dir}/sandbox/x86_64/icu_native/source"
        export CFLAGS=${CFLAGS_ORIG}
        export CXXFLAGS=${CXXFLAGS_ORIG}
      cd ..

    cd ..
    touch icu-hb.built
  else
    echo "ICU with Harfbuzz is already built."
  fi
    # The ICU libraries are made without the prefix 'lib'. Also, the version is missing from the link library. Let's correct that.
  cp -v ${mingw_w64_x86_64_prefix}/lib/icudt.dll ${mingw_w64_x86_64_prefix}/lib/libicudt.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icudt62.dll ${mingw_w64_x86_64_prefix}/lib/libicudt62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuin.dll ${mingw_w64_x86_64_prefix}/lib/libicuin.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuin62.dll ${mingw_w64_x86_64_prefix}/lib/libicuin62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuio.dll ${mingw_w64_x86_64_prefix}/lib/libicuio.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuio62.dll ${mingw_w64_x86_64_prefix}/lib/libicuio62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutest.dll ${mingw_w64_x86_64_prefix}/lib/libicutest.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutest62.dll ${mingw_w64_x86_64_prefix}/lib/libicutest62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutu.dll ${mingw_w64_x86_64_prefix}/lib/libicutu.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icutu62.dll ${mingw_w64_x86_64_prefix}/lib/libicutu62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuuc.dll ${mingw_w64_x86_64_prefix}/lib/libicuuc.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/icuuc62.dll ${mingw_w64_x86_64_prefix}/lib/libicuuc62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicudt.dll.a ${mingw_w64_x86_64_prefix}/lib/libicudt62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicuin.dll.a ${mingw_w64_x86_64_prefix}/lib/libicuin62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicuio.dll.a ${mingw_w64_x86_64_prefix}/lib/libicuio62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicutest.dll.a ${mingw_w64_x86_64_prefix}/lib/libicutest62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicutu.dll.a ${mingw_w64_x86_64_prefix}/lib/libicutu62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/libicuuc.dll.a ${mingw_w64_x86_64_prefix}/lib/libicuuc62.dll.a
  cp -v ${mingw_w64_x86_64_prefix}/lib/iculx.dll ${mingw_w64_x86_64_prefix}/lib/libiculx.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/iculx62.dll ${mingw_w64_x86_64_prefix}/lib/libiculx62.dll
  cp -v ${mingw_w64_x86_64_prefix}/lib/libiculx.dll.a ${mingw_w64_x86_64_prefix}/lib/libiculx62.dll.a
}



build_libunistring() {
  generic_download_and_install http://ftp.gnu.org/gnu/libunistring/libunistring-0.9.9.tar.xz libunistring-0.9.9 "LIBS=-lpthread"
  cd libunistring-0.9.9

  cd ..
}

build_libffi() {
  generic_download_and_install ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz libffi-3.2.1
  cd libffi-3.2.1

  cd ..
}

build_libatomic_ops() {
  generic_download_and_install http://www.ivmaisoft.com/_bin/atomic_ops/libatomic_ops-7.6.4.tar.gz libatomic_ops-7.6.4
  cd libatomic_ops-7.6.4

  cd ..
}

build_bdw-gc() {
  generic_download_and_install http://www.hboehm.info/gc/gc_source/gc-7.6.6.tar.gz gc-7.6.6
  cd gc-7.6.6

  cd ..
}

build_guile() {
  generic_download_and_install ftp://ftp.gnu.org/pub/gnu/guile/guile-2.0.14.tar.xz guile-2.0.14
  cd guile-2.0.14

  cd ..
}

build_autogen() {
  generic_download_and_install http://ftp.gnu.org/gnu/autogen/rel5.18.12/autogen-5.18.12.tar.xz autogen-5.18.12
  cd autogen-5.18.12

  cd ..
}

build_liba52() {
  export CFLAGS=-std=gnu89
  generic_download_and_install https://ba.mirror.garr.it/mirrors/OpenBSD/distfiles/a52dec-snapshot.tar.gz a52dec-0.7.5-cvs
  cd a52dec-0.7.5-cvs

  cd ..
  export CFLAGS=${original_cflags}
}

build_p11kit() {
#  generic_download_and_install https://p11-glue.freedesktop.org/releases/p11-kit-0.23.2.tar.gz p11-kit-0.23.2
  do_git_checkout https://github.com/p11-glue/p11-kit.git p11-kit f00183944fad943216ac5842f6b23ab5c4149e50
  cd p11-kit
    generic_configure_make_install
  cd ..
#  cd p11-kit-0.23.2
}

build_libidn2() {
  do_git_checkout https://github.com/libidn/libidn2.git libidn2 # 301a43b5ac41f0fbea41d70444c0942ae93624cd
  cd libidn2
    generic_configure_make_install

  cd ..
}

build_xerces() {
	download_and_unpack_file http://mirrors.ukfast.co.uk/sites/ftp.apache.org//xerces/c/3/sources/xerces-c-3.2.2.tar.xz xerces-c-3.2.2
	cd xerces-c-3.2.2
		do_cmake && ${top_dir}/correct_headers.sh
		do_make
		do_make_install
	cd ..
}

build_gnutls() {
#  download_and_unpack_file https://www.gnupg.org/ftp/gcrypt/gnutls/v3.3/gnutls-3.3.27.tar.xz gnutls-3.3.27
   # do_git_checkout https://gitlab.com/gnutls/gnutls.git gnutls
  download_and_unpack_file https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/gnutls-3.6.12.tar.xz gnutls-3.6.12
  cd gnutls-3.6.12
#    git submodule init
#    git submodule update
    make autoreconf
    generic_configure "--enable-openssl-compatibility --disable-doc --enable-local-libopts --disable-libdane --with-zlib --enable-cxx --enable-nls" # --disable-cxx --disable-doc --without-p11-kit --disable-local-libopts --disable-libopts-install --with-included-libtasn1" # don't need the c++ version, in an effort to cut down on size... XXXX test difference...
    do_make_install

  cd ..
  sed -i.bak 's/-lgnutls *$/-lgcrypt -lgnutls -lnettle -lhogweed -lgmp -lcrypt32 -lws2_32 -liconv/' "$PKG_CONFIG_PATH/gnutls.pc"
  # For some reason, libraries that conflict with mingw-w64-crt are provided. These must go.
  rm -v ${mingw_w64_x86_64_prefix}/lib/crypt32{.a,.dll.a,.dll}
  rm -v ${mingw_w64_x86_64_prefix}/lib/ncrypt{.a,.dll.a,.dll}
}

build_libnettle() {
  download_and_unpack_file https://ftp.gnu.org/gnu/nettle/nettle-3.5.1.tar.gz nettle-3.5.1
  cd nettle-3.5.1
    generic_configure # "--disable-openssl" # in case we have both gnutls and openssl, just use gnutls [except that gnutls uses this so...huh? https://github.com/rdp/ffmpeg-windows-build-helpers/issues/25#issuecomment-28158515
    do_make_install

  cd ..
}

build_bzlib2() {
  download_and_unpack_file https://web.archive.org/web/20180624184806/http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz bzip2-1.0.6
  cd bzip2-1.0.6
    if [ ! -f bzip2.built ]; then
  # These are MinGW autotools files
      cp $top_dir/bzip2-1.0.6/* .
      autoreconf -fvi
      generic_configure "--disable-static --enable-shared"
      # The following patch is already included in bzip-2-cygming.patch
      # There is a backslash as a directory separator in a pre-processor call
#      apply_patch file://$top_dir/bzip2_cross_compile.diff
      apply_patch file://${top_dir}/bzip-2-cygming.patch
      apply_patch file://${top_dir}/bzip2-1.0.6-progress.patch
      do_make
      do_make_install
      touch bzip2.built
#    do_make "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar PREFIX=$mingw_w64_x86_64_prefix RANLIB=$(echo $cross_prefix)ranlib libbz2.a bzip2 bzip2recover install"
#  cd ..
#  mv $mingw_w64_x86_64_prefix/bin/bzip2  $mingw_w64_x86_64_prefix/bin/bzip2.exe
#  mv $mingw_w64_x86_64_prefix/bin/bunzip2  $mingw_w64_x86_64_prefix/bin/bunzip2.exe
#  mv $mingw_w64_x86_64_prefix/bin/bzcat  $mingw_w64_x86_64_prefix/bin/bzcat.exe
#  mv $mingw_w64_x86_64_prefix/bin/bzip2recover  $mingw_w64_x86_64_prefix/bin/bzip2recover.exe
#  mv $mingw_w64_x86_64_prefix/bin/bzgrep  $mingw_w64_x86_64_prefix/bin/bzgrep.exe
#  mv $mingw_w64_x86_64_prefix/bin/bzmore  $mingw_w64_x86_64_prefix/bin/bzmore.exe
#  mv $mingw_w64_x86_64_prefix/bin/bzdiff  $mingw_w64_x86_64_prefix/bin/bzdiff.exe
#  rm $mingw_w64_x86_64_prefix/bin/bzegrep  $mingw_w64_x86_64_prefix/bin/bzfgrep  $mingw_w64_x86_64_prefix/bin/bzless $mingw_w64_x86_64_prefix/bin/bzcmp
#  cp $mingw_w64_x86_64_prefix/bin/bzgrep.exe $mingw_w64_x86_64_prefix/bin/bzegrep.exe
#  cp $mingw_w64_x86_64_prefix/bin/bzgrep.exe $mingw_w64_x86_64_prefix/bin/bzfgrep.exe
#  cp $mingw_w64_x86_64_prefix/bin/bzmore.exe $mingw_w64_x86_64_prefix/bin/bzless.exe
#  cp $mingw_w64_x86_64_prefix/bin/bzdiff.exe $mingw_w64_x86_64_prefix/bin/bzcmp.exe
   else
     echo "bzip2 already built."
   fi
  cd ..
}

build_zlib() {
  download_and_unpack_file http://zlib.net/zlib-1.2.11.tar.gz zlib-1.2.11
  cd zlib-1.2.11
    export mingw_w64_x86_64_prefix=${mingw_w64_x86_64_prefix}
    echo "PKG_CONFIG_PATH at this point is ${PKG_CONFIG_PATH}"
    apply_patch file://${top_dir}/zlib-Makefile-gcc.patch
#    cp win32/Makefile.gcc Makefile
#    do_make_install
    # Zlib's paths in the pkgconfig file aren't absolute, and libtool won't process these
    sed -i.bak 's|libdir=lib/|libdir=${prefix}/lib/|' $PKG_CONFIG_PATH/zlib.pc
    sed -i.bak 's|sharedlibdir=lib/|sharedlibdir=${prefix}/lib/|' $PKG_CONFIG_PATH/zlib.pc
#    do_configure "--static --prefix=$mingw_w64_x86_64_prefix"
#    do_make_install "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar RANLIB=$(echo $cross_prefix)ranlib ARFLAGS=rcs"
    do_configure "--shared --prefix=${mingw_w64_x86_64_prefix}"
    do_make_install "CC=${cross_prefix}gcc AR=${cross_prefix}ar RC=${cross_prefix}windres RANLIB=${cross_prefix}ranlib STRIP=${cross_prefix}strip IMPLIB=libz.dll.a -f win32/Makefile.gcc"

  cd ..
}

build_libxvid() {
  download_and_unpack_file http://downloads.xvid.org/downloads/xvidcore-1.3.5.tar.gz xvidcore
  cd xvidcore/build/generic
  if [ "$bits_target" = "64" ]; then
    local config_opts="--build=x86_64-unknown-linux-gnu --disable-assembly" # kludgey work arounds for 64 bit
  fi
  do_configure "--host=$host_target --prefix=$mingw_w64_x86_64_prefix $config_opts" # no static option...
  sed -i.bak "s/-mno-cygwin//" platform.inc # remove old compiler flag that now apparently breaks us

  cpu_count=1 # possibly can't build this multi-thread ? http://betterlogic.com/roger/2014/02/xvid-build-woe/
  do_make_install
  cpu_count=$original_cpu_count
  cd ../..

  cd ..

  # force a static build after the fact by only installing the .a file
#  if [[ -f "$mingw_w64_x86_64_prefix/lib/xvidcore.dll.a" ]]; then
#    rm $mingw_w64_x86_64_prefix/lib/xvidcore.dll.a || exit 1
#    mv $mingw_w64_x86_64_prefix/lib/xvidcore.a $mingw_w64_x86_64_prefix/lib/libxvidcore.a || exit 1
#  fi
}

build_fontconfig() {
  download_and_unpack_file https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.13.92.tar.xz fontconfig-2.13.92
  cd fontconfig-2.13.92
    export LDFLAGS="-lintl -liconv"
    apply_patch file://${top_dir}/fontconfig-cross.patch
    rm configure && rm Makefile.in
    generic_configure "--disable-docs --disable-silent-rules"
    do_make_install
    unset LDFLAGS

  cd ..
  sed -i.bak 's/-L${libdir} -lfontconfig[^l]*$/-L${libdir} -lfontconfig -lfreetype -lintl -liconv -lexpat -lz/' "$PKG_CONFIG_PATH/fontconfig.pc"
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
  download_and_unpack_file https://www.openssl.org/source/openssl-1.0.2u.tar.gz openssl-1.0.2u
#  download_and_unpack_file https://www.openssl.org/source/openssl-1.1.0f.tar.gz openssl-1.1.0f
  # When the manpages are written, they need somewhere to go otherwise there is an error.
  mkdir -pv ${mingw_w64_x86_64_prefix}/include/openssl
  mkdir -pv ${mingw_w64_x86_64_prefix}/lib/engines
  mkdir -pv ${mingw_w64_x86_64_prefix}/ssl/misc
  cd openssl-1.0.2u
  #env
  # apply_patch file://${top_dir}/openssl-1.1.0f.patch
  #export cross="${cross_prefix}"
  export CROSS_COMPILE="${cross_prefix}"
  export PERL="/usr/bin/perl"
  #export CC="x86_64-w64-mingw32-gcc"
  #export AR="x86_64-w64-mingw32-ar"
  #export RANLIB="x86_64-w64-mingw32-ranlib"
  #:export RC="x86_64-w64-mingw32-windres"
  #XXXX do we need no-asm here?
  # apply_patch_p1 https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-openssl/openssl-0.9.6-x509.patch
  #if [ "$bits_target" = "32" ]; then
  #  do_configure "--prefix=$mingw_w64_x86_64_prefix shared mingw" ./Configure
  #else
  do_configure "--prefix=$mingw_w64_x86_64_prefix zlib shared no-capieng mingw64" ./Configure
  #fi
  #do_configure "" ./config
#  cpu_count=1
  sleep 3
  do_make # "build_libs"
  do_make "install_sw"
#  cpu_count=$original_cpu_count
  unset cross
  unset CC
  unset AR
  unset RANLIB
  unset RC
  unset CROSS_COMPILE
  unset PERL
  # do_cleanup
  cd ..
}

build_libssh() {
  download_and_unpack_file https://www.libssh.org/files/0.8/libssh-0.8.3.tar.xz libssh-0.8.3
#  do_git_checkout git://git.libssh.org/projects/libssh.git libssh
  export CMAKE_INCLUDE_PATH=${mingw_w64_x86_64_prefix}/include
  mkdir libssh_build
  cd libssh-0.8.3
#    apply_patch file://${top_dir}/libssh-win32.patch
#    apply_patch file://${top_dir}/libssh-ctx-fix.patch
     apply_patch file://${top_dir}/libssh-zlib.patch
  cd ..
  cd libssh_build
    local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")
    if [ ! -f $touch_name ]; then
      export ZLIB_ROOT_DIR=${mingw_w64_x86_64_prefix}
      echo doing cmake in ../libssh-0.8.3 with PATH=$PATH  with extra_args=$extra_args like this:
      echo cmake ../libssh-0.8.3 -DCMAKE_C_FLAGS=-DGPGRT_ENABLE_ES_MACROS -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix -DWITH_GCRYPT=ON $extra_args || exit 1
      cmake ../libssh-0.8.3 -DCMAKE_C_FLAGS=-DGPGRT_ENABLE_ES_MACROS -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix -DWITH_GCRYPT=ON $extra_args || exit 1
      do_make
      do_make_install

      touch $touch_name || exit 1
    fi
  cd ..
}

build_asdcplib-cth() {
   # Use brance cth because this is the version the writer works on, and has modified
  do_git_checkout git://git.carlh.net/git/asdcplib.git asdcplib-carl carl
#  download_and_unpack_file http://carlh.net/downloads/asdcplib-cth/libasdcp-cth-0.1.1.tar.bz2 libasdcp-cth-0.1.1
  cd asdcplib-carl
    export PKG_CONFIG_PATH=${mingw_w64_x86_64_prefix}/lib/pkgconfig
    export CXXFLAGS="-DKM_WIN32"
    export CFLAGS="-DKM_WIN32"
    export LIBS="-lws2_32 -lcrypto -lssl -lgdi32 -lboost_filesystem-mt-x64 -lboost_system-mt-x64"
    apply_patch file://${top_dir}/asdcplib-cth-wscript.patch
    apply_patch file://${top_dir}/asdcplib-cth-snprintf.patch
    # Don't look for boost libraries ending in -mt -- all our libraries are multithreaded anyway
    #sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" wscript
#    sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" test/wscript
    export CC=x86_64-w64-mingw32-g++
    export CXX=x86_64-w64-mingw32-g++
    export AR=x86_64-w64-mingw32-ar
    do_configure "configure -v -pp --prefix=${mingw_w64_x86_64_prefix} --libdir=${mingw_w64_x86_64_prefix}/lib --target-windows --check-cxx-compiler=gxx" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
        # The installation puts the pkgconfig file and the import DLL in the wrong place
    cp -v build/libasdcp-carl.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    cp -v build/src/libasdcp-carl.dll.a ${mingw_w64_x86_64_prefix}/lib
    cp -v build/src/libkumu-carl.dll.a ${mingw_w64_x86_64_prefix}/lib
    unset CXX
    unset CC
    unset AR
    unset CXXFLAGS
    unset CFLAGS
    unset LIBS
  cd ..
}

build_libdcp() {
  # Branches are slightly askew. 1.0 is where development takes place
  do_git_checkout https://github.com/cth103/libdcp.git libdcp # f3058b2f1b48ec613bda5781fe97e83a0dca83a9
#  do_git_checkout git://git.carlh.net/git/libdcp.git libdcp # 3bd9acd5cd3bf5382ad79c295ec9d9aca828dc32
#  download_and_unpack_file https://carlh.net/downloads/libdcp/libdcp-1.6.13.tar.bz2 libdcp-1.6.13
  cd libdcp
    # M_PI is required. This is a quick way of defining it
    sed -i.bak 's/M_PI/3.14159265358979323846/' examples/make_dcp.cc
    # Don't look for boost libraries ending in -mt -- all our libraries are multithreaded anyway
    #sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" wscript
    #sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" test/wscript
#    apply_patch file://${top_dir}/libdcp-libxml.patch
    apply_patch file://${top_dir}/libdcp-boost.patch
    apply_patch file://${top_dir}/libdcp-gm.patch
#    apply_patch_p1 "http://main.carlh.net/gitweb/?p=libdcp.git;a=patch;h=730ba2273b136ad5a3bfc1a185d69e6cc50a65af"
    export CXX=x86_64-w64-mingw32-g++
    do_configure "configure -v -pp --prefix=${mingw_w64_x86_64_prefix} --target-windows --check-cxx-compiler=gxx --enable-debug --disable-tests" "./waf" # --disable-gcov
    ./waf build || exit 1
    ./waf install || exit 1
    unset CXX
        # The installation puts the pkgconfig file and the DLL import file in the wrong place
    cp -v build/libdcp-1.0.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    #sed -i.bak 's/1\.4\.4devel/1.4.4/' ${mingw_w64_x86_64_prefix}/lib/pkgconfig/libdcp-1.0.pc
    cp -v build/libdcp.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig/libdcp.pc
    cp -v build/src/libdcp.dll.a ${mingw_w64_x86_64_prefix}/lib
    cd ${mingw_w64_x86_64_prefix}/include
      ln -s libdcp-1.0/dcp libdcp
    cd -
  cd ..
}

build_libsub() {
#  do_git_checkout git://git.carlh.net/git/libsub.git libsub 1.0
  do_git_checkout https://git.carlh.net/git/libsub.git libsub
#  download_and_unpack_file http://carlh.net/downloads/libsub/libsub-1.2.4.tar.bz2 libsub-1.2.4
  cd libsub
    # include <iostream> is missing
    apply_patch file://${top_dir}/libdcp-reader.h.patch
#    apply_patch file://${top_dir}/libsub-2-iostream.patch
#    apply_patch file://${top_dir}/libdcp-sub_time.h.patch
#    apply_patch file://${top_dir}/libsub-asdcplib-h__Writer.cpp.patch
    # Our Boost libraries are multithreaded anyway
    #sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" wscript
    # The version in the development tree doesn't have an updated version number
#    sed -i.bak "s/1\.1\.0devel/1.2.4/" wscript
    apply_patch file://${top_dir}/libsub-wscript.patch
    #sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" test/wscript
    # iostream header is needed for std::cout objects
#    apply_patch file://${top_dir}/libsub_iostream.patch
    export CXX=x86_64-w64-mingw32-g++
    # I thought this was actually the default, but no?
    export CXXFLAGS="-std=c++11 -fpermissive"
    do_configure "configure -v -pp --prefix=${mingw_w64_x86_64_prefix} --target-windows --check-cxx-compiler=gxx --disable-tests" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
    unset CXX
    export CXXFLAGS=$original_cxxflags
    # The import library and the pkg-config file go into the wrong place
    cp -v build/libsub-1.0.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    cp -v build/src/libsub-1.0.dll.a ${mingw_w64_x86_64_prefix}/lib
  cd ..
}

build_intel_quicksync_mfx() { # qsv
  do_git_checkout https://github.com/lu-zero/mfx_dispatch.git mfx_dispatch_git
  cd mfx_dispatch_git
    sed -i.bak 's/-version-info/-no-undefined -version-info/' Makefile.am
#    sed -i.bak 's/-DMINGW_HAS_SECURE_API=1//' Makefile.am
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
    fi
    generic_configure_make_install

  cd ..
}

build_libnvenc() {
  if [[ ! -f $mingw_w64_x86_64_prefix/include/nvEncodeAPI.h ]]; then
#    rm -rf nvenc # just in case :)
#    mkdir nvenc
#    cd nvenc
#      echo "installing nvenc [nvidia gpu assisted encoder]"
#      curl --retry 5 -4 http://developer.download.nvidia.com/assets/cuda/files/nvidia_video_sdk_6.0.1.zip -O -L --fail || exit 1
#      unzip nvidia_video_sdk_6.0.1.zip
#      cp nvidia_video_sdk_6.0.1/Samples/common/inc/* $mingw_w64_x86_64_prefix/include
#    cd ..

    rm  -rf nvenc
    mkdir nvenc
    cd nvenc
      echo "Installing nvend [nvidia gnu assisted encoder]"
      tar xvvf ${top_dir}/nvidia-sdk-headers-8.0.14.tar.xz
      cp -Rv nvidia-sdk-headers-8.0.14/inc/* ${mingw_w64_x86_64_prefix}/include
    cd ..
  else
    echo "already installed nvenc"
  fi
}

build_fdk_aac() {
  #generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-0.1.0.tar.gz/download fdk-aac-0.1.0
  do_git_checkout https://github.com/mstorsjo/fdk-aac.git fdk-aac_git # e45ae429b9ca8f234eb861338a75b2d89cde206a
  cd fdk-aac_git
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
    fi
    generic_configure_make_install "CXXFLAGS=-Wno-narrowing --enable-example=yes --disable-silent-rules"

  cd ..
}


build_libexpat() {
  do_git_checkout https://github.com/libexpat/libexpat.git libexpat
 # generic_download_and_install http://downloads.sourceforge.net/project/expat/expat/2.2.5/expat-2.2.5.tar.bz2 expat-2.2.5
  cd libexpat/expat
    generic_configure_make_install
  cd ../..
}

build_ladspa() {
  curl -vo "${mingw_w64_x86_64_prefix}/include/ladspa.h" https://raw.githubusercontent.com/swh/ladspa/master/ladspa.h
}

build_libfftw() {
#  generic_download_and_install http://www.fftw.org/fftw-3.3.7.tar.gz fftw-3.3.7 "--with-our-malloc16 --with-windows-f77-mangling --enable-threads --with-combined-threads --enable-portable-binary --enable-sse2 --with-incoming-stack-boundary=2"
  download_and_unpack_file http://www.fftw.org/fftw-3.3.8.tar.gz fftw-3.3.8
  cd fftw-3.3.8
      apply_patch file://${top_dir}/fftw-thread.patch
      generic_configure_make_install "--with-our-malloc16 --with-windows-f77-mangling --enable-threads --with-combined-threads --enable-portable-binary --enable-sse2 --with-incoming-stack-boundary=2"
  cd ..
  # Need to rename the static version for traverso
  ln -sv ${mingw_w64_x86_64_prefix}/lib/libfftw3.a ${mingw_w64_x86_64_prefix}/lib/libfftw3-3.a
}

build_libsamplerate() {
  do_git_checkout https://github.com/erikd/libsamplerate.git libsamplerate
  cd libsamplerate
    generic_configure_make_install

  cd ..
#  generic_download_and_install http://www.mega-nerd.com/SRC/libsamplerate-0.1.9.tar.gz libsamplerate-0.1.9
}

build_vamp-sdk() {
  export cpu_count=1
  do_git_checkout  https://github.com/c4dm/vamp-plugin-sdk.git vamp-plugin-sdk
  # download_and_unpack_file https://code.soundsoftware.ac.uk/attachments/download/2206/vamp-plugin-sdk-2.7.1.tar.gz vamp-plugin-sdk-2.7.1
  cd vamp-plugin-sdk
    # Tell the build system to use the mingw-w64 versions of binary utilities
    sed -i.bak 's/AR		= ar/AR		= x86_64-w64-mingw32-ar/' Makefile.in
    sed -i.bak 's/RANLIB		= ranlib/RANLIB		= x86_64-w64-mingw32-ranlib/' Makefile.in
    sed -i.bak 's/sdk plugins host rdfgen test/sdk plugins host rdfgen/' configure
    # M_PI doesn't get defined: it's not standard C++
    apply_patch file://${top_dir}/vamp-M_PI.patch
    apply_patch file://${top_dir}/vamp-configure.patch
    #apply_patch file://${top_dir}/vamp-mutex.patch
    # Vamp installs shared libraries. They confuse mpv's linker (I think)
    export SNDFILE_LIBS="-lsndfile -lspeex -logg -lspeexdsp -lFLAC -lvorbisenc -lvorbis -logg -lvorbisfile -logg -lFLAC++ -lsndfile"
    generic_configure_make_install
  #  do_cleanup
    unset SNDFILE_LIBS
  #  echo "Now executing rm -fv $mingw_w64_x86_64_prefix/lib/libvamp*.so*"
  #  rm -fv $mingw_w64_x86_64_prefix/lib/libvamp*.so*
    export cpu_count=$original_cpu_count
  cd ..
}

build_librubberband() {
  download_and_unpack_file https://code.breakfastquay.com/attachments/download/34/rubberband-1.8.2.tar.bz2 rubberband-1.8.2
  cd rubberband-1.8.2
##     sed -i.bak 's/:= ar/:= x86_64-w64-mingw32-ar/' Makefile.in
#     sed -i.bak 's#:= bin/rubberband#:= bin/rubberband.exe#' Makefile.in
#     export SNDFILE_LIBS="-lsndfile -lspeex -logg -lspeexdsp -lFLAC -lvorbisenc -lvorbis -logg -lvorbisfile -logg -lFLAC++ -lsndfile"
#     generic_configure
#     export cpu_count=1
#     do_make_install "AR=${cross_prefix}ar RANLIB=${cross_prefix}ranlib DYNAMIC_EXTENSION=.dll DYNAMIC_FULL_VERSION= DYNAMIC_ABI_VERSION="
#     unset SNDFILE_LIBS
     # The shared libraries must vanish
#     rm -fv ${mingw_w64_x86_64_prefix}/lib/librubberband*.so*
     # Need to force static linkers to link other libraries that rubberband depends on
#     sed -i.bak 's/-lrubberband/-lrubberband -lsamplerate -lfftw3 -lstdc++/' "$PKG_CONFIG_PATH/rubberband.pc"
#     export cpu_count=$original_cpu_count
    apply_patch_p1 https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-rubberband/01-mingw-shared.patch
    apply_patch file://${top_dir}/rubberband-exe.patch
    generic_configure_make_install

    #mv -v ${mingw_w64_x86_64_prefix}/bin/rubberband.exe ${mingw_w64_x86_64_prefix}/bin/rubberband.exe
  cd ..
}

build_iconv() {
  download_and_unpack_file http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.15.tar.gz libiconv-1.15
  cd libiconv-1.15
    # Apply patch to fix non-exported inline function in gcc-5.2.0
    #apply_patch file://${top_dir}/libiconv-1.14-iconv-fix-inline.patch
    # We also need an empty langinfo.h to compile this
#    touch $cur_dir/include/langinfo.h
    generic_configure_make_install

  cd ..
}

build_iconvgettext() {
  do_git_checkout git://git.savannah.gnu.org/libiconv.git libiconv
  cd libiconv
    apply_patch file://${top_dir}/libiconv-1.14-iconv-fix-inline.patch
    ./autogen.sh --skip-gnulib
    generic_configure_make_install

  cd ..
}

build_libgpg-error() {
  # We remove one of the .po files due to a bug in Cygwin's iconv that causes it to loop when converting certain character encodings
#  download_and_unpack_file ftp://ftp.gnupg.org/gcrypt/libgpg-error/libgpg-error-1.22.tar.bz2 libgpg-error-1.22
  do_git_checkout git://git.gnupg.org/libgpg-error.git libgpg-error # 12349de46d241cfbadbdf99773d6cabfcbc97578 # 78b679a778ddf37b8952f1808fd8c52cc8163f17
  cd libgpg-error
#    apply_patch file://${top_dir}/gpg-error-pid.patch
#    rm po/ro.* # The Romanian translation causes Cygwin's iconv to loop. This is a Cygwin bug.
    generic_configure_make_install "CC_FOR_BUILD=gcc --disable-doc --disable-tests" # "--prefix=${mingw_compiler_path/}" # This is so gpg-error-config can be seen by other programs
  cd ..
}

build_libgcrypt() {
#  generic_download_and_install ftp://ftp.gnupg.org/gcrypt/libgcrypt/libgcrypt-1.8.1.tar.gz libgcrypt-1.8.1 "GPG_ERROR_CONFIG=${mingw_w64_x86_64_prefix}/bin/gpg-error-config"
  do_git_checkout git://git.gnupg.org/libgcrypt.git libgcrypt #cdaeb86f067b94d9dff4235ade20dde6479d9bb8 # 86e5e06a97ae13b8bbf6923ecc76e02b9c429b46
  cd libgcrypt
  export holding_path="${PATH}"
  export PATH="/usr/bin:/bin:${top_dir}/sandbox/x86_64-w64-mingw32/bin"
    # apply_patch file://${top_dir}/libgcrypt-pkgconfig.patch
    generic_configure_make_install "CC_FOR_BUILD=gcc CFLAGS=-DGPGRT_ENABLE_ES_MACROS GPG_ERROR_CONFIG=${mingw_w64_x86_64_prefix}/bin/gpg-error-config GPGRT_CONFIG=${mingw_w64_x86_64_prefix}/bin/gpgrt-config --disable-doc"
#    echo "Installing pkg-config file because it's added by us"
#    cp -v src/libgcrypt.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
#  cd libgcrypt-1.8.1
#    do_cleanup
#  cd ..
  export PATH="${holding_path}"
  cd ..
}

build_tesseract() {
  do_git_checkout https://github.com/tesseract-ocr/tesseract tesseract fef64d795cdb0db5315c11f936b7efd1424994b2
  # Problem with latest tree and FFmpeg. Should be fixed soon
#  download_and_unpack_file https://github.com/tesseract-ocr/tesseract/archive/3.05.00dev.tar.gz tesseract-3.05.00dev
  cd tesseract
#    apply_patch file://${top_dir}/tesseract-thread.patch
#    apply_patch file://${top_dir}/tesseract-libgomp.patch
    export LIBLEPT_HEADERSDIR="${mingw_w64_x86_64_prefix}/include/leptonica"
    export LIBS="-larchive -ltiff -ljpeg -lpng -lwebp -lz" # -lboost_thread-mt-x64" # -lboost_thread_win32 -lboost_chrono"
    old_cxxflags="${CXXFLAGS}"
    export CXXFLAGS="-fpermissive"
    sed -i.bak 's/Windows.h/windows.h/' opencl/openclwrapper.cpp
    sed -i.bak 's/-ltesseract/-ltesseract -llept -larchive -ltiff -ljpeg -lpng -lwebp -lz/' tesseract.pc.in
    # Unpack English language tessdata into data directory
    # tar xvvf ${top_dir}/tessdata-snapshot-20150411.tar.xz
    generic_configure_make_install "--without-tensorflow --enable-maintainer-mode" #"--disable-openmp"

    unset LIBLEPT_HEADERSDIR
    unset LIBS
    export CXXFLAGS="${old_cxxflags}"
  cd ..
    # Fetch the training data
  mkdir -pv tessdata
  cd tessdata
    if [ ! -f tessdata.downloaded ]; then
      curl --location https://github.com/tesseract-ocr/tessdata/raw/master/osd.traineddata > osd.traineddata
      curl --location https://github.com/tesseract-ocr/tessdata/raw/master/eng.traineddata > eng.traineddata
#  do_git_checkout https://github.com/tesseract-ocr/tessdata.git tessdata
#  cd tessdata
      cp -v eng* osd* ${mingw_w64_x86_64_prefix}/share/tessdata
      rm -v eng* osd*
      touch tessdata.downloaded
    fi
  cd ..
}

build_freetype() {
  download_and_unpack_file https://downloads.sourceforge.net/project/freetype/freetype2/2.10.0/freetype-2.10.0.tar.bz2 freetype-2.10.0
  cd freetype-2.10.0
  # Need to make a directory for the build library
  mkdir -pv lib
  generic_configure "--with-png=yes --host=x86_64-w64-mingw32 --build=x86_64-redhat-linux"
#  cd src/tools
#    "/usr/bin/gcc -v apinames.c -o apinames.exe"
#    cp apinames.exe ../../objs
#  cd ../..
  do_make_install
  # No longer installs freetype-config
  cp -v builds/unix/freetype-config "${mingw_w64_x86_64_prefix}/bin/freetype-config"

#  export cpu_count=$original_cpu_count
  cd ..
  #generic_download_and_install http://download.savannah.gnu.org/releases/freetype/freetype-2.5.3.tar.gz freetype-2.5.3 "--with-png=no"
  sed -i.bak 's/Libs: -L${libdir} -lfreetype.*/Libs: -L${libdir} -lfreetype -lexpat -lpng -lz -lbz2/' "$PKG_CONFIG_PATH/freetype2.pc" # this should not need expat, but...I think maybe people use fontconfig's wrong and that needs expat? huh wuh? or dependencies are setup wrong in some .pc file?
  # possibly don't need the bz2 in there [bluray adds its own]...
#  export CFLAGS=${original_cflags}
  # freetype-config needs to be picked up in the $PATH for dvdauthor and other compilations
  cp -v "${mingw_w64_x86_64_prefix}/bin/freetype-config" "${mingw_w64_x86_64_prefix}/../bin/freetype-config"
}

#build_vo_aacenc() {
#  generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/vo-aacenc/vo-aacenc-0.1.3.tar.gz/download vo-aacenc-0.1.3
#}

build_libcddb() {
#  download_and_unpack_file http://sourceforge.net/projects/libcddb/files/latest/download libcddb-1.3.2
#  cd libcddb-1.3.2
#    apply_patch_p1 file://${top_dir}/0001-include-winsock2-before-windows.mingw.patch
#    apply_patch_p1 file://${top_dir}/0002-fix-header-conflict.mingw.patch
#    apply_patch_p1 file://${top_dir}/0003-silent-rules.mingw.patch
#    apply_patch_p1 file://${top_dir}/0004-hack-around-dummy-alarm.mingw.patch
#    apply_patch_p1 file://${top_dir}/0005-fix-m4-dir.all.patch
#    apply_patch_p1 file://${top_dir}/0006-update-gettext-req.mingw.patch
#    apply_patch_p1 file://${top_dir}/0007-link-to-libiconv-properly.mingw.patch
#    # We need libgnurx, which is the DLL name of the library libregex
#    # sed -i.bak 's/-lregex/-lgnurx/' configure
#    cd lib
#      apply_patch file://${top_dir}/cddb-1.3.2-lib-cddb_net.c.patch
#    cd ..
#    # export LIBS=-lgnurx
##   The next line corrects a bad assumption about malloc when it is asked
##   the malloc zero
#    generic_configure_make_install "ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes --enable-static --enable-shared"
#    # unset LIBS
#  cd ..
  do_git_checkout https://github.com/qyot27/libcddb.git libcddb
  cd libcddb
    apply_patch file://{$top_dir}/libcddb-bootstrap.patch
    apply_patch_p1 file://${top_dir}/0002-fix-header-conflict.mingw.patch
    apply_patch_p1 file://${top_dir}/0004-hack-around-dummy-alarm.mingw.patch
    generic_configure_make_install "ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes CFLAGS=-O0"

  cd ..
}

build_sdl() {
  # apparently ffmpeg expects prefix-sdl-config not sdl-config that they give us, so rename...
  hold_cflags="${CFLAGS}"
  export CFLAGS=-DDECLSPEC=  # avoid SDL trac tickets 939 and 282, not worried about optimizing yet
  generic_download_and_install http://www.libsdl.org/release/SDL-1.2.15.tar.gz SDL-1.2.15 "--disable-stdio-redirect"
  cd SDL-1.2.15

  cd ..
  export CFLAGS="${hold_cflags}" # and reset it
  mkdir -pv temp
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
#  do_git_checkout https://github.com/SDL-mirror/SDL.git SDL 95ea2ed17787d98978805b7b8990d807bf47e2fd # 9333e80281655d2351913ee2418393af991efd36 # 48bcdfd8cc3db5b100e06ca9d5cdcedd4b46a35a
  download_and_unpack_file https://www.libsdl.org/release/SDL2-2.0.8.tar.gz SDL2-2.0.8
  cd SDL2-2.0.8
#    apply_patch file://${top_dir}/SDL2-prevent-duplicate-scalbln.patch
#    apply_patch file://${top_dir}/SDL2-stdint.patch
#    apply_patch file://${top_dir}/sdl2.xinput.patch
#    mkdir -v build

#  local new_hg_version=`hg --debug id -i`
#  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
#    echo "got upstream hg changes, forcing rebuild...SDL2"
##    apply_patch file://${top_dir}/SDL2-prevent-duplicate-d3d11-declarations.patch
#    cd build
#      rm already*
      apply_patch file://${top_dir}/SDL-declaration-after-statement.patch
      do_configure "--host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-shared --disable-static" # --enable-static" # --disable-render-d3d" # "../configure" #3d3 disabled with --disable-render-d3d due to mingw-w64-4.0.0 and SDL disagreements
      do_make_install "V=1"

#   cd ..
# else
#    echo "still at hg $new_hg_version SDL2"
#  fi
  cd ..

#  generic_download_and_install "https://www.libsdl.org/tmp/SDL-2.0.4-9799.tar.gz" "SDL-2.0.4-9799" "--disable-render-d3d"

}

build_sdl2_image() {
#  do_git_checkout https://github.com/SDL-mirror/SDL_image.git SDL_image
  download_and_unpack_file  https://www.libsdl.org/projects/SDL_image/release/SDL2_image-2.0.3.tar.gz SDL2_image-2.0.3
  cd SDL2_image-2.0.3
    rm -v aclocal.m4 Makefile.in configure
    do_configure "--host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-shared --enable-static"
    do_make_install "V=1"
    # do_make_clean
  cd ..
}

build_OpenCL() {
  do_git_checkout https://github.com/KhronosGroup/OpenCL-ICD-Loader.git OpenCL-ICD-Loader #978b4b3a29a3aebc86ce9315d5c5963e88722d03 # 6849f617e991e8a46eebf746df43032175f263b3
  cd OpenCL-ICD-Loader
    mkdir -pv inc/CL
    cp -v ${mingw_w64_x86_64_prefix}/include/CL/* inc/CL/
    export orig_cflags="${CFLAGS}"
    export CFLAGS="-DWINVER=0x0A00 -fcommon"
    do_cmake "-DOPENCL_ICD_LOADER_REQUIRE_WDK=OFF"
    do_make
    export CFLAGS="${orig_cflags}"
    # There is no install target for make
    cp bin/*dll ${mingw_w64_x86_64_prefix}/bin/
    cp bin/*exe ${mingw_w64_x86_64_prefix}/bin/
    cp libOpenCL.dll.a ${mingw_w64_x86_64_prefix}/lib/
  cd ..
}

build_vim() {
  do_git_checkout https://github.com/vim/vim.git vim
  cd vim
#  	apply_patch file://${top_dir}/vim_uuid.patch
  cd ..
  cd vim/src
      sed -i.bak 's/FEATURES=BIG/FEATURES=HUGE/' Make_cyg_ming.mak
      sed -i.bak 's/ARCH=i686/ARCH=x86-64/' Make_cyg_ming.mak
      sed -i.bak 's/CROSS=no/CROSS=yes/' Make_cyg_ming.mak
      sed -i.bak 's/WINDRES := windres/WINDRES := $(CROSS_COMPILE)windres/' Make_cyg_ming.mak
      echo "Now we are going to build vim."
      WINVER=0x0A00 CROSS_COMPILE=${cross_prefix} do_make "-f Make_cyg_ming.mak" # gvim.exe
      echo "Vim is built, but not installed."
      cp -fv gvim.exe vimrun.exe xxd/xxd.exe GvimExt/gvimext.dll GvimExt/gvimext.res "${mingw_w64_x86_64_prefix}/bin"
      # Here come the runtime files, necessary for syntax highlighting, etc.
      # On the installation host, these files must be pointed to by VIMRUNTIME
      mkdir -pv ${mingw_w64_x86_64_prefix}/share/vim && cp -Rv ../runtime/* ${mingw_w64_x86_64_prefix}/share/vim
  cd ../..

  do_git_checkout https://github.com/vim/vim.git vim_console
  cd vim_console/src
    sed -i.bak 's/FEATURES=BIG/FEATURES=HUGE/' Make_cyg_ming.mak
    sed -i.bak 's/ARCH=i686/ARCH=x86-64/' Make_cyg_ming.mak
    sed -i.bak 's/CROSS=no/CROSS=yes/' Make_cyg_ming.mak
    sed -i.bak 's/WINDRES := windres/WINDRES := $(CROSS_COMPILE)windres/' Make_cyg_ming.mak
    echo "Now we are going to build vim."
    WINVER=0x0A00 CROSS_COMPILE=${cross_prefix} do_make "-f Make_cyg_ming.mak GUI=no vim.exe " # gvim.exe
    echo "Vim is built, but not installed."
    cp -fv vim.exe "${mingw_w64_x86_64_prefix}/bin"
  cd ../..
}


build_mpv() {
  do_git_checkout https://github.com/mpv-player/mpv.git mpv # 4c516a064a8246c9067eee32578a7a78feb371dc
  cd mpv
#    apply_patch file://${top_dir}/mpv-disable-rectangle.patch
    ./bootstrap.py
    export DEST_OS=win32
    export TARGET=x86_64-w64-mingw32
    unset AR
    unset CC
    unset LD
    #env
    do_configure "configure -v -pp --prefix=${mingw_w64_x86_64_prefix} --enable-dvdnav --enable-cdda --disable-x11 --disable-debug-build --enable-sdl2 --enable-libmpv-shared --disable-libmpv-static" "./waf"
    # In this cross-compile for Windows, we keep the Python script up-to-date and therefore
    # must call it directly by its full name, because mpv can only explore for executables
    # with the .exe suffix.
    #sed -i.bak 's/path = "youtube-dl"/path = "youtube-dl.py"/' player/lua/ytdl_hook.lua
    #sed -i.bak 's/mp.find_config_file("youtube-dl" .. exesuf)/mp.find_config_file("youtube-dl.py")/' player/lua/ytdl_hook.lua
    #sed -i.bak 's/  ytdl.path, "--no-warnings"/  "python.exe", ytdl.path, "--no-warnings"/' player/lua/ytdl_hook.lua
    #apply_patch file://${top_dir}/mpv-ytdl.patch
    ./waf build || exit 1
    ./waf install || exit 1
    mkdir -pv ${mingw_w64_x86_64_prefix}/share/mpv
    cp -vf ${top_dir}/mpv.conf ${mingw_w64_x86_64_prefix}/share/mpv/mpv.conf
    unset DEST_OS
    unset TARGET
  cd ..
}

build_faac() {
  generic_download_and_install http://downloads.sourceforge.net/faac/faac-1.29.9.2.tar.gz faac-1.29.9.2 "--with-mp4v2=no"
  cd faac-1.29.9.2

  cd ..
}

build_atomicparsley() {
  do_git_checkout https://github.com/benfry/atomicparsley.git atomicparsley
  export ac_cv_func_malloc_0_nonnull=yes
  cd atomicparsley
    rm configure
    apply_patch file://${top_dir}/atomicparsley-min.patch
    generic_configure_make_install

  cd ..
  unset ac_cv_func_malloc_0_nonnull
}

build_gstreamer() {
	
    #do_git_checkout https://github.com/GStreamer/gstreamer.git gstreamer # 6babf1f086cce9cc392e2dc8a6cdf252d9b4cc48
	download_and_unpack_file https://gstreamer.freedesktop.org/src/gstreamer/gstreamer-1.16.2.tar.xz gstreamer-1.16.2
	cd gstreamer-1.16.2
    #cd gstreamer
        	mkdir -vp tests/examples/controller/include # to work around a bad include directory
        	generic_configure_make_install "--disable-silent-rules --disable-fatal-warnings"
  	cd ..
	download_and_unpack_file https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.16.2.tar.xz gst-plugins-base-1.16.2
	cd gst-plugins-base-1.16.2
#    do_git_checkout https://github.com/GStreamer/gst-plugins-base.git gst-plugins-base 909baa2360f7ba7b6e2e27a2ad565e3142630abe
 #   cd gst-plugins-base
        mkdir -vp gst-libs/gst/video/include
        mkdir -vp gst-libs/gst/tag/include
        mkdir -vp ext/gl/include
        mkdir -vp ext/pango/include
        mkdir -vp tests/examples/audio/include
        mkdir -vp tests/examples/gio/include
        mkdir -vp tests/examples/playback/include
        mkdir -vp tests/examples/gl/generic/include
        mkdir -vp tests/examples/gl/gtk/include
        mkdir -vp tests/examples/overlay/include
        mkdir -vp tests/examples/seek/include
        mkdir -vp tests/examples/gl/gtk/filternovideooverlay/include
        mkdir -vp tests/examples/gl/gtk/filtervideooverlay/include
        mkdir -vp tests/examples/snapshot/include
        mkdir -vp tests/examples/gl/gtk/fxtest/include
        mkdir -vp tests/examples/gl/gtk/switchvideooverlay/include
        mkdir -vp tests/examples/gl/gtk/3dvideo/include
        generic_configure_make_install "--disable-fatal-warnings --disable-examples"
    cd ..
}

build_audacity() {
    do_git_checkout https://github.com/audacity/audacity audacity
}

build_traverso() {
    do_git_checkout git://git.savannah.gnu.org/traverso.git traverso
    cd traverso
      # export PKG_CONFIG_DEBUG_SPEW=1
      apply_patch file://${top_dir}/traverso-fixes.patch
      do_cmake "-DPKG_CONFIG_PATH=${mingw_w64_x86_64_prefix}/lib/pkgconfig -DWANT_JACK=ON -DWANT_WAVPACK=OFF -DWANT_PORTAUDIO=ON -DWANT_LV2=ON -DWANT_MP3_DECODE=OFF -DWANT_DEBUG=OFF -DCMAKE_C_FLAGS=-DQ_WS_WIN -DCMAKE_CXX_FLAGS=-DQ_WS_WIN" && ${top_dir}/correct_headers.sh
      do_make
      do_make_install
      # unset PKG_CONFIG_DEBUG_SPEW
    cd ..
}


build_wx() {
  do_git_checkout https://github.com/wxWidgets/wxWidgets.git wxWidgets v3.1.3 # WX_3_0_BRANCH #  8c8557812be37697d4c2ffdad35141a51a9bc71d # WX_3_0_BRANCH
#  download_and_unpack_file https://github.com/wxWidgets/wxWidgets/archive/v3.0.4.tar.gz wxWidgets-3.0.4
  cd wxWidgets
#    apply_patch_p1 https://github.com/wxWidgets/wxWidgets/commit/73e9e18ea09ffffcaac50237def0d9728a213c02.patch
#    rm -v configure
    generic_configure_make_install "--with-msw --enable-monolithic --disable-debug --disable-debug_flag --enable-unicode --enable-optimise --with-libpng --with-libjpeg --with-libtiff --with-opengl --disable-option-checking --enable-compat28 --enable-compat30" # --with-opengl --disable-mslu --enable-unicode --enable-monolithic --with-regex=builtin --disable-precomp-headers --enable-graphics_ctx --enable-webview --enable-mediactrl --with-libpng=sys --with-libxpm=builtin --with-libjpeg=sys --with-libtiff=sys" # "--without-opengl  --enable-checklst --with-regex=yes --with-msw --with-libpng=sys --with-libjpeg=sys --with-libtiff=sys --with-zlib=yes --enable-graphics_ctx --enable-webview --enable-mediactrl --disable-official_build --disable-option-checking" # --with-regex=yes
    # wx-config needs to be visible to this script when compiling
    cp -v ${mingw_w64_x86_64_prefix}/bin/wx-config ${mingw_w64_x86_64_prefix}/../bin/wx-config
    # wxWidgets doesn't include the DLL run-time libraries in the right place.
    cd ${mingw_w64_x86_64_prefix}/lib
      for filename in ./libwx*dll.a; do cp -v "./$filename" "./$(echo $filename | sed -e 's/-x86_64-w64-mingw32//g')";  done
    cd -
    cp -v ${mingw_w64_x86_64_prefix}/lib/wx*dll ${mingw_w64_x86_64_prefix}/bin
  cd ..
  #do_git_checkout https://github.com/wxWidgets/wxWidgets.git wxWidgetsLATEST
#  download_and_unpack_file https://github.com/wxWidgets/wxWidgets/releases/download/v3.1.1/wxWidgets-3.1.1.tar.bz2 wxWidgets-3.1.1
#  cd wxWidgets-3.1.1
#  cd wxWidgetsLATEST
#    generic_configure_make_install "--disable-option-checking --with-gtk=2" # "--with-libpng=sys --with-libjpeg=sys --disable-mslu --enable-unicode --with-regex=builtin --disable-precomp-headers --with-libtiff=sys --with-regex=yes --with-zlib=yes --enable-webview --enable-mediactrl --disable-option-checking --with-gtk=2 --enable-monolithic"
    # wx-config needs to be visible to this script when compiling
#    cp -v ${mingw_w64_x86_64_prefix}/bin/wx-config ${mingw_w64_x86_64_prefix}/../bin/wx-config
    # wxWidgets doesn't include the DLL run-time libraries in the right place.
#    cd ${mingw_w64_x86_64_prefix}/lib
#      for filename in ./libwx*dll.a; do cp -v "./$filename" "./$(echo $filename | sed -e 's/-x86_64-w64-mingw32//g')";  done
#    cd -
#    cp -v ${mingw_w64_x86_64_prefix}/lib/wx*dll ${mingw_w64_x86_64_prefix}/bin
#  cd ..
}

build_libsndfile() {
  store_libs=$LIBS
  export LIBS="-logg -lvorbis"
  generic_download_and_install http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.28.tar.gz libsndfile-1.0.28 "--enable-experimental"
  cd libsndfile-1.0.28

  cd ..
  export LIBS=$store_libs
  # Need to use a different name for the static library for traverso
  ln -sv ${mingw_w64_x86_64_prefix}/lib/libsndfile.a ${mingw_w64_x86_64_prefix}/lib/libsndfile-1.a
}

build_libbs2b() {
  hold_libs=$LIBS
  export LIBS=-lsndfile
  export ac_cv_func_malloc_0_nonnull=yes
  export ac_cv_func_realloc_0_nonnull=yes
  download_and_unpack_file file://${top_dir}/libbs2b-snapshot.tar.xz libbs2b
  cd libbs2b
    sed -i.bak 's/-lm -version-info/-lm -no-undefined -version-info/' src/Makefile.am
    generic_configure_make_install

  cd ..
  export LIBS=$hold_libs
  unset ac_cv_func_malloc_0_nonnull
  unset ac_cv_func_realloc_0_nonnull
}

build_libgame-music-emu() {
  download_and_unpack_file https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.2.tar.xz game-music-emu-0.6.2
  cd game-music-emu-0.6.2
    # sed -i.bak "s|SHARED|STATIC|" gme/CMakeLists.txt
    do_cmake_and_install

  cd ..
}

build_libdcadec() {
  do_git_checkout https://github.com/foo86/dcadec.git dcadec_git
  cd dcadec_git
    do_make_and_make_install "CC=$(echo $cross_prefix)gcc AR=$(echo $cross_prefix)ar PREFIX=$mingw_w64_x86_64_prefix CONFIG_SHARED=1 CONFIG_WINDOWS=1"

  cd ..
}

build_glew() {
#  do_git_checkout https://github.com/nigels-com/glew.git glew
#  cd glew
#    export cpu_count=1
#    do_make "SYSTEM=linux-mingw64"
#    export cpu_count=$original_cpu_count
#    apply_patch file:///${top_dir}/glew-CMakeLists-txt.patch
#    cpu_count=1
#    do_make extensions
#   export cpu_count=$original_cpu_count
#   cd build/cmake
#      do_cmake "-DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF"
#      do_make_install
#    cd ../..
#    generic_configure_make_install
#  cd ..
  download_and_unpack_file https://downloads.sourceforge.net/project/glew/glew/2.1.0/glew-2.1.0.tgz glew-2.1.0
  cd glew-2.1.0
    sed -i.bak 's/i686-w64-mingw32-/x86_64-w64-mingw32-/g' config/Makefile.linux-mingw-w64
    sed -i.bak "s!LDFLAGS.GL = -lopengl32!LDFLAGS.GL = -L${mingw_w64_x86_64_prefix}/lib -lmsvcrt -lopengl32!" config/Makefile.linux-mingw-w64
    sed -i.bak 's/LDFLAGS.EXTRA += -nostdlib/LDFLAGS.EXTRA +=/' config/Makefile.linux-mingw-w64
    do_make "GLEW_PREFIX=${mingw_w64_x86_64_prefix} SYSTEM=linux-mingw-w64 GLEW_DEST=${mingw_w64_x86_64_prefix}"
    do_make_install "GLEW_PREFIX=${mingw_w64_x86_64_prefix} SYSTEM=linux-mingw-w64 GLEW_DEST=${mingw_w64_x86_64_prefix}"
    # For unclear reasons, the Glew distribution does not install the shared libraries.
    # We do this manually.
    cp -v lib/glew32.dll ${mingw_w64_x86_64_prefix}/bin/glew32.dll
    cp -v lib/libglew32.dll.a ${mingw_w64_x86_64_prefix}/lib/libglew32.dll.a

  cd ..

}

build_libwebp() {
  do_git_checkout https://chromium.googlesource.com/webm/libwebp libwebp
  cd libwebp
    generic_configure_make_install "LIBS=-lSDL2main --enable-libwebpmux --enable-libwebpdemux --enable-libwebpdecoder --enable-libwebpextras --enable-experimental --disable-sdl"
#    # I don't understand why, but mux.h, required for GraphicMagick, isn't installed
#    cp -v src/webp/mux.h ${mingw_w64_x86_64_prefix}/include/webp/mux.h
#    cp -v src/webp/mux_types.h ${mingw_w64_x86_64_prefix}/include/webp/mux_types.h

  cd ..
#  generic_download_and_install http://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-0.6.0.tar.gz libwebp-0.6.0
}

build_wavpack() {
  generic_download_and_install http://wavpack.com/wavpack-5.1.0.tar.bz2 wavpack-5.1.0 "--enable-shared=yes"
  cd wavpack-5.1.0

  cd ..
}

build_libmpeg2() {
  do_git_checkout https://code.videolan.org/videolan/libmpeg2.git libmpeg2
  cd libmpeg2
    rm bootstrap
    apply_patch file://${top_dir}/libmpeg2-inline.patch
    export orig_cpu_count=$cpu_count
    export cpu_count=1
    generic_configure_make_install "--without-x --disable-sdl"

    export cpu_count=$orig_cpu_count
  cd ..
}

build_lame() {
  # generic_download_and_install http://sourceforge.net/projects/lame/files/lame/3.99/lame-3.99.5.tar.gz/download lame-3.99.5
  do_git_checkout https://github.com/rbrito/lame.git lame
  cd lame
  # For some reason, the definition of DBL_EPSILON has vanished
  grep -lr DBL_EPSILON libmp3lame | xargs sed -i "s|xmin, DBL_EPSILON|xmin, rh2|g"
  apply_patch file://${top_dir}/lame-obsolete-code.patch
  generic_configure_make_install "--enable-dynamic-frontends --enable-nasm --disable-rpath"

  cd ..
}

build_libMXFpp() {
#  download_and_unpack_file http://gallery.johnwarburton.net/bmxlib-libmxfpp-dd71b1723670edea23252ee6f206df1241013381.tar.xz bmxlib-libmxfpp-dd71b1723670edea23252ee6f206df1241013381
#  cd bmxlib-libmxfpp-dd71b1723670edea23252ee6f206df1241013381
  do_git_checkout https://git.code.sf.net/p/bmxlib/libmxfpp bmxlib-libmxfpp
  cd bmxlib-libmxfpp
  sed -i.bak 's/) -version-info/) -no-undefined -version-info/' libMXF++/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/D10MXFOP1AWriter/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/OPAtomReader/Makefile.am
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
		  mkdir -pv mediainfo
		fi
		cd mediainfo
	       	do_svn_checkout http://svn.code.sf.net/p/mediainfo/code/MediaInfo/trunk MediaInfo
		do_svn_checkout http://svn.code.sf.net/p/mediainfo/code/MediaInfoLib/trunk MediaInfoLib
		do_svn_checkout http://svn.code.sf.net/p/zenlib/code/ZenLib/trunk ZenLib
		# Overcome a case-sensitivity issue
                sed -i.bak 's/Windows.h/windows.h/' MediaInfoLib/Source/MediaInfo/Reader/Reader_File.h
		sed -i.bak 's/Windows.h/windows.h/' MediaInfoLib/Source/MediaInfo/Reader/Reader_File.cpp
		sed -i.bak '/#include <windows.h>/ a\#include <time.h>' ZenLib/Source/ZenLib/Ztring.cpp
		cd ZenLib/Project/GNU/Library
                generic_configure "--prefix=$mingw_w64_x86_64_prefix --host=x86_64-w64-mingw32 --enable-debug"
		sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
		do_make_install

		cd ../../../../MediaInfoLib/Project/GNU/Library
		do_configure "--host=x86_64-w64-mingw32 --prefix=$mingw_w64_x86_64_prefix --with-libcurl --with-libmms --enable-debug" # LDFLAGS=-static-libgcc
		sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
		do_make_install
                # Intriguingly, libmediainfo-config, needed by mediainfo, doesn't get installed. It should go in as a native program.
                cp -v libmediainfo-config ${mingw_w64_x86_64_prefix}/../bin/libmediainfo-config
                # Do NOT do_make_clean at this point because the GUI needs to find the library compile tree
		cd ../../../../MediaInfo/Project/GNU/CLI
		do_configure "--host=x86_64-w64-mingw32 --prefix=$mingw_w64_x86_64_prefix --enable-debug --disable-static-libs" # --enable-staticlibs --enable-shared=no LDFLAGS=-static-libgcc"
		sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
		do_make_install
                # Do NOT do_make_clean at this point because the GUI might need to find the CLI command tree
                cd ../../..
                apply_patch file://${top_dir}/mediainfo-GUI_Main_Menu-cpp.patch
                cd Project/GNU/GUI
                do_configure "--host=x86_64-w64-mingw32 --prefix=$mingw_w64_x86_64_prefix --enable-debug --with-wx-config=${mingw_w64_x86_64_prefix}/bin/wx-config --disable-static-libs"
                sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
                do_make_install

                cd ../../../../MediainfoLib/Project/GNU/Library

                cd ../../../../Mediainfo/Project/GNU/CLI

                cd ../GUI

#                cd ../../../../..
		cd ../../../../..
		echo "Now returned to `pwd`"
}

build_libtool() {
  generic_download_and_install http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz libtool-2.4.6
  cd libtool-2.4.6

  cd ..
}

build_libiberty() {
  download_and_unpack_file https://launchpad.net/ubuntu/+archive/primary/+files/libiberty_20170913.orig.tar.xz libiberty-20170913
  cd libiberty-20170913
    do_configure "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-shared --disable-static --enable-install-libiberty" "./libiberty/configure"
    do_make_install

  cd ..
}

build_live555() {
  download_and_unpack_file https://download.videolan.org/pub/contrib/live555/live.2018.04.25.tar.gz live # http://www.live555.com/liveMedia/public/live555-latest.tar.gz live
  cd live
    export CC=x86_64-w64-mingw32-gcc
    export LD=x86_64-w64-mingw32-ld
    export AR=x86_64-w64-mingw32-ar
    export CXX=x86_64-w64-mingw32-g++
    ./genMakefiles mingw
    do_make
    x86_64-w64-mingw32-gcc -shared -o livemedia.dll -Wl,--out-implib,liblivemedia.dll.a -Wl,--whole-archive liveMedia/libliveMedia.a UsageEnvironment/libUsageEnvironment.a BasicUsageEnvironment/libBasicUsageEnvironment.a groupsock/libgroupsock.a -Wl,--no-whole-archive -lstdc++ -lws2_32
    cp -v livemedia.dll ${mingw_w64_x86_64_prefix}/bin
    cp -v liblivemedia.dll.a ${mingw_w64_x86_64_prefix}/lib
    install -v -D -t ${mingw_w64_x86_64_prefix}/include/liveMedia liveMedia/include/*.hh
    install -v -D -t ${mingw_w64_x86_64_prefix}/include/UsageEnvironment UsageEnvironment/include/*.hh
    install -v -D -t ${mingw_w64_x86_64_prefix}/include/BasicUsageEnvironment BasicUsageEnvironment/include/*.hh
    install -v -D -t ${mingw_w64_x86_64_prefix}/include/groupsock groupsock/include/*.hh
    install -v -D -t ${mingw_w64_x86_64_prefix}/include groupsock/include/*.h
  cd ..
  unset CC LD AR CXX

}

build_exiv2() {
  do_svn_checkout svn://dev.exiv2.org/svn/trunk exiv2
  cd exiv2
#    apply_patch file://${top_dir}/exiv2-makernote.patch
     cpu_count=1 # svn_version.h gets written too early otherwise
    # export LIBS="-lws2_32 -lwldap32"
     apply_patch file://${top_dir}/exiv2-vsnprintf.patch
     make config
     generic_configure_make_install "CXXFLAGS=-std=gnu++98 --enable-video --enable-webready"

#  download_and_unpack_file http://www.exiv2.org/exiv2-0.25.tar.gz exiv2-0.25
#  cd exiv2-0.25
   # A little patch to use the correct definition to pick up mingw-w64 compiler
#    sed -i.bak 's/#ifndef  __MINGW__/#ifndef  __MINGW64__/' src/http.cpp
#    do_cmake '-DCMAKE_SHARED_LINKER_FLAGS=-lws2_32'
#    cp -Rv config/* .
#    generic_configure_make_install
#    do_make_install "VERBOSE=1"
    cpu_count=$original_cpu_count
  cd ..
#  unset LIBS
}

build_bmx() {
  do_git_checkout https://notabug.org/RiCON/bmx.git bmxlib-bmx # 723e48
  cd bmxlib-bmx
    sed -i.bak 's/) -version-info/) -no-undefined -version-info/' src/Makefile.am
#    apply_patch file://${top_dir}/bmxlib-bmx-apps-writers-Makefile-am.patch
    if [[ ! -f ./configure ]]; then
      ./autogen.sh
    fi
    generic_configure_make_install "--disable-silent-rules" # CXXFLAGS=-static"

  cd ..
# bmx has added support for win32 mmap files using MSVC structured exceptions
# which GCC does not support. So we revert, for now, to the snapshot
# before this was added
#  generic_download_and_install file://${top_dir}/bmxlib-bmx-15c92b198cb7378ccf54632718ed47a89aae1553.zip bmxlib-bmx-15c92b198cb7378ccf54632718ed47a89aae1553
}



build_liburiparser() {
  do_git_checkout https://github.com/uriparser/uriparser.git uriparser
  cd uriparser
  # This requires sys/socket.h, which mingw-w64 (Windows) doesn't have
  sed -i.bak 's/bin_PROGRAMS = uriparse/bin_PROGRAMS =/' Makefile.am
#  if [[ ! -f ./configure ]]; then
#    ./autogen.sh
#  fii
  do_cmake "-DURIPARSER_BUILD_TESTS=OFF -DURIPARSER_BUILD_DOCS=OFF"
  do_make
  do_make_install
  #generic_configure_make_install "--disable-test --disable-doc"

  # Put back the change to allow git to update correctly
  sed -i.bak 's/bin_PROGRAMS =/bin_PROGRAMS = uriparse/' Makefile.am
  cd ..
}


build_zvbi() {
  export CFLAGS=-DPTW32_STATIC_LIB # seems needed XXX
  download_and_unpack_file http://sourceforge.net/projects/zapping/files/zvbi/0.2.35/zvbi-0.2.35.tar.bz2/download zvbi-0.2.35
  cd zvbi-0.2.35
    if [[ ! -f zvbi.built ]]; then
      apply_patch file://${top_dir}/zvbi-win32.patch
      apply_patch file://${top_dir}/zvbi-ioctl.patch
#      apply_patch file://${top_dir}/zvbi-shared-dll.patch
#      autoreconf -fvi
      export LIBS="-lpng -liconv -lpthread"
      generic_configure " --disable-dvb --disable-bktr --disable-nls --disable-proxy --without-doxygen --disable-shared --enable-static" # thanks vlc!
      unset LIBS
      cd src
        do_make_install
      cd ..
      cp zvbi-0.2.pc $PKG_CONFIG_PATH/zvbi.pc
      cp zvbi-0.2.pc $PKG_CONFIG_PATH/zvbi-0.2.pc
      touch zvbi.built
#   there is no .pc for zvbi, so we add --extra-libs=-lpng to FFmpegs configure
      sed -i 's/-lzvbi *$/-lzvbi -lpng -lpthread/' "$PKG_CONFIG_PATH/zvbi.pc"
    else
      echo "zvbi already built."
    fi
  cd ..
  export CFLAGS=$original_cflags # it was set to the win32-pthreads ones, so revert it
}

build_libmodplug() {
  generic_download_and_install http://sourceforge.net/projects/modplug-xmms/files/libmodplug/0.8.8.5/libmodplug-0.8.8.5.tar.gz/download libmodplug-0.8.8.5
  cd libmodplug-0.8.8.5

  cd ..
  # unfortunately this sed isn't enough, though I think it should be [so we add --extra-libs=-lstdc++ to FFmpegs configure] http://trac.ffmpeg.org/ticket/1539
  sed -i.bak 's/-lmodplug.*/-lmodplug -lstdc++/' "$PKG_CONFIG_PATH/libmodplug.pc" # huh ?? c++?
  sed -i.bak 's/__declspec(dllexport)//' "$mingw_w64_x86_64_prefix/include/libmodplug/modplug.h" #strip DLL import/export directives
  sed -i.bak 's/__declspec(dllimport)//' "$mingw_w64_x86_64_prefix/include/libmodplug/modplug.h"
}

build_libcaca() {
  local cur_dir2=$(pwd)/libcaca
#  do_git_checkout https://github.com/cacalabs/libcaca libcaca
  download_and_unpack_file http://caca.zoy.org/raw-attachment/wiki/libcaca/libcaca-0.99.beta19.tar.gz libcaca-0.99.beta19
  cd libcaca-0.99.beta19
  # vsnprintf is defined both in libcaca and by mingw-w64-4.0.1 so we'll keep the system definition
  apply_patch_p1 file://${top_dir}/libcaca-vsnprintf.patch
  #apply_patch_p1 file://${top_dir}/libcaca-signals.patch
  cd caca
    sed -i.bak "s/__declspec(dllexport)//g" *.h # get rid of the declspec lines otherwise the build will fail for undefined symbols
    sed -i.bak "s/__declspec(dllimport)//g" *.h
  cd ..
  rm -v configure Makefile autogen autogen.sh bootstrap bootstrap.sh
  generic_configure_make_install "--libdir=$mingw_w64_x86_64_prefix/lib --disable-cxx --disable-csharp --disable-java --disable-python --disable-ruby --disable-imlib2 --disable-doc --disable-gl --disable-ncurses"

  cd ..
}


build_twolame() {
#  download_and_unpack_file http://sourceforge.net/projects/twolame/files/twolame/0.3.13/twolame-0.3.13.tar.gz/download twolame-0.3.13 # "CPPFLAGS=-DLIBTWOLAME_STATIC"
#  cd twolame-0.3.13
#    sed -i.bak 's/libtwolame_la_LDFLAGS  = -export-dynamic/libtwolame_la_LDFLAGS  = -no-undefined -export-dynamic/' libtwolame/Makefile.am
#    ./autogen.sh
#    generic_configure_make_install
#  cd ..
   do_git_checkout https://github.com/njh/twolame.git twolame 3e1720f4718b84c9744c0be936192ef74f2ad573
   cd twolame
#     sed -i.bak 's/libtwolame_la_LDFLAGS  = -export-dynamic/libtwolame_la_LDFLAGS  = -no-undefined -export-dynamic/' libtwolame/Makefile.am
    apply_patch file://${top_dir}/0001-mingw32-does-not-need-handholding.all.patch
    apply_patch file://${top_dir}/0002-no-undefined-on.mingw.patch
     # apply_patch file://${top_dir}/0003-binary-stdin.all.patch
    apply_patch file://${top_dir}/0004-no-need-for-dllexport.mingw.patch
     #apply_patch file://${top_dir}/0005-silent.mingw.patch
     sed -i.bak 's/simplefrontend doc tests/simplefrontend tests/' Makefile.am
     generic_configure_make_install

   cd ..
}

build_regex() {
  download_and_unpack_file "https://downloads.sourceforge.net/project/mingw/Other/UserContributed/regex/mingw-regex-2.5.1/mingw-libgnurx-2.5.1-src.tar.gz" mingw-libgnurx-2.5.1
  cd mingw-libgnurx-2.5.1
    # Patch for static version
    generic_configure
#    apply_patch_p1 file://${top_dir}/libgnurx-1-build-static-lib.patch
#    do_make "-f Makefile.mingw-cross-env libgnurx.a"
    orig_cpu_count=$cpu_count
    cpu_count=1  # Parallel builds are broken
    do_make
    export cpu_count=$orig_cpu_count
    x86_64-w64-mingw32-ranlib libregex.a || exit 1
#    do_make "-f Makefile.mingw-cross-env install-static"
    do_make "install"
    # Some packages e.g. libcddb assume header regex.h is paired with libregex.a, not libgnurx.a
#    cp $mingw_w64_x86_64_prefix/lib/libgnurx.a $mingw_w64_x86_64_prefix/lib/libregex.a
  cd ..
}

build_fmt() {
	do_git_checkout https://github.com/fmtlib/fmt.git fmt 6.0.0
	cd fmt
		do_cmake "-DBUILD_SHARED_LIBS=TRUE -DFMT_TEST=OFF"
		do_make_install
	cd ..
}

build_boost() {
  download_and_unpack_file "http://mirror.nienbo.com/boost/1.72.0/boost_1_72_0.tar.bz2" boost_1_72_0
  cd boost_1_72_0
  #  cd libs/serialization
  #    apply_patch file://${top_dir}/boost-codecvt.patch
  #  cd ../..
    apply_patch file://${top_dir}/boost-snprintf.patch
    local touch_name=$(get_small_touchfile_name already_configured "$configure_options $configure_name $LDFLAGS $CFLAGS")
    if [ ! -f  "$touch_name" ]; then
#      ./bootstrap.sh mingw target-os=windows address-model=64 link=shared threading=multi threadapi=win32 toolset=gcc-mingw --prefix=${mingw_w64_x86_64_prefix} || exit 1
       ./bootstrap.sh mingw --prefix=${mingw_w64_x86_64_prefix} || exit 1
       echo "using gcc : mingw : x86_64-w64-mingw32-g++ : <rc>x86_64-w64-mingw32-windres <archiver>x86_64-w64-mingw32-ar <ranlib>x86_64-w64-mingw32-ranlib ;" > user-config.jam
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
    # And the sed line removes linking to librt, which is folded into the standard libraries on mingw-w64
#    sed -i.bak 's/case \*       : option = -pthread ; libs = rt ;/case *      : option = -pthread ;/' tools/build/src/tools/gcc.jam
#    echo "using gcc : mingw : x86_64-w64-mingw32-g++ : <rc>x86_64-w64-mingw32-windres <archiver>x86_64-w64-mingw32-ar <ranlib>x86_64-w64-mingw32-ranlib ;" > user-config.jam
    # Configure and build in one step. ONLY the libraries necessary for mkvtoolnix are built.
#      ./b2 --prefix=${mingw_w64_x86_64_prefix} -j 2 --ignore-site-config --user-config=user-config.jam address-model=64 architecture=x86 binary-format=pe link=static --target-os=windows threadapi=win32 threading=multi toolset=gcc-mxe --layout=tagged --disable-icu cxxflags='-std=c++11' --with-system --with-filesystem --with-regex --with-date_time install || exit 1
#      ./b2 --prefix=${mingw_w64_x86_64_prefix} -j 2 --ignore-site-config --user-config=user-config.jam address-model=64 architecture=x86 binary-format=pe link=shared --runtime-link=shared --target-os=windows threadapi=win32 threading=multi toolset=gcc-mingw --layout=tagged --disable-icu cxxflags='-std=c++11' --with-system --with-filesystem --with-regex --with-date_time install || exit 1
#      ./b2 -a -d+2 --debug-configuration --prefix=${mingw_w64_x86_64_prefix} variant=release target-os=windows toolset=gcc-mingw address-model=64 link=shared runtime-link=shared threading=multi threadapi=win32 architecture=x86 binary-format=pe --with-system --with-filesystem --with-regex --with-date_time --with-thread --with-test --user-config=user-config.jam install || exit 1
#      ./b2 -a -d+2 --debug-configuration --prefix=${mingw_w64_x86_64_prefix} variant=debug target-os=windows toolset=gcc-mingw address-model=64 link=shared runtime-link=shared threading=multi threadapi=win32 architecture=x86 binary-format=pe boost.locale.winapi=on boost.locale.std=on boost.locale.icu=on boost.locale.iconv=on boost.locale.posix=off --with-locale --user-config=user-config.jam install || exit 1
      ./b2 -a -j ${cpu_count}  --prefix=${mingw_w64_x86_64_prefix} variant=release target-os=windows toolset=gcc-mingw abi=ms address-model=64 link=shared,static runtime-link=shared threading=multi threadapi=win32 architecture=x86 binary-format=pe --without-python --without-serialization --layout=tagged --user-config=user-config.jam install || exit 1 # boost.locale.winapi=on boost.locale.std=on boost.locale.icu=on boost.locale.iconv=on boost.locale.posix=off --user-config=user-config.jam install || exit 1
      touch -- "$touch_name"
    else
      echo "Already built and installed Boost libraries"
    fi

  cd ..
}

build_mkvtoolnix() {
  do_git_checkout https://gitlab.com/mbunkus/mkvtoolnix mkvtoolnix #16772170030715717341c3d5460d3d1fecf501a4
#    download_and_unpack_file https://mkvtoolnix.download/sources/mkvtoolnix-43.0.0.tar.xz mkvtoolnix-43.0.0
  cd mkvtoolnix # -43.0.0
    # Two libraries needed for mkvtoolnix
    git submodule init
    git submodule update
#    orig_ldflags=${LDFLAGS}
    # GNU ld uses a huge amount of memory here.
#    export LDFLAGS="-Wl,--hash-size=31"
    # Configure fixes an optimization problem with mingw 5.1.0 but in fact
    # the problem persists in 5.3.0
    #sed -i.bak 's/xx86" && check_version 5\.1\.0/xamd64" \&\& check_version 5.3.0/' ac/debugging_profiling.m4
    #sed -i.bak 's/\-O2/-O0/' ac/debugging_profiling.m4
    #sed -i.bak 's/\-O3/-O0/' ac/debugging_profiling.m4
    #sed -i.bak 's/\-O1/-O0/' ac/debugging_profiling.m4
#    apply_patch file://${top_dir}/mkvtoolnix-qt5.patch
    old_CC=${CC}
    old_LD=${LD}
    old_AR=${AR}
    old_CXX=${CXX}
    export CC=x86_64-w64-mingw32-gcc
    export LD=x86_64-w64-mingw32-ld
    export AR=x86_64-w64-mingw32-ar
    export CXX=x86_64-w64-mingw32-g++
    #apply_patch file://${top_dir}/mkvtoolnix-qt5-2.patch
    #apply_patch file://${top_dir}/mkvtoolnix-stack.patch
    #rm -vf src/info/sys_windows.cpp
    apply_patch file://${top_dir}/mkvtoolnix-version.patch
    generic_configure "--with-boost=${mingw_w64_x86_64_prefix} --with-boost-system=boost_system-mt-x64 --with-boost-filesystem=boost_filesystem-mt-x64 --with-boost-date-time=boost_date_time-mt-x64 --with-boost-regex=boost_regex-mt-x64 --enable-qt --enable-static-qt=no --disable-static-qt --enable-optimization=yes --enable-debug=no"
    # Now we must prevent inclusion of sys_windows.cpp because our build uses shared libraries,
    # and this piece of code unfortunately tries to pull in a static version of the Windows Qt
    # platform library libqwindows.a
#   sed -i.bak 's!sources("src/info/sys_windows.o!#!' Rakefile
#   env
    echo "Environment is: "
    env
    do_rake_and_rake_install "V=1"
    export CC=${old_CC}
    export AR=${old_AR}
    export LD=${old_LD}
    export CXX=${old_CXX}
    #    export LDFLAGS=${orig_ldflags}
    # To run the program, mkvtoolnix-gui expects to see the 'magic' file from 'file'
    # in its bin directory.
    mkdir -vp ${mingw_w64_x86_64_prefix}/bin/share/misc
    cp -v ${mingw_w64_x86_64_prefix}/share/misc/magic.mgc ${mingw_w64_x86_64_prefix}/bin/share/misc/magic.mgc
  cd ..
}

build_gavl() {
#  generic_download_and_install https://downloads.sourceforge.net/project/gmerlin/gavl/1.4.0/gavl-1.4.0.tar.gz gavl-1.4.0 "--enable-shared=yes"
 do_svn_checkout svn://svn.code.sf.net/p/gmerlin/code/trunk/gavl gavl # 5412
 cd gavl
   apply_patch file://${top_dir}/gavl-ac-try-run.patch
   export ac_cv_have_clock_monotonic=yes 
   generic_configure_make_install "ac_cv_have_clock_monotonic=yes --enable-shared=yes"
   unset ac_cv_have_clock_monotonic
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
  # do_git_checkout https://github.com/nu774/fdkaac.git fdkaac
  do_git_checkout https://github.com/nu774/fdkaac.git fdkaac
  cd fdkaac
    if [[ ! -f "configure" ]]; then
    autoreconf -fiv || exit 1
    fi
#    apply_patch file://${top_dir}/fdkaac-aacenc.patch
    generic_configure_make_install

  cd ..
}

build_poppler() {
#  do_git_checkout git://git.freedesktop.org/git/poppler/poppler poppler poppler-0.67.0
  do_git_checkout https://anongit.freedesktop.org/git/poppler/poppler.git poppler poppler-0.84.0
  cd poppler
#    apply_patch file://${top_dir}/poppler-threads.patch
    sed -i.bak 's!string\.h!sec_api/string_s.h!' test/perf-test.cc
    #sed -i.bak 's/noinst_PROGRAMS += perf-test/noinst_PROGRAMS += /' test/Makefile.am
    # Allow installation of QT5 PDF viewer
    #sed -i.bak 's/noinst_PROGRAMS = poppler_qt5viewer/bin_PROGRAMS = poppler_qt5viewer/' qt5/demos/Makefile.am
    #generic_configure_make_install "CFLAGS=-DMINGW_HAS_SECURE_API CXXFLAGS=-fpermissive --enable-xpdf-headers --enable-cmyk --enable-libtiff --enable-libopenjpeg=openjpeg2 --enable-zlib-uncompress --enable-libcurl"
    export CFLAGS_ORIG="${CFLAGS}"
    export CFLAGS="-DMINGW_HAS_SECURE_API"
    export CXXFLAGS=-fpermissive
    export PKG_CONFIG_PATH="${mingw_w64_x86_64_prefix}/lib/pkgconfig"
    do_cmake "-DENABLE_XPDF_HEADERS=ON -DSPLASH_CMYK=ON -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_UNCOMPRESS=ON -DENABLE_GLIB=OFF -DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_LIBOPENJPEG=unmaintained" && ${top_dir}/correct_headers.sh
    do_make_install

    export CFLAGS="${CFLAGS_ORIG}"
    unset CXXFLAGS
#    unset PKG_CONFIG_PATH
  cd ..
}

build_SWFTools() {
  do_git_checkout https://github.com/matthiaskramm/swftools swftools
  cd swftools
    download_config_files # The version of config.guess is too old here.
    export DISABLEPDF2SWF=true
    rm configure # Force regeneration of configure script to alleviate mingw-w64 conflicts
    sed -i.bak "s!/usr/include/fontconfig!${mingw_w64_x86_64_prefix}/include/fontconfig!g" m4/fontconfig.m4
    aclocal -I m4
    autoconf
    apply_patch file://${top_dir}/swftools-lib-pdf-Makefile-in.patch
    sed -i.bak 's/$(INSTALL_MAN1);//' src/Makefile.in
    sed -i.bak 's/cd swfs;$(MAKE) $@//' Makefile.in
    generic_configure "CPPFLAGS=-I${mingw_w64_x86_64_prefix}/include/poppler/ --enable-poppler"
    sed -i.bak 's/#define boolean int/typedef unsigned char boolean;/' config.h
    apply_patch file://${top_dir}/swftools-xpdf-unlink.patch
    do_make_and_make_install

    unset DISABLEPDF2SWF
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
  do_git_checkout https://github.com/dyne/frei0r.git frei0r # 4b363c644e505ce34c79b27d2d664713cbb3dbaa
  cd frei0r
    # The next three patches cope with the missing definition of M_PI
    apply_patch file://${top_dir}/frei0r-lightgraffiti.cpp.patch
    apply_patch file://${top_dir}/frei0r-vignette.cpp.patch
    apply_patch file://${top_dir}/frei0r-partik0l.cpp.patch
    # The next patch fixes a compilation problem due to curly brackets
  #  apply_patch file://${top_dir}/frei0r-facedetect.cpp-brackets.patch
    # This inserts boost_system-mt library which is missed off the list
  #  apply_patch file://${top_dir}/frei0r-boost.patch
    # This uses the c++ interface, not the c interface
  #  apply_patch file://${top_dir}/frei0r-facebl0r.patch
    # These are ALWAYS compiled as DLLs... there is no static library model in frei0r
    # The facedetect filters don't work because there's something wrong in the way frei0r calls into opencv.
    # If you want to debug this, please add -DCMAKE_BUILD_TYPE=Debug, otherwise important parameters are optimized out
    do_cmake "-DOpenCV_DIR=${OpenCV_DIR} -DOpenCV_INCLUDE_DIR=${OpenCV_INCLUDE_DIR} -DCMAKE_CXX_FLAGS=-std=c++14 -DCMAKE_VERBOSE_MAKEFILE=YES" && ${top_dir}/correct_headers.sh
    # do_cmake "-DCMAKE_CXX_FLAGS=-std=c++14 -DCMAKE_VERBOSE_MAKEFILE=YES"
    do_make_install #  "-j1"

  cd ..
}

build_gobject_introspection() {
  download_and_unpack_file http://ftp.gnome.org/pub/gnome/sources/gobject-introspection/1.56/gobject-introspection-1.56.1.tar.xz gobject-introspection-1.56.1
  cd gobject-introspection-1.56.1
    apply_patch file://${top_dir}/gobject-introspection.patch
    #    sed -i.bak 's/PYTHON_LIBS=`\$PYTHON-config --ldflags --libs/PYTHON_LIBS=`$PYTHON-config --ldflags/'  m4/python.m4
    generic_configure_make_install

  cd ..
}

build_gtk2() {
  download_and_unpack_file http://ftp.gnome.org/pub/gnome/sources/gtk+/2.24/gtk+-2.24.32.tar.xz gtk+-2.24.32
  cd gtk+-2.24.32
    # apply_patch_p1 https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-gtk2/0012-embed-manifest.all.patch
    rm -v configure Makefile.in
    export GTK_UPDATE_ICON_CACHE=/usr/bin/gtk-update-icon-cache
    export ac_cv_path_GTK_UPDATE_ICON_CACHE=/usr/bin/gtk-update-icon-cache
    generic_configure "--build=x86_64-pc-linux-gnu --host=x86_64-w64-mingw32 --disable-gdiplus --enable-explicit-deps=no --with-gdktarget=win32 --disable-modules --disable-cups --disable-papi --disable-glibtest --with-included-immodules=ime"
    rm -fv gtk/gtk.def
    do_make
    do_make_install

    unset GTK_UPDATE_ICON_CACHE
    unset ac_cv_path_GTK_UPDATE_ICON_CACHE
  cd ..
}

build_gtk() {
  # Now to get to work on a default theme
  download_and_unpack_file http://ftp.gnome.org/pub/gnome/sources/adwaita-icon-theme/3.28/adwaita-icon-theme-3.28.0.tar.xz adwaita-icon-theme-3.28.0
  cd adwaita-icon-theme-3.28.0
    generic_configure_make_install "--enable-w32-cursors"
  cd ..
  download_and_unpack_file https://icon-theme.freedesktop.org/releases/hicolor-icon-theme-0.17.tar.xz hicolor-icon-theme-0.17
  cd hicolor-icon-theme-0.17
    rm -v aclocal.m4 Makefile.in configure
    generic_configure_make_install
  cd ..
#  download_and_unpack_file http://ftp.gnome.org/pub/gnome/sources/gtk+/3.22/gtk+-3.22.21.tar.xz gtk+-3.22.21 # was .19

  do_git_checkout https://github.com/GNOME/gtk.git gtk 3a17e8006161df3f84f8b147ebdb6f0e5d2868de # gtk-3-24
  touch ${mingw_w64_x86_64_prefix}/share/icons/hicolor/.icon-theme.cache
  cd gtk
#    orig_cpu_count=$cpu_count
#    export cpu_count=1
    # Don't attempt to run the icon updater here. It's a Windows executable.
#    apply_patch file://${top_dir}/gtk3-demos-gtk-demo-Makefile-am.patch
#    apply_patch file://${top_dir}/gtk3-demos-widget-factory-Makefile-am.patch
#    apply_patch file://${top_dir}/gtk3-modules-input-Makefile.am.patch
    # Now regenerate autoconf and automake files
#    rm -v ./configure ./autogen.sh
#    apply_patch file://${top_dir}/gtk3-22-12.patch
    apply_patch file://${top_dir}/gtk3-introspection.patch
    apply_patch file://${top_dir}/gtk3-update-icon-cache.patch
    orig_pythonpath=${PYTHONPATH}
    export PYTHON=/usr/bin/python2
    export GLIB_COMPILE_RESOURCES=/usr/bin/glib-compile-resources
#  export PYTHONPATH=${mingw_w64_x86_64_prefix}/share/glib-2.0/codegen
    generic_configure_make_install "PYTHON=/usr/bin/python2 GLIB_COMPILE_RESOURCES=/usr/bin/glib-compile-resources --build=x86_64-unknown-linux-gnu --disable-introspection --disable-silent-rules --enable-win32-backend --disable-cups --disable-glibtest --with-included-immodules --disable-test-print-backend"
    export PYTHONPATH=${orig_pythonpath}
    unset GLIB_COMPILE_RESOURCES

#    export cpu_count=$orig_cpu_count
  cd ..

}

build_gtkmm()
{
	download_and_unpack_file http://ftp.gnome.org/pub/GNOME/sources/gtkmm/3.24/gtkmm-3.24.2.tar.xz gtkmm-3.24.2
	cd gtkmm-3.24.2
		generic_configure_make_install
	cd ..
}

build_libcanberra() {
	do_git_checkout git://git.0pointer.de/libcanberra libcanberra
	cd libcanberra
		generic_configure_make_install
	cd ..
}

build_snappy () {
  do_git_checkout https://github.com/google/snappy.git snappy
  cd snappy
    # apply_patch file://${top_dir}/snappy-shared-dll.patch
    cp README.md README
    # Distribution got its documentation wrong
    do_cmake "-DBUILD_SHARED_LIBS=ON -DSNAPPY_BUILD_TESTS=OFF"
    do_make_install

  cd ..
}

build_vidstab() {
  do_git_checkout https://github.com/georgmartius/vid.stab.git vid.stab # "430b4cffeb" # 0.9.8
  cd vid.stab
#    sed -i.bak "s/SHARED/STATIC/g" CMakeLists.txt # static build-ify
    do_cmake "-DUSE_OMP:bool=off"
    do_make_install

  cd ..
}

build_libchromaprint() {
  do_git_checkout https://github.com/acoustid/chromaprint.git chromaprint # 29ace183de7fb4f83a44afb29b3d5c6a641fb917
  cd chromaprint
#    apply_patch file://${top_dir}/chromaprint-vector.patch
    do_cmake "-DWITH_FFTW3=ON -DFFT_LIB=fftw3 -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=ON -DWITH_AVFFT=OFF -DUSE_AVFFT=OFF"
    do_make_install

  cd ..
}

build_libarchive() {
    #download_and_unpack_file https://libarchive.org/downloads/libarchive-3.3.3.tar.gz libarchive-3.3.3
    #cd libarchive-3.3.3
    do_git_checkout https://github.com/libarchive/libarchive.git libarchive
    cd libarchive
        apply_patch file://${top_dir}/libarchive.patch
        generic_configure_make_install
    #cp ${top_dir}/ZlibResult.cmake .
    #do_cmake "-DENABLE_LZO=ON -DENABLE_TAR_SHARED=ON -DENABLE_CPIO_SHARED=ON -DENABLE_CAT_SHARED=ON -CZlibResult.cmake"
    #do_make_install
    cd ..
}

build_pkg-config() {
  cp -v /usr/bin/pkg-config ${mingw_w64_x86_64_prefix}/../bin/x86_64-w64-mingw32-pkg-config
}

build_opusfile() {
  do_git_checkout https://github.com/xiph/opusfile.git opusfile
  cd opusfile
    if [[ ! -f "configure" ]]; then
      ./autogen.sh
    fi
    generic_configure_make_install
  cd ..
}

build_libopusenc() {
  do_git_checkout https://github.com/xiph/libopusenc.git libopusenc
  cd libopusenc
    if [[ ! -f "configure" ]]; then
      ./autogen.sh
    fi
    generic_configure_make_install
  cd ..
}

build_opustools() {
  do_git_checkout https://git.xiph.org/opus-tools.git opus-tools
  cd opus-tools
  apply_patch file://${top_dir}/opus-tools-fortify.patch
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
#  generic_download_and_install http://curl.haxx.se/download/curl-7.51.0.tar.bz2 curl-7.51.0 "--enable-ipv6 --with-librtmp --with-ca-fallback"
  do_git_checkout https://github.com/curl/curl.git curl
  cd curl
    generic_configure_make_install "--enable-ipv6 --with-librtmp --with-ca-fallback"

  cd ..
}

build_curl_early() {
#  generic_download_and_install http://curl.haxx.se/download/curl-7.51.0.tar.bz2 curl-7.51.0 "--enable-ipv6 --with-librtmp --with-ca-fallback"
  do_git_checkout https://github.com/curl/curl.git curl_early
  cd curl_early
    generic_configure_make_install "--enable-ipv6 --with-ca-fallback"

  cd ..
}

#build_asdcplib() {
#  export CFLAGS="-DKM_WIN32"
#  export cpu_count=1
#  download_and_unpack_file http://download.cinecert.com/asdcplib/asdcplib-1.12.60.tar.gz asdcplib-1.12.60
#  cd asdcplib-1.12.60
#    if [ ! -f asdcplib.built ]; then
#      apply_patch file://${top_dir}/asdcplib-shared.patch
#      autoreconf -fvi || exit 1
#      export LIBS="-lws2_32 -lcrypto -lssl -lgdi32"
#      generic_configure "CXXFLAGS=-DKM_WIN32 CFLAGS=-DKM_WIN32 --disable-static --with-openssl=${mingw_w64_x86_64_prefix} --with-expat=${mingw_w64_x86_64_prefix}"
#      do_make "CXXFLAGS=-DKM_WIN32 CFLAGS=-DKM_WIN32"
#      do_make_install
#      touch asdcplib.built
#    else
#      echo "ASDCPLIB already built."
#    fi
#  cd ..
#  unset LIBS
#  export CFLAGS=$original_cflags
#  export cpu_count=$original_cpu_count
#}

build_libdv() {
  download_and_unpack_file https://downloads.sourceforge.net/project/libdv/libdv/1.0.0/libdv-1.0.0.tar.gz libdv-1.0.0
  cd libdv-1.0.0
    # We need to regenerate the autoconf scripts because we patch Makefile.am
    # Makefile.am commands building a native binary to produce a header.
    # I have produced this header myself (it is quite simple) and included it
    # in this distribution.
    rm -v configure
    apply_patch file://${top_dir}/dv.patch
    apply_patch file://${top_dir}/libdv-gasmoff.patch
    apply_patch file://${top_dir}/libdv-enctest.c.patch
    apply_patch file://${top_dir}/libdv-encodedv-Makefile.am.patch
    cp -v ${top_dir}/asmoff.h libdv/asmoff.h || exit 1
    generic_configure_make_install "LIBS=-lpthread --enable-sdl --disable-xv --disable-asm"

  cd ..
}

build_asdcplib() {
  export CXXFLAGS=-DKM_WIN32
  export CFLAGS=-DKM_WIN32
  download_and_unpack_file https://download.videolan.org/contrib/asdcplib/asdcplib-2.7.19.tar.gz asdcplib-2.7.19
  #download_and_unpack_file http://download.cinecert.com/asdcplib/asdcplib-2.10.31.tar.gz asdcplib-2.10.31
  cd asdcplib-2.7.19
    rm configure
    #env
    apply_patch file://${top_dir}/asdcplib-shared.patch
    generic_configure_make_install "--with-openssl=${mingw_w64_x86_64_prefix} --with-expat=${mingw_w64_x86_64_prefix}"
    cp -v src/dirent_win.h ${mingw_w64_x86_64_prefix}/include

  cd ..
  unset CXXFLAGS
  unset CFLAGS
}



build_libtiff() {
  generic_download_and_install http://download.osgeo.org/libtiff/tiff-4.0.9.tar.gz tiff-4.0.9
  cd tiff-4.0.9

  cd ..
}

build_opencl() {
# Method: get the headers, then (in a later function) build OpenCL.dll from the github source
# which does NOT contain the headers
  mkdir -p ${mingw_w64_x86_64_prefix}/include/CL && cd ${mingw_w64_x86_64_prefix}/include/CL
    wget --no-clobber https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_d3d10.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_d3d11.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_dx9_media_sharing.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_dx9_media_sharing_intel.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_ext.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_gl_ext.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_ext_intel.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_gl.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_icd.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_platform.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_va_api_media_sharing_intel.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_version.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/opencl.h \
https://www.khronos.org/registry/cl/api/2.1/cl.hpp \
https://github.com/KhronosGroup/OpenCL-CLHPP/releases/download/v2.0.10/cl2.hpp \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/master/CL/cl_egl.h
#  cd -
#  cd ${top_dir}
# Use the installed OpenCL.dll to make libOpenCL.a
# This is an insecure method. Write something better! FIXME
#  gendef ./OpenCL.dll
#  x86_64-w64-mingw32-dlltool -l libOpenCL.a -d OpenCL.def -k -A
#  mv libOpenCL.a ${mingw_w64_x86_64_prefix}/lib/libOpenCL.a
  cd -
  mkdir -p ${mingw_w64_x86_64_prefix}/include/EGL && cd ${mingw_w64_x86_64_prefix}/include/EGL
    wget --no-clobber https://raw.githubusercontent.com/google/angle/master/include/EGL/egl.h \
https://raw.githubusercontent.com/google/angle/master/include/EGL/eglext.h \
https://raw.githubusercontent.com/google/angle/master/include/EGL/eglext_angle.h \
https://raw.githubusercontent.com/google/angle/master/include/EGL/eglplatform.h
  cd -
  mkdir -p ${mingw_w64_x86_64_prefix}/include/KHR && cd ${mingw_w64_x86_64_prefix}/include/KHR
    wget --no-clobber https://raw.githubusercontent.com/google/angle/master/include/KHR/khrplatform.h
  cd -
}

build_lua() {
  # Needed for mpv to use YouTube URLs. mpv looks for it in pkg-config path so might be
  # best to compile our own mingw version
  download_and_unpack_file http://www.lua.org/ftp/lua-5.2.3.tar.gz lua-5.2.3
  cd lua-5.2.3
    apply_patch_p1 file://${top_dir}/lua-5.2.3-static-mingw.patch
    # Adjustments when not building on Cygwin
    sed -i.bak 's/TO_BIN= lua luac/TO_BIN= lua.exe luac.exe lua52.dll/' Makefile
    sed -i.bak 's/-gcc.exe/-gcc/' Makefile
    sed -i.bak 's/-ar.exe/-ar/' Makefile
    sed -i.bak 's/-ranlib.exe/-ranlib/' Makefile
    sed -i.bak 's/-gcc.exe/-gcc/' src/Makefile
    sed -i.bak 's/-ar.exe/-ar/' src/Makefile
    sed -i.bak 's/-ranlib.exe/-ranlib/' src/Makefile
    sed -i.bak 's/LUA_T=	lua/LUA_T=	lua.exe/' src/Makefile
    sed -i.bak 's/LUAC_T=	luac/LUAC_T=	luac.exe/' src/Makefile
    do_make "mingw"
    do_make_install "mingw"

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
  do_git_checkout https://git.code.sf.net/p/sox/code sox
  cd sox
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv
  fi
  generic_configure_make_install

  cd ..
}

build_libuuid() {
  do_git_checkout https://github.com/h0tw1r3/libuuid-mingw.git libuuid
  cd libuuid
    rm -v autogen Makefile.in configure
    apply_patch file://${top_dir}/libuuid-mingw.patch
    generic_configure_make_install

  cd ..
}

build_zmq() {
  do_git_checkout https://github.com/zeromq/libzmq libzmq cb73745250dce53aa6e059751a47940b7518a1c3 # 4e2b9e6e07d4622d094febf8c4f61f9f191fd9ae
  cd libzmq
    generic_configure_make_install 

  cd ..
}

build_cppzmq() {
	do_git_checkout https://github.com/zeromq/cppzmq.git cppzmq
	cd cppzmq
		do_cmake "-DCPPZMQ_BUILD_TESTS=OFF" && ${top_dir}/correct_headers.sh
		do_make
		do_make_install
	cd ..
}

build_wxsvg() {
  generic_download_and_install http://downloads.sourceforge.net/project/wxsvg/wxsvg/1.5.13/wxsvg-1.5.13.tar.bz2 wxsvg-1.5.13 "--with-wx-config=${mingw_w64_x86_64_prefix}/bin/wx-config"
  cd wxsvg-1.5.13

  cd ..
}

build_pixman() {
#  do_git_checkout https://github.com/aseprite/pixman.git pixman
#  cd pixman
#    generic_configure_make_install
#  cd ..
  generic_download_and_install https://www.cairographics.org/releases/pixman-0.34.0.tar.gz pixman-0.34.0
  cd pixman-0.34.0

  cd ..
}

build_cairo() {
  download_and_unpack_file https://www.cairographics.org/releases/cairo-1.14.12.tar.xz cairo-1.14.12 # Was .8
  cd cairo-1.14.12
     rm -v autogen.sh configure
     apply_patch file://${top_dir}/cairo-fortify.patch
     generic_configure_make_install "--disable-silent-rules --enable-win32 --enable-win32-font --enable-gobject --enable-tee --enable-pdf --enable-ps --enable-svg --disable-dependency-tracking"

  cd ..
  download_and_unpack_file http://cairographics.org/snapshots/cairo-1.15.14.tar.xz cairo-1.15.14 # Was .4
  cd cairo-1.15.14
     rm -v autogen.sh configure
     apply_patch file://${top_dir}/cairo-fortify.patch
     generic_configure_make_install "--disable-silent-rules --enable-win32 --enable-win32-font --enable-gobject --enable-tee --enable-pdf --enable-ps --enable-svg --disable-dependency-tracking"

  cd ..
#  do_git_checkout git://anongit.freedesktop.org/git/cairo cairo
#  cd cairo
#    cp -v ${top_dir}/private-strndup.h ${mingw_w64_x86_64_prefix}/include/private-strndup.h || exit 1
#    apply_patch file://${top_dir}/cairo-pdf-interchange-strndup.patch
#    generic_configure_make_install "--disable-silent-rules --enable-win32 --enable-win32-font --enable-gobject --enable-tee --enable-pdf --enable-ps --enable-svg"
#"--disable-silent-rules --enable-win32 --enable-win32-font --enable-gobject --enable-tee --enable-pdf --enable-ps --enable-svg  cd ..
}

build_mmcommon() {
  do_git_checkout https://github.com/GNOME/mm-common.git mm-common
  cd mm-common
    generic_configure_make_install "--enable-network"

  cd ..
}

build_cairomm() {
#  download_and_unpack_file http://cairographics.org/releases/cairomm-1.15.3.tar.gz cairomm-1.15.3
#  do_git_checkout git://git.cairographics.org/git/cairomm cairomm v1.15.5
#  cd cairomm
#    apply_patch file://${top_dir}/cairomm-win32_surface.patch
#    orig_aclocalpath=${ACLOCAL_PATH}
#    export ACLOCAL_PATH="/usr/local/share/aclocal"
#    generic_configure_make_install # "--with-boost"
#
#    export ACLOCAL_PATH=${orig_aclocalpath}
#  cd ..
  download_and_unpack_file https://ftp.osuosl.org/pub/blfs/conglomeration/cairomm/cairomm-1.12.2.tar.gz cairomm-1.12.2
  cd cairomm-1.12.2
    generic_configure_make_install "--with-boost"

  cd ..
#  cd cairomm-1.15.3
#    apply_patch file://${top_dir}/cairomm-missing-M_PI.patch
#    generic_configure_make_install "--with-boost"
#  cd ..
}

build_taglib() {
  do_git_checkout https://github.com/taglib/taglib.git taglib
  cd taglib
    do_cmake "-DBUILD_EXAMPLES=ON -DBUILD_SHARED_LIBS=ON"
    do_make
    do_make_install
    # The examples are not installed
    cd examples
      cp -v *exe ${mingw_w64_x86_64_prefix}/bin/
    cd ..

  cd ..
}

build_dvdauthor() {
  do_git_checkout https://github.com/ldo/dvdauthor.git dvdauthor
  cd dvdauthor
#iconv does bad mojo in mingw-w64. And who doesn't want Unicode anyway, these days?
    export am_cv_func_iconv=no
    apply_patch_p1 file://${top_dir}/dvdauthor-mingw.patch
#    apply_patch file://${top_dir}/dvdauthor-configure-ac.patch
#    apply_patch file://${top_dir}/dvdauthor-mkdir-mingw32.patch
#    apply_patch file://${top_dir}/dvdauthor-compat-c-langinfo.patch
#    apply_patch file://${top_dir}/dvdauthor-dvdvob-sync.patch
#    sed -i.bak 's/SUBDIRS = doc src/SUBDIRS = src/' Makefile.am
#    sed -i.bak 's/@XML_CPPFLAGS@/@XML2_CFLAGS@/' src/Makefile.am
    generic_configure_make_install "CFLAGS=-I${mingw_w64_x86_64_prefix}/include/GraphicsMagick  LIBS=-lxml2 MAGICK_LIBS=-lGraphicsMagick"

    unset am_cv_func_iconv
  cd ..
}


build_openssh() {
  generic_download_and_install http://mirror.bytemark.co.uk/pub/OpenBSD/OpenSSH/portable/openssh-7.6p1.tar.gz openssh-7.6p1 "LIBS=-lgdi32"
  cd openssh-7.6p1

  cd ..
}

build_libffi() {
  generic_download_and_install ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz libffi-3.2.1
  cd libffi-3.2.1

  cd ..
}

build_ilmbase() {
  do_git_checkout https://github.com/openexr/openexr.git openexr 48c2106310c8edefc7c1387cffc466665e4f38d2 #9f23bcc60b9786ffd5d97800750b953313080c87
  # Problem with threads in latest code that checks for c++14 standard
#  cd openexr/IlmBase
  cd openexr
# IlmBase is written expecting that some of its binaries will be run during compilation.
    # In a cross-compiling environment, this more difficult to do than I know how.
    # The files that the binaries generate are two quite large headers. We have generated
    # them for you, and copy them to where they're required.
    # Then we patch the Makefiles to prevent the binaries' compilation.
#    cp ${top_dir}/openexr-IlmBase-Half-Makefile.am Half/Makefile.am
#    cp ${top_dir}/eLut.h Half/eLut.h
#    cp ${top_dir}/toFloat.h Half/toFloat.h
#    cd IlmThread
    # Now apply patch to cause Windows threads to be used instead of Posix
    # Note that ILM has supplied the code; we merely enable it in Makefile.am
#      apply_patch file://${top_dir}/ilmbase-ilmthread-Makefile.am.patch
#    cd ..
#    generic_configure_make_install "--enable-shared --enable-large-stack"

#    apply_patch file://${top_dir}/openexr.patch
    do_cmake "-DPYILMBASE_ENABLE=OFF -DCMAKE_VERBOSE_MAKEFILE=ON" && ${top_dir}/correct_headers.sh # -DCMAKE_THREAD_LIBS_INIT=-lboost_thread-mt-x64
    do_make "V=1"
    do_make_install "V=1"
    # Some bizarre locations are used
    cd ${mingw_w64_x86_64_prefix}/lib
    rm -vf libIlmImfUtil.dll libIlmImf.dll libIexMath.dll libIlmThread.dll libHalf.dll libIex.dll libImath.dll
    cd -
    cd ${mingw_w64_x86_64_prefix}/bin
    ln -fvs libIlmImfUtil-2_4.dll libIlmImfUtils.dll
    ln -fvs libIlmImf-2_4.dll libIlmImf.dll
    ln -fvs libIexMath-2_4.dll libIexMath.dll
    ln -fvs libIlmThread-2_4.dll libIlmThread.dll
    ln -fvs libHalf-2_4.dll libHalf.dll
    ln -fvs libIex-2_4.dll libIex.dll
    ln -fvs libImath-2_4.dll libImath.dll
    cd -
#  cd ../..
  cd ..
}


build_ffms2() {
# Checkout specified owing to non-compatible recent change
  do_git_checkout https://github.com/FFMS/ffms2.git ffms2 6df5632
  cd ffms2
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv
    fi
    apply_patch file://${top_dir}/ffms2.videosource.cpp.patch
    generic_configure_make_install "--disable-static --enable-shared --disable-silent-rules"

  cd ..
}

build_flac() {
  do_git_checkout https://git.xiph.org/flac.git flac  # b821ac2
#  cpu_count=1
  cd flac
    # microbench target hasn't been tested on many platforms yet
    sed -i.bak 's/microbench//' Makefile.am
    # Distributions subsituting doocbook2man need this
#    sed -i.bak 's/docbook-to-man/docbook2man/' man/Makefile.am
    if [[ ! -f "configure" ]]; then
      ./autogen.sh
    fi
    generic_configure_make_install "--disable-doxygen-docs --disable-silent-rules"

#    cpu_count=$original_cpu_count
  cd ..
}

build_youtube-dl() {
  do_git_checkout https://github.com/rg3/youtube-dl youtube-dl
  cd youtube-dl
    do_make youtube-dl
    cp youtube-dl "${mingw_w64_x86_64_prefix}/bin/youtube-dl.py"
  cd ..
}

build_libudfread() {
  do_git_checkout http://code.videolan.org/videolan/libudfread.git libudfread
  cd libudfread
    # Patch to work around broken detection of MinGW in tendem with MSVC
    apply_patch file://${top_dir}/libudfread-udfread-c.patch
    generic_configure_make_install

  cd ..
}

build_libburn() {
  do_svn_checkout http://svn.libburnia-project.org/libburn/trunk libburn
  cd libburn
    generic_configure_make_install

  cd ..
}

build_mjpegtools() {
#	do_svn_checkout https://svn.code.sf.net/p/mjpeg/Code/ mjpeg-Code
#	cd mjpeg-Code/trunk/mjpeg_play
#		apply_patch file://${top_dir}/mjpegtools-svn.patch
#		generic_configure_make_install "--disable-simd-accel"
#	cd -

  download_and_unpack_file http://downloads.sourceforge.net/project/mjpeg/mjpegtools/2.1.0/mjpegtools-2.1.0.tar.gz mjpegtools-2.1.0
  cd mjpegtools-2.1.0
    apply_patch file://${top_dir}/mjpegtools-2.1.0-mingw.patch
    apply_patch file://${top_dir}/mjpegtools-2.1.0-nanosleep.patch
    apply_patch file://${top_dir}/lavtools-Makefile.am.patch
    rm -v lavtools/Makefile.in
    rm -v configure
    generic_configure_make_install "LIBS=-lpthread --without-x --without-gtk SDL_CFLAGS=-I${mingw_w64_x86_64_prefix}/include/SDL"
  cd -
}

build_file() {
  # Also contains libmagic
  do_git_checkout https://github.com/file/file.git file_native #13ba1a3639f7a40f3bffbabf2737cbdde314faf4
  do_git_checkout https://github.com/file/file.git file #13ba1a3639f7a40f3bffbabf2737cbdde314faf4
  # We use the git version of file and libmagic, which is updated more
  # often than distributions track. File requires its own binary to compile
  # its list of magic numbers. Therefore, because we are cross-compiling,
  # we first compile a native 'file' executable, and store it in the path
  # where the mingw-w64 compilers are to be found. We must also modify
  # Makefile.am because it is not written for this kind of cross-compilation.
  cd file_native
#    apply_patch file://${top_dir}/magic_psl.patch
    do_configure "--prefix=${mingw_w64_x86_64_prefix}/.. --disable-shared --enable-static"
    do_make_install

  cd ..
  cd file
    apply_patch file://${top_dir}/file-win32.patch
#    apply_patch file://${top_dir}/magic_psl.patch
#    export cross_compiling=yes
    generic_configure_make_install "--enable-fsect-man5"
#    unset cross_compiling
  cd ..
}

build_cdrkit() {
  download_and_unpack_file http://pkgs.fedoraproject.org/repo/pkgs/cdrkit/cdrkit-1.1.11.tar.gz/efe08e2f3ca478486037b053acd512e9/cdrkit-1.1.11.tar.gz cdrkit-1.1.11
  cd cdrkit-1.1.11
    apply_patch_p1 file://{$top_dir}/cdrkit-1.1.11-mingw.patch
    apply_patch_p1 file://${top_dir}/cdrkit-1.1.11-cross-compile.patch
    do_cmake
    do_make

#    do_make_install
  cd ..
}

build_libebur128() {
  do_git_checkout https://github.com/jiixyj/libebur128.git libebur128
  cd libebur128
    do_cmake "-DENABLE_INTERNAL_QUEUE_H=ON"
    do_make
    do_make_install
    cp -v ${mingw_w64_x86_64_prefix}/lib/libebur128.dll ${mingw_w64_x86_64_prefix}/bin/libebur128.dll
  cd ..
}

build_loudness-scanner() {
  do_git_checkout https://github.com/jiixyj/loudness-scanner.git loudness-scanner
  cd loudness-scanner
    git submodule init
    git submodule update
    # Rename internal copy of libebur128 because of slight differences
    # update some code for latest FFmpeg
    apply_patch file://${top_dir}/ebur128-CMakeLists.txt-private.patch
    #apply_patch file://${top_dir}/loudness-scanner-ffmpeg.patch
    sed -i.bak 's/avcodec_alloc_frame/av_frame_alloc/' scanner/inputaudio/ffmpeg/input_ffmpeg.c
    do_cmake_static "-DENABLE_INTERNAL_QUEUE_H=ON -DCMAKE_VERBOSE_MAKEFILE=1 -DCMAKE_POLICY_DEFAULT_CMP0020=NEW -DGTK2_GDKCONFIG_INCLUDE_DIR=${mingw_w64_x86_64_prefix}/include/gtk-2.0/ -DDISABLE_QT5=ON"
    sed -i.bak 's/-isystem /-I/g' scanner/scanner-tag/CMakeFiles/scanner-tag.dir/includes_CXX.rsp
    sed -i.bak 's/-isystem /-I/g' scanner/scanner-drop-qt/CMakeFiles/loudness-drop-qt5.dir/includes_CXX.rsp
    do_make "VERBOSE=1 V=1"
    do_make_install #"VERBOSE=1"
    # The executable doesn't get installed
    cp -v loudness.exe ${mingw_w64_x86_64_prefix}/bin/loudness.exe
    cp -v loudness-drop-qt5.exe ${mingw_w64_x86_64_prefix}/bin/loudness-drop-qt5.exe
#    cp -v libebur128-ls.dll ${mingw_w64_x86_64_prefix}/bin/libebur128-ls.dll
#    cp -v libinput_ffmpeg.dll ${mingw_w64_x86_64_prefix}/bin/libinput_ffmpeg.dll
#    cp -v libinput_sndfile.dll ${mingw_w64_x86_64_prefix}/bin/libinput_sndfile.dll

  cd ..
}

build_filewalk() {
  do_git_checkout https://github.com/jiixyj/filewalk.git filewalk
  cd filewalk
    do_cmake
    do_make
    # There is no 'install' target in the Makefile
    cp -v libfiletree.a ${mingw_w64_x86_64_prefix}/lib/libfiletree.a
    cp -v filetree.h ${mingw_w64_x86_64_prefix}/include/filetree.h

  cd ..
}

build_cdrecord() {
  download_and_unpack_bz2file http://downloads.sourceforge.net/project/cdrtools/alpha/cdrtools-3.02a06.tar.bz2 cdrtools-3.02
  cd cdrtools-3.02
    export holding_path="${PATH}"
    export PATH="/usr/bin:/bin:${mingw_compiler_path}/bin"
#    apply_patch https://raw.githubusercontent.com/Warblefly/multimediaWin64/master/cdrtools-3.01a25_mingw.patch
    do_smake "STRIPFLAGS=-s OSNAME=mingw32_nt-6.4 CC=${cross_prefix}gcc INS_BASE=$mingw_w64_x86_64_prefix"
    do_smake_install "STRIPFLAGS=-s OSNAME=mingw32_nt-6.4 CC=${cross_prefix}gcc INS_BASE=$mingw_w64_x86_64_prefix"
#    do_smake "STRIPFLAGS=-s INS_BASE=${mingw_w64_x86_64_prefix}/x86_64_pc_cygwin"
#    do_smake_install "STRIPFLAGS=-s ${mingw_w64_x86_64_prefix}/x86_64_pc_cygwin"
  cd ..
  export PATH="${holding_path}"
}

build_smake() { # This enables build of cdrtools. Jorg Schilling uses his own make system called smake
                # which first nust be compiled for the native Cygwin architecture. Mingw builds don't
                # work for me
  download_and_unpack_file http://downloads.sourceforge.net/project/s-make/smake-1.2.4.tar.bz2 smake-1.2.4
  cd smake-1.2.4
  orig_path=$PATH
  export PATH=/bin:/usr/bin:/sbin:/usr/sbin
  /usr/bin/make STRIPFLAGS=-s INS_BASE=${mingw_w64_x86_64_prefix}/.. || exit 1
  /usr/bin/make install STRIPFLAGS=-s INS_BASE=${mingw_w64_x86_64_prefix}/.. || exit 1
  export PATH="${orig_path}"
  cd ..
}


build_zimg() {
  do_git_checkout https://github.com/sekrit-twc/zimg.git zimg # 799f91c403f562a26d8bf8ce757051abbf5c8cd6 # e6069fa9e883e0e637e0dd2023d444a07b4dc73c
  cd zimg
    sed -i.bak 's/Windows\.h/windows.h/' src/testcommon/mmap.cpp
    generic_configure_make_install "--enable-x86simd"

  cd ..
}

build_codec2() {
  unset AR
  unset CC
  unset CXX
  unset LD
  unset LDFLAGS
  do_git_checkout https://github.com/svn2github/Codec2-dev.git codec2-dev
  mkdir build-codec-2-mingw
  cd codec2-dev
    apply_patch file://${top_dir}/codec2-src-CMakeFiles.txt.patch
#    apply_patch file://${top_dir}/codec2-CMakeFiles.txt.patch
  cd ..
  cd build-codec-2-mingw
    #mkdir -pv build
    #cd build
      #echo "Environment print-out:"
      #env
      do_cmake ../codec2-dev "-DINSTALL_EXAMPLES=ON -DCMAKE_BUILD_TYPE=Release -DUNITTEST=OFF"
      do_make
      cd src
        cp -v *exe ${mingw_w64_x86_64_prefix}/bin/
        cp -v *dll ${mingw_w64_x86_64_prefix}/bin/
        cp -v *dll.a ${mingw_w64_x86_64_prefix}/lib/
        mkdir -vp ${mingw_w64_x86_64_prefix}/include/codec2
        cd ../../codec2-dev/src
        cp -v golay23.h codec2.h codec2_fdmdv.h codec2_cohpsk.h codec2_fm.h codec2_odfm.h fsk.h codec2_fifo.h comp.h comp_prim.h modem_stats.h kiss_fft.h freedv_api.h varicode.h freedv_api_internal.h ${mingw_w64_x86_64_prefix}/include/codec2
        cp -v ../../build-codec-2-mingw/codec2/version.h ${mingw_w64_x86_64_prefix}/include/codec2/version.h
      cd ..

    #cd ..
  cd ..
}

build_lzo() {
  generic_download_and_install http://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz lzo-2.10
  cd lzo-2.10

  cd ..

}

build_dvbpsi() {
  do_git_checkout http://code.videolan.org/videolan/libdvbpsi.git libdvbpsi
  cd libdvbpsi
    apply_patch file://${top_dir}/libdvbpsi.patch
    generic_configure_make_install

  cd ..
  # It helps some programs to see all these headers in the one place
  cp -v ${mingw_w64_x86_64_prefix}/include/dvbpsi/atsc/*h ${mingw_w64_x86_64_prefix}/include/dvbpsi
  cp -v ${mingw_w64_x86_64_prefix}/include/dvbpsi/custom/*h ${mingw_w64_x86_64_prefix}/include/dvbpsi
  cp -v ${mingw_w64_x86_64_prefix}/include/dvbpsi/dvb/*h ${mingw_w64_x86_64_prefix}/include/dvbpsi
  cp -v ${mingw_w64_x86_64_prefix}/include/dvbpsi/mpeg/*h ${mingw_w64_x86_64_prefix}/include/dvbpsi
  cp -v ${mingw_w64_x86_64_prefix}/include/dvbpsi/types/*h ${mingw_w64_x86_64_prefix}/include/dvbpsi
}

build_lz4() {
  do_git_checkout https://github.com/lz4/lz4.git lz4
  cd lz4
    cd contrib/cmake_unofficial
      do_cmake
      do_make_install

    cd ../..
  cd ..
}

build_libtasn1() {
  generic_download_and_install https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.13.tar.gz libtasn1-4.13 "--disable-doc --disable-gtk-doc --disable-gtk-doc-html --disable-gtk-doc-pdf"
  cd libtasn1-4.13

  cd ..
#  do_git_checkout https://git.savannah.gnu.org/git/libtasn1.git libtasn1
#  cd libtasn1
#    generic_configure_make_install
#  cd ..
}

build_ocaml() {
  do_git_checkout https://github.com/ocaml/ocaml.git ocaml 4.07
    cd ocaml
        git submodule init
        git submodule update
        apply_patch file://${top_dir}/ocaml.patch
        cp config/m-nt.h byterun/caml/m.h
        cp config/s-nt.h byterun/caml/s.h
        cp config/Makefile.mingw64 config/Makefile
        # do_configure "--host x86_64-w64-mingw32 --target x86_64-w64-mingw32 --prefix ${mingw_w64_x86_64_prefix}"
        do_make "-f Makefile.nt flexdll -j1"
        do_make "-f Makefile.nt bootstrap -j1"
        do_make "-f Makefile.nt world.opt -j1"
        do_make "-f Makefile.nt flexlink.opt -j1"
        do_make_install "-f Makefile.nt"
    cd ..
}

build_aubio() {
    # We need our own version of Waf, specially compiled
    # Tests have been added to aubio but don't work when cross-compiled
    do_git_checkout https://git.aubio.org/aubio/aubio aubio #d94afb37f953f5d7cad9881dac42bff1e3b66f9c
    cd aubio
    	apply_patch file://${top_dir}/aubio_notests.patch
	apply_patch file://${top_dir}/aubio_mingw.patch
        mkdir aubio_build
        cd aubio_build
            wget https://waf.io/waf-2.0.1.tar.bz2
            tar xvvf waf-2.0.1.tar.bz2
            cd waf-2.0.1
                NOCLIMB=1 python waf-light --tools=c_emscripten
            cd ..
        cd ..
    cp -v aubio_build/waf-2.0.1/waf .
    rm -rvf aubio_build
    do_configure "configure AR=x86_64-w64-mingw32-ar PKGCONFIG=x86_64-w64-mingw32-pkg-config WINRC=x86_64-w64-mingw32-windres CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ -v -pp --prefix=${mingw_w64_x86_64_prefix} --enable-double --disable-fftw3f --enable-fftw3 --with-target-platform=win64 --disable-jack --disable-tests --notests --disable-examples" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
    cd ..

}

build_libdsm() {
  do_git_checkout https://github.com/videolabs/libdsm.git libdsm #03e98f930c45f4b9c34a98cc1f9a69c78567e9a3
  cd libdsm
    apply_patch file://${top_dir}/libdsm-fortify.patch
    generic_configure_make_install "--disable-silent-rules"

  cd ..
#  cd ${mingw_w64_x86_64_prefix}/lib/pkgconfig
#    apply_patch file://${top_dir}/libdsm-pc.patch
#  cd -
}

build_libcdio() {
#  download_and_unpack_file file://${top_dir}/libcdio-4b5eda30.tar.gz libcdio-cdtext-testing-4b5eda3
  do_git_checkout git://git.sv.gnu.org/libcdio.git libcdio #  cd libcdio
  cd libcdio
    if [[ ! -f "configure" ]]; then
      autoreconf -fvi
    fi
    touch ./doc/version.texi # Documentation isn't included but the Makefile still wants it
    touch src/cd-drive.1 src/cd-info.1 src/cd-read.1 src/iso-info.1 src/iso-read.1
    generic_configure_make_install

  cd ..
}

build_libcdio_libcddb() {
  # This needs compiling twice to work around a circular dependency with libcddb
#  do_git_checkout git://git.sv.gnu.org/libcdio.git libcdio_cddb cdtext-testing
  download_and_unpack_file file://${top_dir}/libcdio-4b5eda30.tar.gz libcdio-cdtext-testing-4b5eda3
#  cd libcdio_cddb
  cd libcdio-cdtext-testing-4b5eda3
    sed -i.bak 's/noinst_PROGRAMS/bin_PROGRAMS/' example/Makefile.am
    if [[ ! -f "configure" ]]; then
      autoreconf -fvi
    fi
    touch ./doc/version.texi # Documentation isn't included but the Makefile still wants it
    touch src/cd-drive.1 src/cd-info.1 src/cd-read.1 src/iso-info.1 src/iso-read.1
    generic_configure_make_install
    cd example
      do_make_install
    cd ..

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

build_gettext() {
	# Later versions of GNU gettext have a mingw incompatibility
  do_git_checkout https://git.savannah.gnu.org/git/gettext.git gettext  5ed70829a2a78b38f8fddf3543a34f9f22ea110e
  cd gettext
    generic_configure "CFLAGS=-O2 CXXFLAGS=-O2 LIBS=-lpthread"
    cd gettext-runtime/intl
      do_make
      do_make_install

    cd ../..
  cd ..
#    apply_patch file://${top_dir}/gettext-cross.patch
#    generic_configure_make_install "CFLAGS=-O2 CXXFLAGS=-O2 LIBS=-lpthread"
#  generic_download_and_install http://ftp.gnu.org/pub/gnu/gettext/gettext-0.19.8.1.tar.xz gettext-0.19.8.1 "CFLAGS=-O2 CXXFLAGS=-O2 LIBS=-lpthread --without-libexpat-prefix --without-libxml2-prefix"
}

build_pcre() {
  generic_download_and_install https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.bz2 pcre-8.43 "--enable-pcre16 --enable-pcre32 --enable-newline-is-any --enable-jit --enable-utf --enable-pcregrep-libz --enable-pcregrep-libbz2 --enable-pcregrep-libreadline --enable-unicode-properties"
}

build_glib() {
  download_and_unpack_file http://ftp.gnome.org/pub/GNOME/sources/glib/2.62/glib-2.62.4.tar.xz glib-2.62.4 # Was 2.53.1
  export orig_cpu=$cpu_count
#  export cpu_count=1
  cd glib-2.62.4
    export glib_cv_long_long_format=I64
    export glib_cv_stack_grows=no
  #  apply_patch file://${top_dir}/glib-no-tests.patch
    rm aclocal.m4
    apply_patch file://${top_dir}/glib-meson.patch
    # Work around mingw-w64 lacking strerror_s()
#    sed -i.bak 's/strerror_s (buf, sizeof (buf), errnum);/strerror_r (errno, buf, sizeof (buf);/' glib/gstrfuncs.c
    generic_meson_ninja_install "-Dinstalled_tests=false" "meson" "CFLAGS=-DMINGW_HAS_SECURE_API"

    unset glib_cv_long_long_format
    unset glib_cv_stack_grows
    # To ensure gtk uses the latest gdbus-codegen, we must ensure that the glib Python utility by this name
    # appears in our PATH
#    cp -v ${mingw_w64_x86_64_prefix}/bin/gdbus-codegen ${mingw_w64_x86_64_prefix}/../bin/gdbus-codegen
  cd ..
#  export cpu_count=$orig_cpu
}

build_atk() {
download_and_unpack_file http://ftp.gnome.org/pub/GNOME/sources/atk/2.29/atk-2.29.1.tar.xz atk-2.29.1 # Was 2.25.2
  cd atk-2.29.1
    generic_meson_ninja_install
    echo "WE ARE NOW IN DIRECTORY"
    pwd
  cd ..
}

build_atkmm() {
#	do_git_checkout https://github.com/GNOME/atkmm.git atkmm
#	cd atkmm
#		generic_configure_make_install
#	cd ..
	download_and_unpack_file http://ftp.gnome.org/pub/GNOME/sources/atkmm/2.29/atkmm-2.29.1.tar.xz atkmm-2.29.1
	cd atkmm-2.29.1
		generic_configure_make_install
	cd ..
	generic_download_and_install https://ftp.gnome.org/pub/GNOME/sources/atkmm/2.24/atkmm-2.24.3.tar.xz atkmm-2.24.3
}

build_libplacebo() {
  #do_git_checkout https://code.videolan.org/videolan/libplacebo.git libplacebo #3294a29ee0fa103a0558a37123344cee573324e8
  do_git_checkout https://github.com/haasn/libplacebo.git libplacebo e79ea1902ea7c797f5cd2ff2de937a789408c136 # 08b45ede97262d73778f1bee40ac845702e240d4 # 5198e1564c5f2900b7b1f98561b6323d27bd78bb
  cd libplacebo
    #apply_patch file://${top_dir}/libplacebo-win32.patch
    generic_meson_ninja_install
  cd ..
}

build_gdk_pixbuf() {
  download_and_unpack_file http://ftp.gnome.org/pub/GNOME/sources/gdk-pixbuf/2.36/gdk-pixbuf-2.36.12.tar.xz gdk-pixbuf-2.36.12 "--with-libjasper --disable-glibtest --enable-always-build-tests=no --enable-relocations --with-included-loaders=yes --build=x86_64-unknown-linux-gnu"
#  do_git_checkout https://git.gnome.org/browse/gdk-pixbuf gdk-pixbuf
    cd gdk-pixbuf-2.36.12
      apply_patch file://${top_dir}/gdk-pixbuf.patch
      rm -v ./configure
      generic_configure_make_install "--with-libjasper --disable-glibtest --enable-relocations --with-included-loaders=yes --disable-installed-tests --disable-always-build-tests --build=x86_64-unknown-linux-gnu"

  cd ..
}

build_libsigc++() {
  generic_download_and_install https://ftp.gnome.org/pub/GNOME/sources/libsigc++/3.0/libsigc++-3.0.2.tar.xz libsigc++-3.0.2
#  do_git_checkout https://github.com/libsigcplusplus/libsigcplusplus.git libsigcplusplus libsigc++-2-10
#  cd libsigc++-3.0.2
#    orig_aclocalpath=${ACLOCAL_PATH}
#    export ACLOCAL_PATH="${mingw_w64_x86_64_prefix}/share/aclocal"
#    apply_patch file://{$top_dir}/libsigcplusplus.patch
#    generic_configure_make_install

#    export ACLOCAL_PATH=${orig_aclocalpath}
#  cd ..
  generic_download_and_install https://download.gnome.org/sources/libsigc++/2.10/libsigc++-2.10.2.tar.xz libsigc++-2.10.2
# generic_download_and_install https://download.gnome.org/sources/libsigc++/2.99/libsigc++-2.99.8.tar.xz libsigc++-2.99.8
}

build_locked_sstream() {
  do_git_checkout https://github.com/cth103/locked_sstream.git locked_sstream
#  do_git_checkout git://git.carlh.net/git/locked_sstream.git locked_sstream
  cd locked_sstream
    do_configure "configure --prefix=${mingw_w64_x86_64_prefix}" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
  cd ..
}

build_libebml() {
#  do_git_checkout https://github.com/evpobr/libebml.git libebml cmake-export-symbols
#  download_and_unpack_file https://dl.matroska.org/downloads/libebml/libebml-1.3.6.tar.xz libebml-1.3.6
#  cd libebml-1.3.6
#    do_cmake_static "-DCMAKE_CXX_FLAGS=-fpermissive"
#    do_make
#    do_make_install
#  cd ..
	download_and_unpack_file https://github.com/Matroska-Org/libebml/archive/release-1.3.10.tar.gz libebml-release-1.3.10
	cd libebml-release-1.3.10
		do_cmake
		do_make
		do_make_install
	cd ..
}

build_libmatroska() {
        #do_git_checkout https://github.com/Matroska-Org/libmatroska.git libmatroska

	download_and_unpack_file https://github.com/Matroska-Org/libmatroska/archive/release-1.5.2.tar.gz libmatroska-release-1.5.2
	cd libmatroska-release-1.5.2
		do_cmake && ${top_dir}/correct_headers.sh
#		echo "Environment is: "
#		env
#		exit 1
		do_make
		do_make_install
	cd ..
#   cd libmatroska-1.4.8
#       apply_patch file://${top_dir}/libmatroska-typo.patch
#       do_cmake "-DCMAKE_VERBOSE_MAKEFILE=YES -DCMAKE_CXX_FLAGS=-fpermissive -DCMAKE_C_FLAGS=-fpermissive" && ${top_dir}/correct_headers.sh # "-DCMAKE_CXX_FLAGS=-fpermissive"
#       do_make "VERBOSE=1"
#       do_make_install
#   cd ..
}

build_1394camera() {
  cp -v ${top_dir}/1394camera.dll ${mingw_w64_x86_64_prefix}/bin/1394camera.dll
  cp -v ${top_dir}/lib1394camera.a ${mingw_w64_x86_64_prefix}/lib/lib1394camera.a
  cp -v ${top_dir}/1394*h ${mingw_w64_x86_64_prefix}/include
}

build_libdc1394() {
  do_git_checkout https://github.com/astraw/dc1394.git libdc1394
  cd libdc1394/libdc1394
    generic_configure_make_install

  cd ../..
}

build_libcxml(){
  do_git_checkout https://github.com/cth103/libcxml.git libcxml 9fb7d466379c0943c22d3e1f0bc51d737e493d7d # 4dfe693bbe01810274f370a7e791a9f508f7e8f6
#  download_and_unpack_file http://carlh.net/downloads/libcxml/libcxml-0.15.1.tar.bz2 libcxml-0.15.1
  cd libcxml
#    apply_patch file://${top_dir}/libcxml-shared_ptr.patch
    export ORIG_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
    export CC=${cross_prefix}gcc
    export CXX=${cross_prefix}g++
    export PKG_CONFIG_PATH="${mingw_w64_x86_64_prefix}/lib/pkgconfig"
    export CXXFLAGS=-fpermissive
    # libdir must be set
    # We have to tell wscript not to look in /usr/local/lib. This ought not to be hard-coded
    sed -i.bak "s!libpath='/usr/local/!libpath='${mingw_w64_x86_64_prefix}/!" wscript
    apply_patch file://${top_dir}/libcxml-boost.patch
    do_configure "configure --target-windows -vv -pp --prefix=${mingw_w64_x86_64_prefix} --check-cxx-compiler=gxx" "./waf" # --libdir=${mingw_w64_x86_64_prefix}/lib WINRC=x86_64-w64-mingw32-windres CXX=x86_64-w64-mingw32-g++
    ./waf build || exit 1
    ./waf install || exit 1
    # The installation puts the pkgconfig file and the DLL import library in the wrong place
    cp -v build/libcxml.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    cp -v build/src/libcxml.dll.a ${mingw_w64_x86_64_prefix}/lib
    export PKG_CONFIG_PATH=$ORIG_PKG_CONFIG_PATH
    unset CXXFLAGS CC CXX
  cd ..
}

build_glibmm() {
  # Because our threading model for our GCC does not involve posix threads, we must emulate them with
  # the Boost libraries. These provide an (almost) drop-in replacement.
  # VERSION WARNING: glibmm-2.51 breaks compatibility. You have to read the documentation to learn this.
#  export GLIBMM_LIBS="-lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lboost_system-mt-x64 -lsigc-2.0 -lboost_thread-mt-x64"
#  export GIOMM_LIBS="-lgio-2.0 -lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lboost_system-mt-x64 -lsigc-2.0"
#  export NOCONFIGURE=1
  download_and_unpack_file http://ftp.gnome.org/pub/GNOME/sources/glibmm/2.63/glibmm-2.63.1.tar.xz glibmm-2.63.1
  cd glibmm-2.63.1
#    apply_patch file://${top_dir}/glibmm-2.63.1-mutex1.patch
#    apply_patch file://${top_dir}/glibmm-2.63.1-mutex2.patch
    generic_configure_make_install "--disable-silent-rules"
  cd ..
#  do_git_checkout https://github.com/GNOME/glibmm.git glibmm glibmm-2-52
#  cd glibmm
#    orig_aclocalpath=${ACLOCAL_PATH}
#    export ACLOCAL_PATH="/usr/local/share/aclocal"
#    export GLIBMM_LIBS="-lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lboost_system -lsigc-2.0 -lboost_thread_win32"
#    export GIOMM_LIBS="-lgio-2.0 -lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lboost_system -lsigc-2.0"
#  download_and_unpack_file ftp://ftp.gnome.org/mirror/gnome.org/sources/glibmm/2.53/glibmm-2.53.1.1.tar.xz glibmm-2.53.1.1
#  cd glibmm-2.53.1.1
#    apply_patch file://${top_dir}/glibmm-2.53-mutex.patch
#    rm -v configure
#    generic_configure_make_install "NOCONFIGURE=1 --disable-silent-rules --disable-deprecated-api"
#  cd ..
 # export ACLOCAL_PATH=${orig_aclocalpath}
#  unset GLIBMM_LIBS
#  unset GIOMM_LIBS
#  unset NOCONFIGURE
  download_and_unpack_file https://ftp.gnome.org/pub/GNOME/sources/glibmm/2.62/glibmm-2.62.0.tar.xz glibmm-2.62.0
  cd glibmm-2.62.0
#    apply_patch file://${top_dir}/glibmm-2.62.0-mutex.patch
    generic_configure_make_install "--disable-silent-rules"
  cd ..
  download_and_unpack_file https://ftp.gnome.org/pub/GNOME/sources/glibmm/2.61/glibmm-2.61.1.tar.xz glibmm-2.61.1
  cd glibmm-2.61.1
#    apply_patch file://${top_dir}/glibmm-2.61.1-mutex.patch
    generic_configure_make_install "--disable-silent-rules"
  cd ..
  download_and_unpack_file https://ftp.gnome.org/pub/GNOME/sources/glibmm/2.59/glibmm-2.59.1.tar.xz glibmm-2.59.1
  cd glibmm-2.59.1
#    apply_patch file://${top_dir}/glibmm-2.59.1-mutex.patch
    generic_configure_make_install "--disable-silent-rules"
  cd ..
}

build_libxml++ () {
#  orig_aclocalpath=${ACLOCAL_PATH}
#  export ACLOCAL_PATH="/usr/local/share/aclocal"
#  download_and_unpack_file http://ftp.gnome.org/pub/GNOME/sources/libxml++/2.40/libxml++-2.40.1.tar.xz libxml++-2.40.1
  do_git_checkout https://github.com/GNOME/libxmlplusplus.git libxmlplusplus
  cd libxmlplusplus
#  cd libxml++-2.40.1
    rm -v configure
#    apply_patch file://${top_dir}/libxml++-2.4-ac.patch
    generic_configure_make_install

  cd ..
#  do_git_checkout https://git.gnome.org/browse/libxml++ libxml++
#  cd libxml++
#    generic_configure_make_install
#  cd ..
#  generic_download_and_install https://git.gnome.org/browse/libxml++/snapshot/libxml++-3.0.1.tar.xz libxml++-3.0.1
#  export ACLOCAL_PATH=${orig_aclocalpath}
  generic_download_and_install http://ftp.gnome.org/pub/GNOME/sources/libxml++/2.40/libxml++-2.40.1.tar.xz libxml++-2.40.1
}

build_libexif() {
  do_git_checkout https://github.com/libexif/libexif.git libexif  #a459ed1dca57612ef13880e8d78037db2f089f13
  cd libexif
    # We need to update autotools because a check is needed for JPEG files > 2GB
    #rm configure
    generic_configure_make_install

  cd ..
}

build_libzip() {
  download_and_unpack_file http://www.nih.at/libzip/libzip-1.5.1.tar.xz libzip-1.5.1
  cd libzip-1.5.1
    do_cmake
    do_make
    do_make_install
  cd ..
}

build_uchardet() {
#do_git_checkout git://anongit.freedesktop.org/uchardet/uchardet uchardet
  download_and_unpack_file https://www.freedesktop.org/software/uchardet/releases/uchardet-0.0.6.tar.xz uchardet-0.0.6
    cd uchardet-0.0.6
        do_cmake "-DTARGET_ARCHITECTURE=x86"
        do_make
        do_make_install
    cd ..
}

build_zstd() {
    do_git_checkout https://github.com/facebook/zstd.git zstd 6b7a1d6127a0306731d4f98a0da2b9e91c078242
    cd zstd/build/cmake
        do_cmake
        do_make
        do_make_install
    cd ../../..
}

build_flacon() {
    do_git_checkout https://github.com/flacon/flacon.git flacon
        cd flacon
        do_cmake && ${top_dir}/correct_headers.sh
        do_make
        do_make_install
    cd ..
}

build_exif() {
  download_and_unpack_file https://downloads.sourceforge.net/project/libexif/exif/0.6.21/exif-0.6.21.tar.bz2 exif-0.6.21
  cd exif-0.6.21
    rm configure
    # Inclusion of langinfo.h is not needed, and doesn't exist in MinGW-w64
    sed -i.bak 's!#  include <langinfo.h>!/*#  include <langinfo.h> */!' exif/exif-i18n.c
    # exif calls a bad autoconfig macro for locating popt. We must, therefore, explicitly
    # tell it where our cross-compiled libpopt is located.
    generic_configure_make_install "POPT_CFLAGS=-I${mingw_w64_x86_64_prefix}/include POPT_LIBS=-L${mingw_w64_x86_64_prefix}/lib LIBS=-lpopt"

  cd ..
}

build_hdf() {
	download_and_unpack_file https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.6/src/hdf5-1.10.6.tar.bz2 hdf5-1.10.6
	cd hdf5-1.10.6
		mkdir -pv build
		cd build
			do_cmake ..
			do_make
			do_make_install
		cd ..
	cd ..
#  generic_download_and_install http://www.hdfgroup.org/ftp/HDF5/current/src/hdf5-1.8.19.tar.bz2 hdf5-1.8.19
#  cd hdf5-1.10.1

#  cd ..
}

build_netcdf() {
  do_git_checkout https://github.com/Unidata/netcdf-c.git netcdf-c #383f1cbe321e16ec82c6eb8e1774e16d8ed1962c
  cd netcdf-c
    apply_patch file://${top_dir}/netcdf-shared.patch
#    apply_patch file://${top_dir}/netcdf-errno.patch
#    apply_patch file://${top_dir}/netcdf-gcc.patch
#    apply_patch file://${top_dir}/netcdf-mingw.patch
    apply_patch file://${top_dir}/netcdf-getopt.patch
    generic_configure_make_install "--enable-dll --disable-netcdf4"
  cd ..
#  generic_download_and_install ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-4.5.0.tar.gz netcdf-4.5.0 "--enable-dll --disable-netcdf4"
#  cd netcdf-4.5.0

#  cd ..
}

build_vlc() {
  # VLC normally requires its own libraries to be linked. However, it in fact builds with latest
  # versions of everything compiled here. At the moment..
  do_git_checkout https://code.videolan.org/videolan/vlc.git vlc # 7b81168938cf2fd2217cbc5bf701ab23ad8655b9 # a047b31b978e4a3bd86b3c1a8f7dec9281d1a056
  cd vlc
    unset CFLAGS
    unset CXXFLAGS
    export LIBS="-lwinmm"
    export CFLAGS="-fpermissive"
    export CXXFLAGS="-fpermissive"
    apply_patch file://${top_dir}/vlc-qt5.patch
    apply_patch file://${top_dir}/vlc-more-static.patch
#    apply_patch file://${top_dir}/vlc-dxgi.patch
    apply_patch file://${top_dir}/vlc-dll-dirs.patch
    apply_patch file://${top_dir}/vlc-aom.patch
#    apply_patch file://${top_dir}/vlc-vpx.patch
#    apply_patch file://${top_dir}/vlc-d3d11-deinterlace.patch
    apply_patch file://${top_dir}/vlc-stack.patch
    apply_patch file://${top_dir}/vlc-fortify.patch
    export LIVE555_CFLAGS="-I${mingw_w64_x86_64_prefix}/include/liveMedia -I${mingw_w64_x86_64_prefix}/include/UsageEnvironment -I${mingw_w64_x86_64_prefix}/include/BasicUsageEnvironment -I${mingw_w64_x86_64_prefix}/include/groupsock"
    export DSM_LIBS="-lws2_32 -ldsm"
    export AOM_LIBS="-laom -lpthread -lm"
    export BUILDCC=/usr/bin/gcc
    export cpu_count=1
    generic_configure_make_install "--disable-medialibrary --enable-qt --disable-dvbpsi --disable-gst-decode --disable-asdcp --disable-opencv --disable-ncurses --disable-dbus --disable-sdl --disable-telx --disable-silent-rules --disable-pulse JACK_LIBS=-ljack JACK_CFLAGS=-L${mingw_w64_x86_64_prefix}/../lib LIVE555_LIBS=-llivemedia ASDCP_LIBS=lasdcp ASDCP_CFLAGS=-I${mingw_w64_x86_64_prefix}/include/asdcp"
    # X264 is disabled because of an API change. We ought to be able to re-enable it when vlc has caught up.
    export cpu_count=8
  cd ..
}

build_meson_cross() {
    rm -fv meson-cross.mingw.txt
    echo "[binaries]" >> meson-cross.mingw.txt
    echo "c = '${cross_prefix}gcc'" >> meson-cross.mingw.txt
    echo "cpp = '${cross_prefix}g++'" >> meson-cross.mingw.txt
    echo "ar = '${cross_prefix}ar'" >> meson-cross.mingw.txt
    echo "strip = '${cross_prefix}strip'" >> meson-cross.mingw.txt
    echo "pkgconfig = '${cross_prefix}pkg-config'" >> meson-cross.mingw.txt
    echo "nm = '${cross_prefix}nm'" >> meson-cross.mingw.txt
    echo "windres = '${cross_prefix}windres'" >> meson-cross.mingw.txt
#    echo "[properties]" >> meson-cross.mingw.txt
#    echo "needs_exe_wrapper = true" >> meson-cross.mingw.txt
    echo "[host_machine]" >> meson-cross.mingw.txt
    echo "system = 'windows'" >> meson-cross.mingw.txt
    echo "cpu_family = 'x86_64'" >> meson-cross.mingw.txt
    echo "cpu = 'x86_64'" >> meson-cross.mingw.txt
    echo "endian = 'little'" >> meson-cross.mingw.txt
    mv -v meson-cross.mingw.txt ../..
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
  do_git_checkout https://github.com/gpac/gpac.git mp4box_gpac
  cd mp4box_gpac
#    apply_patch file://${top_dir}/mp4box-dashcast.patch
  # are these tweaks needed? If so then complain to the mp4box people about it?
  # sed -i "s/has_dvb4linux=\"yes\"/has_dvb4linux=\"no\"/g" configure
  # sed -i "s/`uname -s`/MINGW32/g" configure
  # XXX do I want to disable more things here?
    sed -i.bak 's#bin/gcc/MP4Box #bin/gcc/MP4Box.exe #' Makefile
    sed -i.bak 's#bin/gcc/MP42TS #bin/gcc/MP42TS.exe #' Makefile
    sed -i.bak 's#bin/gcc/MP4Client #bin/gcc/MP4Client.exe #' Makefile
  # The Makefile for the jack module has a hard-coded library search path. This is bad.
    sed -i.bak 's#/bin/gcc -lgpac -L/usr/lib#/bin/gcc -lgpac -L${mingw_w64_x86_64_prefix}/lib#' modules/jack/Makefile
  # The object dll seems to have the wrong link
    sed -i.bak 's#FLAGS) -m 755 bin/gcc/libgpac\.dll\.a \$(DESTDIR)\$(prefix)/\$(libdir)#FLAGS) -m 755 bin/gcc/libgpac.dll $(DESTDIR)$(prefix)/$(libdir)/libgpac.dll.a#' Makefile
#  sed -i.bak 's/	$(MAKE) installdylib/#	$(MAKE) installdylib/' Makefile
#  sed -i.bak 's/-DDIRECTSOUND_VERSION=0x0500/-DDIRECTSOUND_VERSION=0x0800/' src/Makefile
#  generic_configure_make_install "--verbose --static-mp4box --enable-static-bin --target-os=MINGW32 --cross-prefix=x86_64-w64-mingw32- --prefix=${mingw_w64_x86_64_prefix} --static-mp4box --extra-libs=-lz --enable-all --enable-ffmpeg"
    generic_configure_make_install "--enable-ipv6 --verbose --target-os=MINGW32 --cross-prefix=x86_64-w64-mingw32- --prefix=${mingw_w64_x86_64_prefix} --extra-libs=-lz --enable-all --enable-ffmpeg --disable-pulseaudio"

  # All the modules need moving into the main binary directory for GPAC's default configuration file to be correct.
    mv -fv ${mingw_w64_x86_64_prefix}/lib/gpac/* ${mingw_w64_x86_64_prefix}/bin

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

build_pango() {
  generic_download_and_install http://ftp.gnome.org/pub/gnome/sources/pango/1.42/pango-1.42.1.tar.xz pango-1.42.1 # Was .6
  cd pango-1.42.1

  cd ..
}

build_pangomm() {
  # VERSION WARNING Pango-2.41 breaks compatibility
  export PANGOMM_LIBS="-lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lglibmm-2.4 -lgio-2.0 -lboost_system-mt-x64 -lsigc-2.0 -lboost_thread-mt-x64 -lboost_system-mt-x64 -lcairo -lcairomm-1.0 -lpango-1.0 -lpangocairo-1.0"
  generic_download_and_install http://ftp.gnome.org/pub/GNOME/sources/pangomm/2.40/pangomm-2.40.1.tar.xz pangomm-2.40.1
  cd pangomm-2.40.1

  cd ..
  unset PANGOMM_LIBS
}

build_mimedb() {
  export orig_cpu_count=$cpu_count
  export cpu_count=1
  # The installer barfs if this directory doesn't exist.
#  mkdir -v -p ${mingw_w64_x86_64_prefix}/share/mime/packages
  generic_download_and_install http://freedesktop.org/~hadess/shared-mime-info-1.9.tar.xz shared-mime-info-1.9 "--disable-update-mimedb"
  cd shared-mime-info-1.9

  cd ..
  export cpu_count=$orig_cpu_count
}

build_qjackctl() {
  do_git_checkout https://github.com/rncbc/qjackctl.git qjackctl e76e58ea6e67b74ab1fcc539a4d1f18ea0686144 # b2ae94121d368bb2498a3fa09173e99263fe8c39 # 568b076f1ddd0fcb18a78828e0e5b833e52fd7a1
  cd qjackctl
#    apply_patch file://${top_dir}/qjackctl-MainForm.patch
    generic_configure_make_install "LIBS=-lportaudio --enable-xunique=no --disable-alsa-seq" # enable-jack-version=yes
    # make install doesn't work
    cp -vf src/release/qjackctl.exe ${mingw_w64_x86_64_prefix}/bin

  cd ..
}

build_spirvtools() {
do_git_checkout https://github.com/KhronosGroup/SPIRV-Headers.git SPIRV-Headers # 3ce3e49d73b8abbf2ffe33f829f941fb2a40f552
do_git_checkout https://github.com/KhronosGroup/SPIRV-Tools.git SPIRV-Tools # 2d9a325264e3fc81317acc0a68a098f0546c352d # fe2fbee294a8ad4434f828a8b4d99eafe9aac88c
    cd SPIRV-Tools
        ln -svf ../../SPIRV-Headers external
        # apply_patch file://${top_dir}/SPIRV-Tools-shared.patch
        do_cmake_static "-DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=ON -DSPIRV_WERROR=OFF"
        do_make
        do_make_install
    cd ..
}

build_glslang() {
    do_git_checkout https://github.com/KhronosGroup/glslang.git glslang #135e3e35ea87d07b51d977b73fde7bd637fcbe4a 
    #download_and_unpack_file https://github.com/KhronosGroup/glslang/archive/6.2.2596.tar.gz glslang-6.2.2596
    cd glslang #-6.2.2596
        #apply_patch_p1 https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-glslang/001-install-missing-dll.patch
        #apply_patch file://${top_dir}/glslang-threads.patch
    #    apply_patch file://${top_dir}/glslang-shared.patch
        do_cmake_static "-DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=YES"
        do_make "V=1"
        do_make_install
    cd ..
#    ln -s ${mingw_w64_x86_64_prefix}/include/glslang/SPIRV ${mingw_w64_x86_64_prefix}/include/SPIRV
}

build_shaderc() {
    do_git_checkout https://github.com/google/shaderc.git shaderc #14ae0de47d34f14e09ae1c64327cd39c32c8f693 # a2c044c44d68c31014210f9b37a682d118c40388 # be8e0879750303a1de09385465d6b20ecb8b380d
    cd shaderc
        export spirv-tools_SOURCE_DIR=${top_dir}/x86_64/SPIRV-Tools/
        export glslang_SOURCE_DIR=${top_dir}/x86_64/glslang/
        export shaderc_SOURCE_DIR=${top_dir}/x86_64/shaderc/
        apply_patch file://${top_dir}/shaderc.patch
        mkdir build
        cd build
        do_cmake_static ".." "-GNinja -DSHADERC_SKIP_TESTS=ON -DCMAKE_VERBOSE_MAKEFILE=YES " #-DSHADERC_ENABLE_SHARED_CRT=ON" # -DSHADERC_ENABLE_SHARED_CRT=ON"
        apply_patch file://${top_dir}/shaderc-build-new.patch
        cd ..
	cd libshaderc/src
		ln -s ${mingw_w64_x86_64_prefix}/include/glslang/SPIRV SPIRV
	cd ../..
	cd libshaderc_util/src
		ln -s ${mingw_w64_x86_64_prefix}/include/glslang/SPIRV SPIRV
	cd ../..
	cd libshaderc_util
		mkdir glslang
		cd glslang
			ln -s -v ${mingw_w64_x86_64_prefix}/include/glslang/MachineIndependent MachineIndependent
			ln -s -v ${mingw_w64_x86_64_prefix}/include/glslang/Include Include
		cd ..
	cd ..
        do_ninja_and_ninja_install "V=1"
#        do_make_install
    cd ..
}


build_vulkan() {

    #download_and_unpack_file https://github.com/KhronosGroup/Vulkan-Loader/archive/sdk-1.1.73.0.tar.gz Vulkan-Loader-sdk-1.1.73.0
    #download_and_unpack_file https://github.com/KhronosGroup/Vulkan-Headers/archive/sdk-1.1.92.0.tar.gz Vulkan-Headers-sdk-1.1.92.0
    download_and_unpack_file https://github.com/KhronosGroup/Vulkan-Headers/archive/v1.2.133.tar.gz Vulkan-Headers-1.2.133
    #cd Vulkan-Loader-sdk-1.1.73.0
    cd Vulkan-Headers-1.2.133
        do_cmake
        do_make
        do_make_install
    cd ..
    download_and_unpack_file https://github.com/KhronosGroup/Vulkan-Loader/archive/v1.2.133.tar.gz Vulkan-Loader-1.2.133
    cd Vulkan-Loader-1.2.133
        #apply_patch_p1 file://${top_dir}/001-build-fix.patch
        #apply_patch_p1 file://${top_dir}/002-proper-def-files-for-32bit.patch
        #apply_patch_p1 file://${top_dir}/003-generate-pkgconfig-files.patch
        #apply_patch_p1 file://${top_dir}/004-installation-commands.patch
        #apply_patch_p1 file://${top_dir}/005-mingw-dll-name.patch
        #apply_patch file://${top_dir}/006-commit.patch
        apply_patch_p1 https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-vulkan-loader/001-build-fix.patch
        apply_patch_p1 https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-vulkan-loader/002-proper-def-files-for-32bit.patch
        apply_patch_p1 https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-vulkan-loader/003-generate-pkgconfig-files.patch
        #echo "#define SPIRV_TOOLS_COMMIT_ID \"8d8a71278bf9e83dd0fb30d5474386d30870b74d\"" > spirv_tools_commit_id.h
        #cp -fv spirv_tools_commit_id.h loader/
        # Missing defines are already added to MinGW by our scripts earlier in the build process.
        export CFLAGS="-D_WIN32_WINNT=0x0A00 -D__STDC_FORMAT_MACROS"
        export CPPFLAGS="-D_WIN32_WINNT=0x0A00 -D__STDC_FORMAT_MACROS"
        export CXXFLAGS="-D_WIN32_WINNT=0x0A00 -D__USE_MINGW_ANSI_STDIO -D__STDC_FORMAT_MACROS -fpermissive"
        do_cmake "-DCMAKE_BUILD_TYPE=Release -DBUILD_DEMOS=OFF -DBUILD_TESTS=OFF" # -DDISABLE_BUILD_PATH_DECORATION=ON -DDISABLE_BUILDTGT_DIR_DECORATION=ON"
        #apply_patch file://${top_dir}/vulkan-threads.patch
        apply_patch file://${top_dir}/vulkan-cfgmgr.patch
        do_make
        do_make_install
        unset CFLAGS
        unset CPPFLAGS
        unset CXXFLAGS
    cd ..
}


build_angle() {
#  do_git_checkout https://chromium.googlesource.com/angle/angle angle # dd1b0c485561e0ce825a9426d7e223b4e158a358 # 57ce9ea23e54e7beb0526502bdf9094d1ddfde68 # 9f09037b073a7481bc5d94984a26b7c9d3427b16
    # If Angle has been built, then skip the whole process because Git barfs
    if [[ ! -f "angle/already_built_angle" ]]; then
      echo "Angle not built: building from scratch."
      do_git_checkout https://github.com/google/angle.git angle 76c1d14b8e212db9822a6398343a344ff9028298 # fa7cc9da878b1eba4df568084b97a981e046709c
      cd angle
        # remove .git directory to prevent: No rule to make target '../build-x86_64/.git/index', needed by 'out/Debug/obj/gen/angle/id/commit.h'.
        rm -rvf .git || exit 1
        # These patches from the AUR linux project
#        apply_patch_p1 file://${top_dir}/angle-Fix-dynamic-libraries.patch
#        apply_patch_p1 file://${top_dir}/angle-Link-against-dxguid-d3d9-and-gdi32.patch
#        apply_patch_p1 file://${top_dir}/angle-Export-shader-API-via-libGLESv2.dll.patch
#        apply_patch_p1 file://${top_dir}/angle-Make-GLintptr-and-GLsizeiptr-match-those-from-Qt-5.patch
#        apply_patch_p1 file://${top_dir}/angle-Remove-copy_scripts-target.patch
#        apply_patch_p1 file://${top_dir}/angle-Fix-generation-of-commit_id.h.patch
#        # These are my patches to work around VC-only functions
#        apply_patch file://${top_dir}/angle-string_utils-cpp.patch
#        apply_patch file://${top_dir}/angle-RendererD3D-cpp.patch
#        apply_patch file://${top_dir}/angle-future.patch
        # executing .bat scripts on Linux is a no-go so make this a no-op

        echo "" > src/copy_compiler_dll.bat
        chmod +x src/copy_compiler_dll.bat
        # provide a file to export symbols declared in ShaderLang.h as part of libGLESv2.dll
        # (required to build Qt WebKit which uses shader interface)
    #    cp ${top_dir}/angle-entry_points_shader.cpp src/libGLESv2/entry_points_shader.cpp
        apply_patch_p1 file://${top_dir}/0000-build-fix.patch
        apply_patch_p1 https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-angleproject-git/angleproject-include-import-library-and-use-def-file.patch
        apply_patch_p1 https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-angleproject-git/0001-static-build-workaround.patch
        apply_patch_p1 https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-angleproject-git/0002-redist.patch
        mkdir -pv build-x86_64
        cd build-x86_64
          export CXX=x86_64-w64-mingw32-g++
          export AR=x86_64-w64-mingw32-ar
          old_cxxflags=${CXXFLAGS}
          export CXXFLAGS="-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions --param=ssp-buffer-size=4 -std=c++14 -msse2 -DANGLE_STD_ASYNC_WORKERS=ANGLE_DISABLED -DUNICODE -D_UNICODE -I./../src -I./../include -I./../src/common/third_party/numerics -I./../src/common/third_party/base"
          # Prepare the Makefile
          gyp -D angle_enable_vulkan=0 -D use_ozone=0 -D OS=win -D TARGET=win64 --format make -DMSVS_VERSION="" --depth . -I ../gyp/common.gypi ../src/angle.gyp
          make V=1 LIBS="-lmingw32 -lm -lsetupapi -ldinput8 -ldxguid -ldxerr8 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -lshell32 -lversion -luuid -ld3d9 -ld3d11" -j $cpu_count || exit 1
          # The libraries are built but have the wrong suffix
          # There is no make install target
          cp -v out/Debug/src/libGLESv2.so "${mingw_w64_x86_64_prefix}/bin/libGLESv2.dll"
          cp -v out/Debug/src/libEGL.so "${mingw_w64_x86_64_prefix}/bin/libEGL.dll"
          cp -v libGLESv2.dll.a libEGL.dll.a out/Debug/src/lib*.a "${mingw_w64_x86_64_prefix}/lib/"
          cp -Rv ../include/* "${mingw_w64_x86_64_prefix}/include/"
          unset CXX
          unset AR
          export CXXFLAGS=${old_cxxflags}
        cd ..
      touch already_built_angle

      cd ..
    else
      echo "Angle already built. Not making it again."
    fi
}

build_libepoxy() {
  generic_download_and_install https://github.com/anholt/libepoxy/releases/download/1.5.2/libepoxy-1.5.2.tar.xz libepoxy-1.5.2 # Was 1.3.1
  cd libepoxy-1.5.2

  cd ..
#  do_git_checkout https://github.com/anholt/libepoxy.git libepoxy
#  cd libepoxy
#    generic_configure_make_install
#    do_cmake_and_install "-DEPOXY_BUILD_SHARED=ON -DEPOXY_BUILD_STATIC=OFF"
#  cd ..
}

build_librsvg() {
  generic_download_and_install https://download.gnome.org/sources/librsvg/2.42/librsvg-2.42.4.tar.xz librsvg-2.42.4 "--disable-introspection"
}

build_cuetools() {
  do_git_checkout https://github.com/svend/cuetools.git cuetools
  cd cuetools
    generic_configure_make_install

  cd ..
}

build_turingcodec() {
  do_git_checkout https://github.com/bbc/turingcodec.git turingcodec
  cd turingcodec
    do_cmake
    do_make
    do_make_install

  cd ..
}

build_dbus() {
  generic_download_and_install https://dbus.freedesktop.org/releases/dbus/dbus-1.12.8.tar.gz dbus-1.12.8
  cd dbus-1.12.8

  cd ..
}

build_libcroco() {
  generic_download_and_install http://ftp.gnome.org/pub/GNOME/sources/libcroco/0.6/libcroco-0.6.12.tar.xz libcroco-0.6.12
}

build_lash() {
  do_git_checkout https://git.savannah.gnu.org/git/lash.git lash
  cd lash
    generic_configure_make_install --with-python=no --with-alsa=no --with-jack-dbus=no

  cd ..
}

build_pngcrush() {
  do_git_checkout https://git.code.sf.net/p/pmt/code pngcrush pngcrush
  cd pngcrush
    apply_patch file://{$top_dir}/pngcrush.patch
    do_make
    cp -v pngcrush.exe ${mingw_w64_x86_64_prefix}/bin/pngcrush.exe

  cd ..
}

build_eigen() {
  do_git_checkout https://github.com/eigenteam/eigen-git-mirror.git eigen-git-mirror #54d243db458f88b716deafb5ac1da5d7ffde4a78
#  download_and_unpack_file http://bitbucket.org/eigen/eigen/get/3.3.5.tar.bz2 eigen-eigen-b3f3d4950030
#  cd eigen-eigen-b3f3d4950030
    cd eigen-git-mirror
    mkdir -pv build
    cd build
      export FC=${cross_prefix}gfortran
      do_cmake ..
      do_make_install
# Need to put the pkgconfig file in the right place
      cp -v eigen3.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
      unset FC
    cd ..

#    mkdir -v -p ${mingw_w64_x86_64_prefix}/include/Eigen || exit 1
#    cp -Rvf Eigen/* ${mingw_w64_x86_64_prefix}/include/Eigen || exit 1
#    # But we must install eigen3.pc manually
#    sed -i.bak "s!@CMAKE_INSTALL_PREFIX@!${mingw_w64_x86_64_prefix}!" eigen3.pc.in
#    sed -i.bak "s/@EIGEN_VERSION_NUMBER@/3.3.2/" eigen3.pc.in
#    sed -i.bak "s!@INCLUDE_INSTALL_DIR@!include!" eigen3.pc.in
#    cp -v eigen3.pc.in ${mingw_w64_x86_64_prefix}/lib/pkgconfig/eigen3.pc
  cd ..
}

build_movit() {
  do_git_checkout https://git.sesse.net/movit movit
  cd movit
    apply_patch file://${top_dir}/movit-ffs.patch
    apply_patch file://${top_dir}/movit-call_once.patch # Revert thread use not available
    apply_patch file://${top_dir}/movit-resample.patch # GCC and Eigen don't get on here
    export GTEST_DIR=../googletest/googletest
    old_CFLAGS=${CFLAGS}
    old_CXXFLAGS=${CXXFLAGS}
    export CFLAGS="-fpermissive -std=c++11"
    export CXXFLAGS="-fpermissive -std=c++11"
    generic_configure_make_install
    CFLAGS=${old_CFLAGS}
    CXXFLAGS=${old_CXXFLAGS}

    unset GTEST_DIR
  cd ..
}

build_aom() {
  do_git_checkout https://aomedia.googlesource.com/aom aom  # bbe0a0a1cd34dc5aa9040f1d8b68468f32b895e4
  cd aom
    old_LDFLAGS=${LDFLAGS}
    old_CFLAGS=${CFLAGS}
    old_CXXFLAGS=${CFLAGS}
    old_CC=${CC}
    old_LD=${LD}
    old_AR=${AR}
    old_CXX=${CXX}
    export LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib
    export CFLAGS=-I${mingw_w64_x86_64_prefix}/include
    export CXXFLAGS=-I${mingw_w64_x86_64_prefix}/include
    export CC=x86_64-w64-mingw32-gcc
    export LD=x86_64-w64-mingw32-ld
    export AR=x86_64-w64-mingw32-ar
    export CXX=x86_64-w64-mingw32-g++
#    apply_patch file://${top_dir}/aom-pthread.patch
#    do_configure "--target=x86_64-win64-gcc --prefix=${mingw_w64_x86_64_prefix} --enable-webm-io --enable-pic --enable-multithread --enable-runtime-cpu-detect --enable-postproc --enable-av1 --enable-lowbitdepth --disable-unit-tests"
    mkdir -pv ../aom_build
    cd ../aom_build
    do_cmake_static ../aom/. "-DAOM_TARGET_CPU=x86_64 -DCONFIG_FILEOPTIONS=1 -DCONFIG_LOWBITDEPTH=0 -DCONFIG_HIGHBITDEPTH=1 -DHAVE_PTHREAD=1 -DCMAKE_TOOLCHAIN_FILE=../aom/build/cmake/toolchains/x86_64-mingw-gcc.cmake"
      do_make
      do_make_install
    cd ../aom

    export LDFLAGS=${old_LDFLAGS}
    export CFLAGS=${old_CFLAGS}
    export CXXFLAGS=${old_CXXFLAGS}
    export CC=${old_CC}
    export AR=${old_AR}
    export LD=${old_LD}
    export CXX=${old_CXX}
  cd ..
}

build_libdash() {
  do_git_checkout https://github.com/bitmovin/libdash.git libdash
  cd libdash
    apply_patch file://${top_dir}/libdash-case-fix.patch
    cd libdash
      do_cmake "-DCMAKE_CXX_FLAGS=-D_WIN32_WINNT=0x0A00"
      # Winsock is missed out. I don't know why.
      sed -i.bak 's/ -lxml2 -lkernel32/ -lxml2 -lws2_32 -lkernel32/' libdash_networkpart_test/CMakeFiles/libdash_networkpart_test.dir/linklibs.rsp
      do_make
      # We need to install manually
      cp -vf bin/libdash.dll ${mingw_w64_x86_64_prefix}/bin/libdash.dll
      cp -vf bin/libdash.dll.a ${mingw_w64_x86_64_prefix}/lib/libdash.dll.a
      mkdir -pv  ${mingw_w64_x86_64_prefix}/include/libdash
      cp -vf libdash/include/*h  ${mingw_w64_x86_64_prefix}/include/libdash/
      cd qtsampleplayer
        do_cmake && ${top_dir}/correct_headers.sh
        do_make "VERBOSE=1"
        cp -vf qtsampleplayer.exe ${mingw_w64_x86_64_prefix}/bin/qtsampleplayer.exe

      cd ..

  cd ../..
}

build_synaesthesia() {
  do_git_checkout https://github.com/dreamlayers/synaesthesia.git synaesthesia
  cd synaesthesia
    apply_patch file://${top_dir}/synaesthesia-case.patch
    apply_patch file://${top_dir}/synaesthesia-missing-icon.patch
    export LIBS="-lmingw32 -lSDL2main"
    generic_configure_make_install "CXXFLAGS=-fpermissive --with-sdl2=yes"

    unset LIBS
  cd ..
}

build_harfbuzz() {
  download_and_unpack_file https://www.freedesktop.org/software/harfbuzz/release/harfbuzz-2.1.3.tar.bz2 harfbuzz-2.1.3
#  download_and_unpack_file https://www.freedesktop.org/software/harfbuzz/release/harfbuzz-1.7.6.tar.bz2 harfbuzz-1.7.6
#  do_git_checkout https://github.com/behdad/harfbuzz.git harfbuzz
  cd harfbuzz-2.1.3
    generic_configure_make_install

  cd ..
}

build_pulseaudio() {
  download_and_unpack_file https://freedesktop.org/software/pulseaudio/releases/pulseaudio-13.99.1.tar.xz pulseaudio-13.99.1
    cd pulseaudio-13.99.1
        apply_patch file://${top_dir}/pulseaudio-size.patch
	apply_patch file://${top_dir}/pulseaudio-conf.patch
        generic_configure_make_install "LIBS=-lintl --enable-orc --enable-waveout --disable-silent-rules --disable-gsettings --disable-dbus" # "LIBS=-lintl --enable-orc --enable-waveout --disable-silent-rules -disable-gsettings --disable-dbus"
        # Main library is in wrong place for our paths
        cp -vf ${mingw_w64_x86_64_prefix}/lib/pulseaudio/*dll ${mingw_w64_x86_64_prefix}/bin
        cp -vf ${mingw_w64_x86_64_prefix}/lib/pulse-13.0/bin/*dll ${mingw_w64_x86_64_prefix}/bin
        cp -vf ${mingw_w64_x86_64_prefix}/lib/bin/*dll ${mingw_w64_x86_64_prefix}/bin
    cd ..
}

build_pamix() {
	do_git_checkout https://github.com/patroclos/PAmix.git PAmix
	cd PAmix
		apply_patch file://${top_dir}/PAmix-mutex.patch
		do_cmake "-DCMAKE_BUILD_TYPE=RELEASE -DWITH_UNICODE=ON" # -DWITH_UNICODE=1 -DFEAT_UNICODE=1"
		do_make
		do_make_install
	cd ..
}

build_pavucontrol() {
	do_git_checkout https://gitlab.freedesktop.org/pulseaudio/pavucontrol.git pavucontrol
	cd pavucontrol
		generic_configure_make_install
	cd ..
}


build_iculehb() {
  do_git_checkout https://github.com/behdad/icu-le-hb.git icu-le-hb
  cd icu-le-hb
    apply_patch file://${top_dir}/icu-le-hb-shared.patch
    generic_configure_make_install

  cd ..
}

build_rtaudio() {
  do_git_checkout https://github.com/thestk/rtaudio.git rtaudio
  cd rtaudio
    do_cmake "-DCMAKE_VERBOSE_MAKEFILE=ON -DRTAUDIO_API_WASAPI=ON -DRTAUDIO_API_ALSA=OFF -DRTAUDIO_API_PULSE=OFF -DRTAUDIO_API_JACK=OFF -DRTAUDIO_API_CORE=OFF"
    do_make "V=1"
    do_make_install "V=1"
#    apply_patch file://${top_dir}/rtaudio-configure.patch
#    generic_configure_make_install "--with-wasapi --disable-static --enable-shared "
  cd ..
}

build_libidn() {
  do_git_checkout https://gitlab.com/libidn/libidn2.git libidn2
  cd libidn2
    generic_configure_make_install

  cd ..
}

build_cmark() {
  do_git_checkout https://github.com/commonmark/cmark.git cmark
  cd cmark
    mkdir -pv build
    cd build
    do_cmake .. "-DCMARK_STATIC=OFF -DCMARK_SHARED=ON"
      do_make
      do_make_install
    cd ..
  cd ..
}

build_xz() {
  do_git_checkout https://git.tukaani.org/xz.git xz
  cd xz
    generic_configure_make_install

  cd ..
}

build_libjson() {
do_git_checkout https://github.com/json-c/json-c.git json-c
    cd json-c
        generic_configure_make_install "--enable-threading"
        ln -vs ${mingw_w64_x86_64_prefix}/lib/pkgconfig/json-c.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig/json.pc
    cd ..
}

build_libMXF() {
  #download_and_unpack_file http://sourceforge.net/projects/ingex/files/1.0.0/libMXF/libMXF-src-1.0.0.tgz "libMXF-src-1.0.0"
  #cd libMXF-src-1.0.0
  #apply_patch https://raw.githubusercontent.com/rdp/ffmpeg-windows-build-helpers/master/patches/libMXF.diff
  #do_make "MINGW_CC_PREFIX=$cross_prefix"
  do_git_checkout git://git.code.sf.net/p/bmxlib/libmxf bmxlib-libmxf
#  download_and_unpack_file file://${top_dir}/bmxlib-libmxf-353c344ec81315e8936f54ed753bcff00dd783b4.zip bmxlib-libmxf-353c344ec81315e8936f54ed753bcff00dd783b4
  cd bmxlib-libmxf
#  cd bmxlib-libmxf-353c344ec81315e8936f54ed753bcff00dd783b4
#    cd tools/MXFDump
#    if [[ ! -e patch_done ]]; then
#      echo "applying patch to bmxlib-libmxf"
#      MXFPATCH="
#--- MXFDump.cpp 2014-09-24 08:46:22.840096500 +0100
#+++ MXFDump-patched.cpp 2014-09-24 09:28:00.964403200 +0100
#@@ -89,6 +89,9 @@
# #elif defined(__GNUC__) && defined(__sparc__) && defined(__sun__)
# #define MXF_COMPILER_GCC_SPARC_SUNOS
# #define MXF_OS_UNIX
#+#elif defined(__GNUC__) && defined(__x86_64__) && defined(_WIN32)
#+#define MXF_COMPILER_GCC_INTEL_WINDOWS
#+#define MXF_OS_WINDOWS
# #else
# #error \"Unknown compiler\"
# #endif"
#      echo "$MXFPATCH" | patch
#      touch patch_done
#    else
#      echo "patch for MXFDump.exe already applied"
#    fi
#    cd ../..
#  sed -i.bak 's/@PC_ADD_LIBS@/-lmsvcrt @PC_ADD_LIBS@/' libMXF.pc.in
#  cd mxf
#    # GCC doesn't do structured exception handling
##    # but this boilerplate code from Tom Bramer at progammingunlimited.net
#    # seems to compile. I've modified it slightly to reference 32 bit registers
#    # in a 64 bit compile.
#    # And because this involves C++ style programming, we must
#    # rename the file accordingly.
#    mv mxf_win32_mmap.c mxf_win32_mmap.cpp
#    apply_patch_p1 file://${top_dir}/libmxf-win32-mmap-gcc.patch
#    apply_patch_p1 file://${top_dir}/libmxf-win32-mmap-Makefile.am.patch
#    sed -i.bak 's/) -version-info/) -no-undefined -version-info/' Makefile.am
#  cd ..
  sed -i.bak 's/) -version-info/) -no-undefined -version-info/' mxf/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/reader/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/writeavidmxf/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/avidmxfinfo/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/archive/write/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/archive/test/Makefile.am
  sed -i.bak 's/= -version-info/= -no-undefined -version-info/' examples/archive/info/Makefile.am
  if [[ ! -f ./configure ]]; then
    ./autogen.sh
  fi
  generic_configure_make_install "V=1" # CXXFLAGS=-static

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
  cd ImageMagick-6.9.1-10

  cd ..
}

build_jasper() {
  download_and_unpack_file https://www.ece.uvic.ca/~frodo/jasper/software/jasper-1.900.29.tar.gz jasper-1.900.29
  cd jasper-1.900.29
    apply_patch file://${top_dir}/jasper-dll.patch
    rm -v configure
    # We must regenerate configure for libjasper so that a DLL is made
    generic_configure_make_install

  cd ..
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
  mkdir -pv build

  local new_hg_version=`hg --debug id -i`
  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
    echo "got upstream hg changes, forcing rebuild...GraphicsMagick"
    apply_patch file://${top_dir}/graphicmagick-mingw64.patch
    cd build
      rm already*
#      generic_download_and_install ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/snapshots/GraphicsMagick-1.4.020150919.tar.xz GraphicsMagick-1.4.020150919 "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-magick-compat --disable-shared --enable-static --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix}/include CPPFLAGS=-I${mingw_w64_x86_64_prefix}"
#      do_configure "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-magick-compat --disable-shared --enable-static --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix}/include CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
      # Add extra libraries to those required to link with libGraphicsMagick
      sed -i.bak 's/Libs: -L\${libdir} -lGraphicsMagick/Libs: -L${libdir} -lGraphicsMagick -lfreetype -lbz2 -lz -llcms2 -lpthread -lpng16 -ltiff -lgdi32 -lgdiplus -ljpeg -lwebp -ljasper/' ../magick/GraphicsMagick.pc.in
      # References to a libcorelib are not needed. The library doesn't exist on my platform
      sed -i.bak 's/-lcorelib//' ../magick/GraphicsMagick.pc.in
      export ac_cv_path_xml2_config=${mingw_w64_x86_64_prefix}/bin/xml2-config
      do_configure "--with-magick-plus-plus --disable-static --enable-magick-compat --enable-shared --with-modules --host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-broken-coders --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix} CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
      do_make_install || exit 1
      unset ac_cv_path_xml2_config
      # cp -v config/* ${mingw_w64_x86_64_prefix}/share/GraphicsMagick-1.4/config/
      # do_make_clean
    cd ..
  else
    echo "still at hg $new_hg_version GraphicsMagick"
  fi
  cd ..
}

build_graphicsmagicksnapshot() {
  download_and_unpack_file ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/snapshots/GraphicsMagick-1.4.020190523.tar.xz GraphicsMagick-1.4.020190523
  cd GraphicsMagick-1.4.020190523
    apply_patch file://${top_dir}/graphicmagick-mingw64.patch
    mkdir -pv build
    cd build
      sed -i.bak 's/Libs: -L\${libdir} -lGraphicsMagick/Libs: -L${libdir} -lGraphicsMagick -lfreetype -lbz2 -lz -llcms2 -lpthread -lpng16 -ltiff -lgdi32 -lgdiplus -ljpe
  g -lwebp -ljasper/' ../magick/GraphicsMagick.pc.in
      # References to a libcorelib are not needed. The library doesn't exist on my platformi
      export ac_cv_path_xml2_config=${mingw_w64_x86_64_prefix}/bin/xml2-config
      do_configure "--with-magick-plus-plus --disable-static --enable-magick-compat --enable-shared --with-modules --host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-broken-coders --without-x
 LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix} CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
      do_make_install || exit 1
      unset ac_cv_path_xml2_config
      cp -v config/* ${mingw_w64_x86_64_prefix}/share/GraphicsMagick-1.4/config/
    cd ..
  cd ..
}

#build_graphicsmagick() {
#  local old_hg_version
#  if [[ -d GM ]]; then
#    cd GM
#      echo "doing hg pull -u GM"
#      old_hg_version=`hg --debug id -i`
#     hg pull -u || exit 1
#     hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
#  else
#    hg clone http://hg.code.sf.net/p/graphicsmagick/code GM || exit 1
#    cd GM
#      old_hg_version=none-yet
#  fi
#  download_and_unpack_file ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/snapshots/GraphicsMagick-1.4.020180218.tar.xz GraphicsMagick-1.4.020180218
#  cd GraphicsMagick-1.4.020180218
#    mkdir build
#
#  local new_hg_version=`hg --debug id -i`
#  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
#    echo "got upstream hg changes, forcing rebuild...GraphicsMagick"
#    apply_patch file://${top_dir}/graphicmagick-mingw64.patch
#    cd build
#      rm already*
      # Add extra libraries to those required to link with libGraphicsMagick
#      sed -i.bak 's/Libs: -L\${libdir} -lGraphicsMagick/Libs: -L${libdir} -lGraphicsMagick -lfreetype -lbz2 -lz -llcms2 -lpthread -lpng16 -ltiff -lgdi32 -lgdiplus -ljpeg -lwebp -ljasper/' ../magick/GraphicsMagick.pc.in
      # References to a libcorelib are not needed. The library doesn't exist on my platform
#      sed -i.bak 's/-lcorelib//' ../magick/GraphicsMagick.pc.in
#      do_configure "--with-magick-plus-plus --enable-magick-compat --without-modules --with-fpx --disable-static --enable-shared --host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-broken-coders --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix} CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
#      do_make_install || exit 1
#      cp -v config/* ${mingw_w64_x86_64_prefix}/share/GraphicsMagick-1.4/config/

#    cd ..
#  else
#    echo "still at hg $new_hg_version GraphicsMagick"
#  fi
#  cd ..
#  download_and_unpack_file https://sourceforge.net/code-snapshots/hg/g/gr/graphicsmagick/code/graphicsmagick-code-baae93bf73b8701b03340b6ec0b9aaa4ba961d89.zip graphicsmagick-code-baae93bf73b8701b03340b6ec0b9aaa4ba961d89
#  cd graphicsmagick-code-baae93bf73b8701b03340b6ec0b9aaa4ba961d89
#    mkdir -v build
#    cd build
#      # Add extra libraries to those required to link with libGraphicsMagick
#      sed -i.bak 's/Libs: -L\${libdir} -lGraphicsMagick/Libs: -L${libdir} -lGraphicsMagick -lfreetype -lbz2 -lz -llcms2 -lpthread -lpng16 -ltiff -lgdi32 -lgdiplus -ljpeg -lwebp -ljasper/' ../magick/GraphicsMagick.pc.in
      # References to a libcorelib are not needed. The library doesn't exist on my platform
#      sed -i.bak 's/-lcorelib//' ../magick/GraphicsMagick.pc.in
#      do_configure "--with-magick-plus-plus --enable-magick-compat --without-modules --with-fpx --disable-static --enable-shared --host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-broken-coders --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix} CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
#      do_make_install || exit 1
#      cp -v config/* ${mingw_w64_x86_64_prefix}/share/GraphicsMagick-1.4/config/
#    cd ..
#  cd ..
#}

build_yamlcc() {
	do_git_checkout https://github.com/jbeder/yaml-cpp.git yaml-cpp release-0.5.3
	cd yaml-cpp
		apply_patch file://${top_dir}/yamlcpp.patch
		do_cmake "-DYAML_CPP_BUILD_TESTS=OFF -DCMAKE_VERBOSE_MAKEFILE=ON"
		do_make "V=1"
		do_make_install "V=1"
		cp -v ${mingw_w64_x86_64_prefix}/bin/pkgconfig/yaml-cpp.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig/yaml-cpp.pc
	cd ..
}

build_tinyxml() {
download_and_unpack_file https://downloads.sourceforge.net/project/tinyxml/tinyxml/2.6.2/tinyxml_2_6_2.tar.gz tinyxml
	cd tinyxml
		cp ${top_dir}/tinyxml-CMakeLists.txt CMakeLists.txt
		cp ${top_dir}/tinyxml.pc.in tinyxml.pc.in
		do_cmake "-DCMAKE_VERBOSE_MAKEFILE=ON"
		do_make "V=1"
		do_make_install "V=1"
	cd ..
}

build_ocio() {
	download_and_unpack_file https://github.com/AcademySoftwareFoundation/OpenColorIO/archive/v1.1.1.tar.gz OpenColorIO-1.1.1
	cd OpenColorIO-1.1.1
		apply_patch file://${top_dir}/OpenColorIO.patch
		do_cmake "-DCMAKE_VERBOSE_MAKEFILE=ON -DOCIO_BUILD_PYGLUE=OFF -DOCIO_BUILD_TESTS=OFF -DOCIO_BUILD_STATIC=OFF -DUSE_EXTERNAL_YAML=ON -DUSE_EXTERNAL_TINYXML=ON"
		do_make "V=1"
		do_make_install "V=1"
	cd ..
}

build_otio() {
	do_git_checkout https://github.com/PixarAnimationStudios/OpenTimelineIO.git OpenTimelineIO
	cd OpenTimelineIO
		apply_patch file://${top_dir}/opentime.patch
		do_cmake "-DCMAKE_VERBOSE_MAKEFILE=ON"
		do_make "V=1"
		do_make_install "V=1"
	cd ..
}

build_GLM() {
	download_and_unpack_file https://github.com/g-truc/glm/archive/0.9.9.7.tar.gz glm-0.9.9.7
	cd glm-0.9.9.7
	cp -rv glm ${mingw_w64_x86_64_prefix}/include/	
	cd ..
}

build_GLFW() {
	download_and_unpack_file https://github.com/glfw/glfw/archive/3.3.2.tar.gz glfw-3.3.2
	cd glfw-3.3.2
		do_cmake "-DCMAKE_VERBOSE_MAKEFILE=ON"
		do_make "V=1"
		do_make_install "V=1"
	cd ..
}
build_picoJSON() {
	do_git_checkout https://github.com/kazuho/picojson.git picojson
	cd picojson
		mkdir -pv ${mingw_w64_x86_64_prefix}/include/picojson/
		cp -v picojson.h ${mingw_w64_x86_64_prefix}/include/picojson/picojson.h
	cd ..
}

build_get_iplayer() {
  # This isn't really "building" - just downloading the latest Perl script from Github
  # Don't forget - you MUST have a working Perl interpreter to run this program.
  # Note that this is the development version, that closely tracks the developers' work on changes
  # to the BBC website. It is NOT supported, but may have fixes before the release version.
  curl -o ${mingw_w64_x86_64_prefix}/bin/get_iplayer.pl https://raw.githubusercontent.com/get-iplayer/get_iplayer/contribute/get_iplayer
}

build_libdecklink() {
#  if [[ ! -f $mingw_w64_x86_64_prefix/include/DeckLinkAPI_i.c ]]; then
  cp -v ${top_dir}/DeckLinkAPI.h $mingw_w64_x86_64_prefix/include/DeckLinkAPI.h  || exit 1
  cp -v ${top_dir}/DeckLinkAPI_i.c $mingw_w64_x86_64_prefix/include/DeckLinkAPI_i.c  || exit 1
  cp -v ${top_dir}/DeckLinkAPIVersion.h $mingw_w64_x86_64_prefix/include/DeckLinkAPIVersion.h  || exit 1
#  fi
}

build_libklvanc() {
    do_git_checkout https://github.com/stoth68000/libklvanc.git libklvanc
    cd libklvanc
        rm autogen.sh
        apply_patch file://${top_dir}/libklvanc.patch
        generic_configure_make_install "LIBS=-lpthread --disable-silent-rules"
    cd ..
}

build_ffmpegnv() {
  do_git_checkout https://github.com/FFmpeg/nv-codec-headers.git nv-codec-headers
  cd nv-codec-headers
    sed -i.bak "s!PREFIX = /usr/local!PREFIX = ${mingw_w64_x86_64_prefix}!" Makefile
    do_make
    do_make_install
  cd ..
}


build_ffmpeg() {
  local type=$1
  local shared=$2
  local git_url="https://git.ffmpeg.org/ffmpeg.git" # "https://github.com/mpv-player/ffmpeg-mpv.git"
  local output_dir="ffmpeg_git"

  # FFmpeg + libav compatible options
  # add libpsapi to enable libdlfcn for Windows to work, thereby enabling frei0r plugins
  local extra_configure_opts="--enable-libsoxr --enable-fontconfig --enable-libass --enable-libbluray --enable-iconv --enable-libtwolame --enable-libzvbi --enable-libcaca --enable-libmodplug --extra-libs=-lstdc++ --extra-libs=-lpsapi --enable-opengl --extra-libs=-lz --extra-libs=-lpng --enable-libvidstab --enable-decklink --extra-libs=-loleaut32 --enable-libcdio --enable-libzimg --enable-chromaprint --enable-libsnappy --enable-libx265 --enable-lv2 --enable-libklvanc --logfile=/dev/tty"

# The -Wno-narrowing is because libutvideo triggers a compiler strictness with the narrowing of a constant inside a curly-bracketed declaration
  extra_configure_opts="$extra_configure_opts --extra-cflags=$CFLAGS --extra-version=COMPILED_BY_JohnWarburton --extra-cxxflags=-Wno-narrowing" # extra-cflags is not needed, but adds it to the console output which I lke

  # can't mix and match --enable-static --enable-shared unfortunately, or the final executable seems to just use shared if the're both present
  if [[ $shared == "shared" ]]; then
    output_dir=${output_dir}_shared
    do_git_checkout $git_url ${output_dir} #f52dd8a55a98418b6301cce4a56d2b73d08b7eea # 2f7ca0b94e49c2bfce8bda3f883766101ebd7a9b
    final_install_dir=`pwd`/${output_dir}.installed
    extra_configure_opts="--enable-shared --disable-static $extra_configure_opts"
    # avoid installing this to system?
    extra_configure_opts="$extra_configure_opts --prefix=$final_install_dir"
  else
    do_git_checkout $git_url $output_dir #f52dd8a55a98418b6301cce4a56d2b73d08b7eea # 2f7ca0b94e49c2bfce8bda3f883766101ebd7a9b
    extra_configure_opts="--enable-shared --disable-static --disable-debug --disable-stripping $extra_configure_opts" # --pkg-config-flags=--static
  fi
  cd $output_dir

  if [ "$bits_target" = "32" ]; then
   local arch=x86
  else
   local arch=x86_64
  fi

#  apply_patch file://${top_dir}/ffmpeg-amix.patch
# --extra-cflags=$CFLAGS, though redundant, just so that FFmpeg lists what it used in its "info" output
  #apply_patch file://${top_dir}/ffmpeg-dash-demux.patch
#  apply_patch_p1 file://${top_dir}/ffmpeg-mcompand.patch
  #apply_patch file://${top_dir}/ffmpeg-framesync2.patch
#  apply_patch file://${top_dir}/lavfi-vfstack-reverse.patch
#  apply_patch_p1 file://${top_dir}/ffmpeg-decklink-teletext-1-reverse.patch
#  apply_patch_p1 file://${top_dir}/ffmpeg-decklink-teletext-2-reverse.patch
  apply_patch file://${top_dir}/ffmpeg-bs2b.patch

  config_options="--arch=$arch --target-os=mingw32 --cross-prefix=$cross_prefix --pkg-config=pkg-config --enable-libjack --disable-doc --enable-libxml2 --enable-opencl --enable-gpl --enable-libtesseract --enable-libx264 --enable-avisynth --enable-libxvid --enable-libmp3lame --enable-libmysofa --enable-version3 --enable-zlib --enable-librtmp --enable-libvorbis --enable-libtheora --enable-libspeex --enable-libopenjpeg --enable-gnutls --enable-libgsm --enable-libfreetype --enable-libopus --disable-w32threads --enable-libcodec2 --enable-frei0r --enable-filter=frei0r --enable-bzlib --enable-libxavs --enable-libxavs2 --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-libvpx --enable-libilbc --enable-libwavpack --enable-libwebp --enable-libgme --enable-libbs2b --enable-libmfx --enable-librubberband --enable-dxva2 --enable-d3d11va --enable-nvenc --enable-libzmq --enable-nonfree --enable-libfdk-aac --enable-libflite --enable-decoder=aac --enable-libaom --enable-runtime-cpudetect --enable-libpulse --enable-cuda-nvcc --prefix=$mingw_w64_x86_64_prefix $extra_configure_opts" # $CFLAGS # other possibilities: --enable-w32threads --enable-libflite
  # sed -i 's/openjpeg-1.5/openjpeg-2.1/' configure # change library path for updated libopenjpeg
  export PKG_CONFIG="pkg-config" # --static
  export LDFLAGS="" # "-static"
#  apply_patch file://${top_dir}/ffmpeg-x264-depth-1.patch
#  apply_patch file://${top_dir}/ffmpeg-x264-depth-2.patch
  do_configure "$config_options"
  unset PKG_CONFIG
  unset LDFLAGS
  rm -f */*.a */*.dll *.exe # just in case some dependency library has changed, force it to re-link even if the ffmpeg source hasn't changed...
  rm already_ran_make*
  echo "doing ffmpeg make $(pwd)"
  do_make "V=0"
  do_make_install "V=0" # install ffmpeg to get libavcodec libraries to be used as dependencies for other things, like vlc [XXX make this a parameter?] or install shared to a local dir

  # build ismindex.exe, too, just for fun
  make tools/ismindex.exe

  sed -i.bak 's/-lavutil -lm.*/-lavutil -lm -lpthread/' "$PKG_CONFIG_PATH/libavutil.pc" # XXX patch ffmpeg itself
  sed -i.bak 's/-lswresample -lm.*/-lswresample -lm -lsoxr/' "$PKG_CONFIG_PATH/libswresample.pc" # XXX patch ffmpeg
  echo "FFmpeg binaries are built."
  CFLAGS=${orig_cflags}
  # do_make_clean
  cd ..
  # Put back the x265.exe executable we hid earlier. I do not know why FFmpeg becomes linked against it otherwise!
  # NO don't put it back. Windows still finds x265.exe even though the compiler didn't see that binary at link time.
  # NO idea what is going on.
  # mv -v $mingw_w64_x86_64_prefix/bin/MOVEDx265.MOVEDexe $mingw_w64_x86_64_prefix/bin/x265.exe
}

build_dvdstyler() {
  generic_download_and_install http://sourceforge.net/projects/dvdstyler/files/dvdstyler-devel/3.0b1/DVDStyler-3.0b1.tar.bz2 DVDStyler-3.0b1 "DVDAUTHOR_PATH=${mingw_w64_x86_64_prefix}/bin/dvdauthor.exe FFMPEG_PATH=${mingw_w64_x86_64_prefix}/bin/ffmpeg.exe --with-wx-config=${mingw_w64_x86_64_prefix}/bin/wx-config"
  cd DVDStyker-3.0b1

  cd ..
}

build_NDI_headers() {
    cd ${mingw_w64_x86_64_prefix}
      tar xvvf ${top_dir}/NDI-NewTek.tar.xz
    cd -
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
  build_meson_cross
  # build_win32_pthreads # vpx etc. depend on this--provided by the compiler build script now, so shouldn't have to build our own
  build_libtool
  build_pkg-config # because MPV likes to see a mingw version of pkg-config
  build_iconv # Because Cygwin's iconv is buggy, and loops on certain character set conversions
  build_libffi # for glib among others
  build_locked_sstream # for dcp-o-matic dcpomatic
  #build_doxygen
  build_libdlfcn # ffmpeg's frei0r implentation needs this <sigh>
  build_zlib # rtmp depends on it [as well as ffmpeg's optional but handy --enable-zlib]
  build_bzlib2 # in case someone wants it [ffmpeg uses it]
  build_xz
  build_lzo
  build_lz4
  build_taglib # Used by loudness-scanner among others
  build_snappy # For certain types of very fast video compression
  build_libpng # for openjpeg, needs zlib
  build_gmp # for libnettle
  build_pcre # for glib and others
  build_libnettle # needs gmp
  build_openssl
  build_libexpat
  build_unbound
  build_libunistring # Needed for gnutls
  build_libtasn1
  build_p11kit # Needed for gnutls
#  build_libffi # Needed for guile
#  build_libatomic_ops # Needed for bdw-gc
#  build_bdw-gc # Needed for guile
#  build_guile # Needed for autogen
#  build_autogen # Required for gnutls to see libopts
#  build_iconv # mplayer I think needs it for freetype [just it though], vlc also wants it.  looks like ffmpeg can use it too...not sure what for :)
  build_libidn2 # Required for gnutls
  build_gnutls # needs libnettle, can use iconv it appears
#  build_openssl
#  build_gomp   # Not yet.
  build_gavl # Frei0r has this as an optional dependency
#  build_libutvideo
  build_opencl
  build_OpenCL
  build_libflite # too big for the ffmpeg distro...
  build_sdl # needed for ffplay to be created
  build_sdl2
  build_uchardet
  build_libopus
  build_libopencore
  build_libogg
  #build_fmt
#  build_icu
  build_boost # needed for mkv tools
  build_libspeexdsp # Speex now split into two libraries
  build_libspeex # needs libogg for exe's
  build_libvorbis # needs libogg
  build_libtheora # needs libvorbis, libogg
  build_orc
  build_libschroedinger # needs orc
  build_libebur128
  build_regex # needed by ncurses and cddb among others
  build_termcap
  build_ncurses
  build_readline
  build_gettext
  #build_iconvgettext # Because of circular dependency libiconv->gettext
  build_libpopt
  build_libzip
  build_freetype # uses bz2/zlib seemingly
  build_libexpat
  build_libxml2
  build_libxslt
  build_libgpg-error # Needed by libgcrypt
  build_libgcrypt # Needed by libxmlsec
  build_libxmlsec
  build_libaacs
  build_libbdplus
  build_lcms2 # Openjpeg2 and others require this
#  build_libudfread # Needed by libbluray but built as submodule
  build_libbluray # needs libxml2, freetype [FFmpeg, VLC use this, at least]
  build_libopenjpeg
  build_libopenjpeg2
  build_libjpeg_turbo # mplayer can use this, VLC qt might need it? [replaces libjpeg],
                      # Place after other jpeg libraries so headers are over-written
  build_libdvdcss
  build_libdvdread # vlc, mplayer use it. needs dvdcss
  build_libdvdnav # vlc, mplayer use this
  build_libtiff
  build_zimg # Image format conversion library for FFmpeg and others
  build_libexif # For manipulating EXIF data
  build_NDI_headers
  build_libxvid
  build_libxavs
  build_libxavs2
  build_libsoxr
  build_libx262
  build_libx264 # Libx264 must be installed OVER libx262. x262 is like x264 but with
                # MPEG-2 encoding on top of it. We don't want this, because the version
		# of libx264 it tracks is way behind the current version. Instead, we must
		# be happy with the command-line x262 program, and pipe data to it.
  build_libx265
#  build_turingcodec # Needs work on thread interface. Can't mingw compile yet
  build_asdcplib
  build_lame
  build_vidstab
  build_libcaca
  build_libmodplug # ffmepg and vlc can use this
  build_zvbi
  # build_libcddb # Circular dependency here!
  build_libcdio
  build_libcddb
  build_libcdio_libcddb # Now build again with cddb support
  build_libcdio-paranoia
  build_sqlite
  build_libfilezilla
  build_libvpx
#  build_vo_aacenc
  build_libdecklink
  build_liburiparser
  build_libilbc
#  build_icu # Needed for Qt5 / QtWebKit
  build_libmms
  build_libklvanc
  build_flac
  if [[ -d gsm-1.0-pl13 ]]; then # this is a TERRIBLE kludge because sox mustn't see libgsm
    cd gsm-1.0-pl13
    make uninstall
    cd ..
    rm $mingw_w64_x86_64_prefix/lib/libgsm.a # because make uninstall in gsm-1.0-pl13
                                             # doesn't actually remove the installed library
  fi
  build_libfftw
  build_libchromaprint
  build_libsndfile
  # build_libnvenc
  build_live555
  build_googletest
  build_glib
  build_mmcommon
  build_libsigc++
  build_glibmm
  build_libxml++
  build_libcxml
  build_dbus
  build_zstd
  build_libarchive
  build_jasper # JPEG2000 codec for GraphicsMagick among others
  build_atk
  build_atkmm
  build_gdk_pixbuf
  build_mimedb
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
  build_libuuid
  build_libass # needs freetype, needs fribidi, needs fontconfig
  build_intel_quicksync_mfx
  build_glew
#  build_libopenjpeg
#  build_libopenjpeg2
  build_libwebp
  build_filewalk
  build_curl_early
  build_poppler
  build_SWFTools
  build_ASIOSDK
  build_eigen
  build_portaudio_without_jack
  build_jack
  build_portaudio_with_jack
#  build_openblas # Not until we make a Fortran compiler
  build_opencv
  build_frei0r
  build_libjson
  build_liba52
  build_leptonica
  build_serd
  build_sord
  build_lv2
  build_sratom
  build_lilv
  build_pixman
  build_libssh
  #build_pthread_stubs
  #build_drm
  build_sdl2_image
#  build_mmcommon
  build_spirvtools
  build_glslang
  build_shaderc
  build_vulkan
  #build_angle
  build_cairo
  build_cairomm
#  build_pango
#  build_pangomm
  build_icu
  build_harfbuzz
  build_pango
  build_pangomm
  build_iculehb
  build_icu_with_iculehb
  build_libcroco
  # build_lash
  build_tesseract
  if [[ "$non_free" = "y" ]]; then
    build_fdk_aac
    # build_faac # not included for now, too poor quality :)
    # build_libaacplus # if you use it, conflicts with other AAC encoders <sigh>, so disabled :)
  fi
  build_librtmp # needs gnutls [or openssl...] and curl depends on this too
#  build_smake # This is going to be useful one day. But not now.
  build_lua
  build_ladspa # Not a real build: just copying the API header file into place
  build_librubberband # for mpv
  build_zmq
#  build_libtasn1
  build_cppzmq
  build_libdsm
  build_dvbpsi
  build_libebml
  build_libmatroska
  build_1394camera
  build_libdc1394
  build_libmpeg2
  build_vim
  build_ilmbase
#  build_hdf
  build_netcdf
  build_cunit
  build_libmysofa
  build_libiberty
  build_libspatialaudio
  build_libidn
#  build_librsvg
#  build_gobject_introspection
  build_libepoxy
  build_rtaudio
  build_gtk2
  build_gtk
  build_gtkmm
  build_graphicsmagick
  build_eigen
  build_libdv
  build_aom
  build_asdcplib-cth
  build_cmark
  build_opusfile
  build_libopusenc
  build_medialibrary
  build_yamlcc
  build_tinyxml
  build_ocio
  build_otio
  build_GLM
  build_GLFW
  build_picoJSON
  build_libaec
  build_gctpc
}

build_apps() {
  # now the things that use the dependencies...
#  build_less
#  build_coreutils
  build_file
  #build_pngcrush
  build_exif
  build_gcal
  build_opustools
  build_curl # Needed for mediainfo to read Internet streams or file, also can get RTMP streamss
  build_gdb # Really useful, and the correct version for Windows executables
  build_atomicparsley
  if [[ $build_libmxf = "y" ]]; then
    build_libMXF
    build_libMXFpp
    build_bmx
  #  build_makemkv
  fi
#  if [[ $build_mp4box = "y" ]]; then
#    build_mp4box
#  fi
#  build_ocaml
  build_exiv2
  build_wgrib2
#  build_cdrecord # NOTE: just now, cdrecord doesn't work on 64-bit mingw. It scans the emulated SCSI bus but no more.
#  build_cdrkit # No. Still not compiled in MinGW
  build_lsdvd
  build_fdkaac-commandline
#  build_cdrecord
  build_qt
  #build_kf5_config
  #build_kf5_coreaddons
  #build_kf5_itemmodels
  #build_kf5_itemviews
  #build_kf5_auth
  #build_kf5_codecs
  #build_kf5_guiaddons
  #build_kf5_i18n
  #build_kf5_widgetsaddons
  #build_kf5_configwidgets
  #build_kf5_archive
  #build_kf5_iconthemes
  #build_kf5_completion
  #build_kf5_windowsystem
  #build_kf5_crash
  #build_kf5_dbusaddons
  #build_kf5_service
  #build_kf5_sonnet
  #build_kf5_textwidgets
  #build_kf5_attica
  #build_kf5_globalaccel
  #build_kf5_xmlgui
  #build_kf5_solid
  #build_kf5_threadweaver
  #build_digikam
  build_youtube-dl
  build_mjpegtools
  build_unittest
# build_qt5
  build_mkvtoolnix
#  build_openssh
#  build_rsync
  build_dvdbackup
  build_codec2
  build_ffmpegnv
  if [[ $build_ffmpeg_shared = "y" ]]; then
    build_ffmpeg ffmpeg shared
  fi
  build_pulseaudio
#  build_libcanberra
  if [[ $build_ffmpeg_static = "y" ]]; then
    build_ffmpeg ffmpeg
  fi
  if [[ $build_libav = "y" ]]; then
    build_ffmpeg libav
  fi
  build_pamix
  build_ffms2
  build_mp4box
  build_libdash
  build_aubio
  build_libopenshotaudio
#  build_libopenshot
  #build_pulseaudio
  build_mpv
  build_libplacebo
  build_opendcp # Difficult at the moment. Development tree doesn't compile under its own procedures
  # build_opencv # We place it here because opencv has an interface to FFmpeg
  #if [[ $build_vlc = "y" ]]; then
  #  build_vlc # NB requires ffmpeg static as well, at least once...so put this last :)
  #fi
  build_cuetools
  build_xerces
#  build_graphicsmagick
  build_libdcp # Now needs graphicsmagick
  build_libsub
#  build_pavucontrol
  build_gstreamer
  build_wx
  build_filezilla
  build_wxsvg
  build_mediainfo
  build_dvdauthor
#  build_audacity
#  build_traverso
  build_mlt # Framework, but relies on FFmpeg, Qt, and many other libraries we've built.
  build_movit
  build_DJVnew # Requires FFmpeg libraries
  build_qjackctl
#  build_jackmix
  build_flacon
  build_get_iplayer
  build_dcpomatic
  build_loudness-scanner
  build_synaesthesia
  # Because loudness scanner installs its own out-of-date libebur128, we must re-install our own.
#  build_dvdstyler
  #build_vlc
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
echo "Processors found: ${cpu_count}"
original_cpu_count=$cpu_count # save it away for some that revert it temporarily
#gcc_cpu_count=1 # allow them to specify more than 1, but default to the one that's most compatible...
gcc_cpu_count=$cpu_count
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
      --gcc-cpu-count=1 [number of cpu cores set it higher than 1 if you have multiple cores and > 1GB RAM, this speeds up cross compiler build. FFmpeg build uses number of cores regardless.]
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
# Install a decent set of colours for vim. Makes development easier.
#do_git_checkout https://github.com/amix/vimrc.git ~/.vim_runtime
#chmod +x ~/.vim_runtime/install_awesome_vimrc.sh
#~/.vim_runtime/install_awesome_vimrc.sh
install_cross_compiler
# the header Windows.h needs to appear
cd ${cur_dir}/x86_64-w64-mingw32/x86_64-w64-mingw32/include
  ln -s windows.h Windows.h
  ln -s winsock2.h WinSock2.h
  ln -s cfgmgr32.h Cfgmgr32.h
  ln -s devpkey.h Devpkey.h
  ln -s shlobj.h ShlObj.h
  ln -s uiviewsettingsinterop.h UIViewSettingsInterop.h
cd -
cd ${cur_dir}/x86_64-w64-mingw32/x86_64-w64-mingw32/lib
  ln -s libversion.a libVersion.a
cd -
#cd ${cur_dir}/x86_64-w64-mingw32/lib32
#  ln -s libversion.a libVersion.a
#cd -
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

if [ -d "x86_64-w64-mingw32" ]; then # they installed a 64-bit compiler
  echo "Building 64-bit ffmpeg..."
  host_target='x86_64-w64-mingw32'
  mingw_w64_x86_64_prefix="$cur_dir/x86_64-w64-mingw32/$host_target"
  export PATH="$cur_dir/x86_64-w64-mingw32/bin:$original_path"
  export PKG_CONFIG_PATH="$cur_dir/x86_64-w64-mingw32/x86_64-w64-mingw32/lib/pkgconfig"
  export mingw_compiler_path="$cur_dir/mingw"
  mkdir -p x86_64
  bits_target=64
  cross_prefix="$cur_dir/x86_64-w64-mingw32/bin/x86_64-w64-mingw32-"
  # Make a link to system pkg-config program because some compiles look for it as a cross-compiler version of pkg-config
  ln -s /usr/bin/pkg-config ${cross_prefix}pkg-config.exe
  cd x86_64
  build_dependencies
  build_apps
  cd ..
fi

# A few shared libraries have been installed into ./lib.
# They need to be in ./bin for our installation.
# TODO: CHECK THIS LIST WHEN ADDING NEW PACKAGES

echo "Copying runtime libraries that have gone to the wrong build directory."
#wrong_libs=('iculx59.dll' 'icudt59.dll' 'icutu59.dll' 'icuin59.dll' 'icuio59.dll' 'icutest59.dll' 'icuuc59.dll' 'libatomic-1.dll' 'libboost_chrono.dll' 'libboost_date_time.dll' 'libboost_filesystem.dll' 'libboost_prg_exec_monitor.dll' 'libboost_regex.dll' 'libboost_system.dll' 'libboost_locale.dll' 'libboost_thread_win32.dll' 'libboost_unit_test_framework.dll' 'libboost_timer.dll' 'libdcadec.dll' 'libgcc_s_seh-1.dll' 'libopendcp-lib.dll' 'libpthread.dll' 'libquadmath-0.dll' 'libssp-0.dll' 'libstdc++-6.dll' 'pthreadGC2.dll' 'libebur128.dll')
#for move in ${wrong_libs[@]}; do
#  cp -Lv "${mingw_w64_x86_64_prefix}/lib/${move}" "${mingw_w64_x86_64_prefix}/bin/${move}" || exit 1
  cp -Lv ${mingw_w64_x86_64_prefix}/lib/*dll ${mingw_w64_x86_64_prefix}/bin/
#done
# Also copy WxWidgets
cp -v ${mingw_w64_x86_64_prefix}/lib/wx*dll ${mingw_w64_x86_64_prefix}/bin/ || "WxWidgets already copied."
echo "Runtime libraries in wrong directory now copied."

# Many DLLs are put in the compiler's directory. I don't know why, but the
# compilers seem to find them ok.
# These libraries, too, need linking into the object binary directory

echo "Symbolic linking runtime libraries in compiler directory to executables directory."
# Remove QT libraries -- they are in the compile-time bin directory to get around
# a hack in the compilation of loudness_scanner
echo "First removing Qt lib symlinks from loudness_scanner hack..."
rm -fv ${mingw_w64_x86_64_prefix}/../bin/Qt*dll
rm -fv ${mingw_w64_x86_64_prefix}/../plugins
# while we're at it, a stray link to plugins sometimes appears.
# This must be removed
echo "Removing stray link to plugins directory..."
rm -fv ${mingw_w64_x86_64_prefix}/plugins/plugins

# A number of Windows DLLs have now been duplicated from /lib. They don't
# belong there. For safety's sake, let's remove only the top directory.
# Leave all the other files behind. They're sometimes needed for run-time
# linking or other work.
echo "Removing DLL files accidentally left in /lib"
rm -fv ${mingw_w64_x86_64_prefix}/lib/*dll

# The new mingw compilation script has fixed this next hack
# for library in ${mingw_w64_x86_64_prefix}/../bin/*dll; do
#   linkname=$(basename $library)
#   echo "Linking ${library} to ${mingw_w64_x86_64_prefix}/bin/${linkname}"
#   ln -fvs ${library} ${mingw_w64_x86_64_prefix}/bin/${linkname} || exit 1
# done
# echo "Runtime libraries in compiler directory now symbolically linked."

# QT expects its platform plugins to be in a subdirectory of the binary directory
# named "platforms"

# Remove the symbolic link first, or we get an infinite loop
rm -v "${mingw_w64_x86_64_prefix}/bin/platforms"
ln -fvs "${mingw_w64_x86_64_prefix}/plugins/platforms" "${mingw_w64_x86_64_prefix}/bin/platforms"

echo "Stripping all binaries..."

# TODO: Check plugin directories for new things that future builds of QT5 might install

${cross_prefix}strip  -p -s -v `find ${mingw_w64_x86_64_prefix} -iname "*.exe"`
${cross_prefix}strip  -p -s -v `find ${mingw_w64_x86_64_prefix} -iname "*.dll"`
#${cross_prefix}strip  -p -s -v `find ${mingw_w64_x86_64_prefix}/../lib -name "*dll"`
#${cross_prefix}strip  -p -s -v `find ${mingw_w64_x86_64_prefix}/plugins -name "*dll"`
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/bearer/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/generic/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/iconengines/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/imageformats/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/platforms/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/printsupport/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/sqldrivers/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/lib/frei0r-1/*.dll
#${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.dll
echo "Binaries are stripped. Debugging versions of FFmpeg programs ending _g"
echo "are in build directory."
#echo "searching for some local exes..."
#for file in $(find_all_build_exes); do
#  echo "built $file"
#done
echo "done!"

