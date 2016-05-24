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
  local check_packages=('sshpass' 'curl' 'pkg-config' 'make' 'gettext' 'git' 'svn' 'cmake' 'gcc' 'autoconf' 'libtool' 'automake' 'yasm' 'cvs' 'flex' 'bison' 'makeinfo' 'g++' 'ed' 'hg' 'patch' 'pax' 'bzr' 'gperf' 'ruby' 'doxygen' 'asciidoc' 'xsltproc' 'autogen' 'rake' 'autopoint' 'pxz' 'wget' 'zip' 'xmlto')
  for package in "${check_packages[@]}"; do
    type -P "$package" >/dev/null || missing_packages=("$package" "${missing_packages[@]}")
  done

  if [[ -n "${missing_packages[@]}" ]]; then
    clear
    echo "Could not find the following execs (svn is actually package subversion, autopoint is gettext or gettext-devel, makeinfo is actually package texinfo if you're missing them): ${missing_packages[@]}"
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
  sed -i.bak "s/gcc_release_ver='4.9.2'/gcc_release_ver='6.1.0'/" mingw-w64-build-3.6.6
  sed -i.bak "s/mpfr_release_ver='3.1.2'/mpfr_release_ver='3.1.4'/" mingw-w64-build-3.6.6
  sed -i.bak "s/binutils_release_ver='2.25'/binutils_release_ver='2.26'/" mingw-w64-build-3.6.6
  sed -i.bak "s/isl_release_ver='0.12.2'/isl_release_ver='0.16.1'/" mingw-w64-build-3.6.6
  sed -i.bak "s/gmp_release_ver='6.0.0a'/gmp_release_ver='6.1.0'/" mingw-w64-build-3.6.6
  sed -i.bak "s/gmp-6\.0\.0/gmp-6.1.0/" mingw-w64-build-3.6.6
  sed -i.bak "s!//gcc\.gnu\.org/svn/gcc/trunk!//gcc.gnu.org/svn/gcc/branches/gcc-5-branch!" mingw-w64-build-3.6.6
  apply_patch file://${top_dir}/mingw-w64-build-isl_fix.patch 
#  sed -i.bak "s|ln -s '../include' './include'|mkdir include|" mingw-w64-build-3.6.6
#  sed -i.bak "s|ln -s '../lib' './lib'|mkdir lib|" mingw-w64-build-3.6.6
#  sed -i.bak "s/--enable-threads=win32/--enable-threads=posix/" mingw-w64-build-3.6.6
# Gendef compilation throws a char-as-array-index error when invoked with "--target=" : "--host" avoids this.
#  sed -i.bak 's#gendef/configure" --build="$system_type" --prefix="$mingw_w64_prefix" --target#gendef/configure" --build="$system_type" --prefix="$mingw_w64_prefix" --host#' mingw-w64-build-3.6.6
  ./mingw-w64-build-3.6.6 --default-configure --mingw-w64-ver=git --gcc-ver=svn --pthreads-w32-ver=2-9-1 --cpu-count=$gcc_cpu_count --build-type=$build_choice --enable-gendef --enable-widl --binutils-ver=2.26 --verbose || exit 1 # --disable-shared allows c++ to be distributed at all...which seemed necessary for some random dependency...
  export CFLAGS=$original_cflags # reset it
# We need to move the plain cross-compiling versions of bintools out of the way
# because exactly the same binaries exist with the host triplet prefix
#  rm ${mingw_w64_x86_64_prefix}/bin/objdump ${mingw_w64_x86_64_prefix}/bin/ar ${mingw_w64_x86_64_prefix}/bin/ranlib ${mingw_w64_x86_64_prefix}/bin/objcopy ${mingw_w64_x86_64_prefix}/bin/dlltool ${mingw_w64_x86_64_prefix}/bin/nm ${mingw_w64_x86_64_prefix}/bin/strip ${mingw_w64_x86_64_prefix}/bin/as ${mingw_w64_x86_64_prefix}/bin/ld.bfd ${mingw_w64_x86_64_prefix}/bin/ld 
  # A couple of multimedia-related files need cases changing because of QT5 includes
  cd mingw-w64-x86_64/include
    ln -s evr9.h Evr9.h
    ln -s mferror.h Mferror.h
  cd ../..
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
  local configure_noclean="$3"
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

do_drake() {
  local extra_make_options="$1 -j $cpu_count"
  local cur_dir2=$(pwd)
  local touch_name=$(get_small_touchfile_name already_ran_drake "$extra_make_options")

  if [ ! -f $touch_name ]; then
    echo
    echo "draking $cur_dir2 as $ PATH=$PATH drake $extra_make_options"
    echo
    nice drake $extra_make_options || exit 1
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
    nice ${mingw_w64_x86_64_prefix}/../bin/smake $extra_make_options || exit 1
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
    nice ${mingw_w64_x86_64_prefix}/../bin/smake install $extra_make_options || exit 1
    touch $touch_name || exit 1
  fi
}


do_cmake() {
  extra_args="$1" 
  local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")

  if [ ! -f $touch_name ]; then
    local cur_dir2=$(pwd)
    echo doing cmake in $cur_dir2 with PATH=$PATH  with extra_args=$extra_args like this:
    echo cmake . -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
    cmake . -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix $extra_args || exit 1
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

do_drake_and_drake_install() {
  local extra_make_options="$1"
  do_drake "$extra_make_options"
  local touch_name=$(get_small_touchfile_name already_ran_drake_install "$extra_make_options")
  if [ ! -f $touch_name ]; then
    echo "drake installing $(pwd) as $ PATH=$PATH drake install $extra_make_options"
    nice drake install $extra_make_options || exit 1
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

build_libx265() {
#  if [[ $prefer_stable = "n" ]]; then
#    local old_hg_version
#    if [[ -d x265 ]]; then
#      cd x265
#      if [[ $git_get_latest = "y" ]]; then
#        echo "doing hg pull -u x265"
#        old_hg_version=`hg --debug id -i`
#        hg pull -u || exit 1
#        hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
#      else
#        echo "not doing hg pull x265"
#        old_hg_version=`hg --debug id -i`
#      fi
#    else
#      hg clone https://bitbucket.org/multicoreware/x265 || exit 1
#      cd x265
#      old_hg_version=none-yet
#    fi
#    cd source
#
#    # hg checkout 9b0c9b # no longer needed, but once was...
#
#    local new_hg_version=`hg --debug id -i`  
#    if [[ "$old_hg_version" != "$new_hg_version" ]]; then
#      echo "got upstream hg changes, forcing rebuild...x265"
#      rm already*
#    else
#      echo "still at hg $new_hg_version x265"
#    fi
#  else
#    local old_hg_version
#    if [[ -d x265 ]]; then
#      cd x265
#      if [[ $git_get_latest = "y" ]]; then
#        echo "doing hg pull -u x265"
#        old_hg_version=`hg --debug id -i`
#        hg pull -u || exit 1
#        hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
#      else
#        echo "not doing hg pull x265"
#        old_hg_version=`hg --debug id -i`
#      fi
#    else
#      hg clone https://bitbucket.org/multicoreware/x265 -r stable || exit 1
#      cd x265
#      old_hg_version=none-yet
#    fi
#    cd source
#
#    # hg checkout 9b0c9b # no longer needed, but once was...
#
#    local new_hg_version=`hg --debug id -i`  
#    if [[ "$old_hg_version" != "$new_hg_version" ]]; then
#      echo "got upstream hg changes, forcing rebuild...x265"
#      rm already*
#    else
#      echo "still at hg $new_hg_version x265"
#    fi
#  fi
  do_git_checkout https://github.com/videolan/x265.git x265
  cd x265/source
    local cmake_params="-DENABLE_SHARED=ON -DENABLE_STATIC=OFF"
    if [[ $high_bitdepth == "y" ]]; then
      cmake_params="$cmake_params -DHIGH_BIT_DEPTH=ON -DMAIN12=ON" # Enable 10 bits (main10) and 12 bits (???) per pixels profiles.
      if grep "DHIGH_BIT_DEPTH=0" CMakeFiles/cli.dir/flags.make; then
        rm already_ran_cmake_* #Last build was not high bitdepth. Forcing rebuild.
      fi
    else
      if grep "DHIGH_BIT_DEPTH=1" CMakeFiles/cli.dir/flags.make; then
        rm already_ran_cmake_* #Last build was high bitdepth. Forcing rebuild.
      fi
    fi
#  apply_patch_p1 file://${top_dir}/x265-missing-bool.patch  
  # Fixed by x265 developers now
    do_cmake "$cmake_params" 
  # x265 seems to fail on parallel builds
    export cpu_count=1
    do_make_install 
    export cpu_count=$original_cpu_count
  cd ../..
}

#x264_profile_guided=y

build_libx264() {
  do_git_checkout git://git.videolan.org/x264.git x264
  cd x264
  local configure_flags="--host=$host_target --disable-static --enable-shared --cross-prefix=$cross_prefix --prefix=$mingw_w64_x86_64_prefix --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac" # --enable-win32thread --enable-debug shouldn't hurt us since ffmpeg strips it anyway I think
  
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
  cd rtmpdump_git
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

build_qt() {
  export QT_VERSION="5.6.0"
  export QT_SOURCE="qt-source"
  export QT_BUILD="qt-build"
  if [ ! -f qt.built ]; then
    download_and_unpack_file http://download.qt.io/official_releases/qt/5.6/${QT_VERSION}/single/qt-everywhere-opensource-src-${QT_VERSION}.tar.gz "qt-everywhere-opensource-src-${QT_VERSION}"
    mkdir -p "${QT_BUILD}"
    ln -vs "qt-everywhere-opensource-src-${QT_VERSION}" "${QT_SOURCE}"
    cd "${QT_BUILD}"
      do_configure "-xplatform win32-g++ -prefix ${mingw_w64_x86_64_prefix} -hostprefix ${mingw_w64_x86_64_prefix}/../ -opensource -skip qtactiveqt -qt-freetype -fontconfig -glib -confirm-license -accessibility -nomake examples -nomake tests -debug -debug-and-release -strip -openssl -opengl desktop -device-option CROSS_COMPILE=$cross_prefix -device-option PKG_CONFIG=${mingw_w64_x86_64_prefix}/../bin/x86_64-w64-mingw32-pkg-config -no-use-gold-linker -I ${mingw_w64_x86_64_prefix}/include/glib-2.0 -I ${mingw_w64_x86_64_prefix}/lib/glib-2.0/include -l glib-2.0 -v" "../${QT_SOURCE}/configure" # "noclean"
      do_make || exit 1
      do_make_install || exit 1
    cd ..
      touch "qt.built"
  else
    echo "Skipping QT build... already completed."
  fi
  unset QT_VERSION
  unset QT_SOURCE
  unset QT_BUILD
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

build_mlt() {
  do_git_checkout http://github.com/mltframework/mlt.git mlt
  cd mlt
    apply_patch file://${top_dir}/mlt-mingw-sandbox.patch
    export CXX=x86_64-w64-mingw32-g++
    export CROSS=x86_64-w64-mingw32-
    export CC=x86_64-w64-mingw32-gcc
    # The --avformat-ldextra option must contain all the libraries that 
    # libavformat.dll is linked against. These we obtain by reading libavformat.pc
    # from the pkgconfig directory
    avformat_ldextra=`pkg-config --static --libs-only-l libavformat`
    generic_configure_make_install "--enable-gpl --enable-gpl3 --target-os=mingw --target-arch=x86_64 --libdir=${mingw_w64_x86_64_prefix}/bin/lib --datadir=${mingw_w64_x86_64_prefix}/bin/share --avformat-swscale --avformat-ldextra=${avformat_ldextrahttps// /\\ \\}"
    unset CXX
    unset CROSS
    unset CC
    # The Makefiles don't use Autotools, and put the binaries in the wrong places with
    # no executable extension for 'melt.exe'
    # Also, the paths are not correct for Windows execution. So we must move things
    mv -v ${mingw_w64_x86_64_prefix}/melt ${mingw_w64_x86_64_prefix}/bin/melt.exe
    mv -v ${mingw_w64_x86_64_prefix}/libmlt* ${mingw_w64_x86_64_prefix}/bin/
  cd ..
}

build_DJV() {
  do_git_checkout git://git.code.sf.net/p/djv/git DJV
  cd DJV
    # Patch to get around Mingw-w64's difficult-to-follow handling of strerror_s()
    apply_patch file://${top_dir}/djv-djvFileInfo.cpp.patch
    # Patch to use g++ equivalents of possibly missing environment manipulation functions
    apply_patch file://${top_dir}/djv-djvSystem.cpp.patch
    # Non-portable patch to restore missing #define-s of these math constants
    # that have lately disappeared in Mingw-w64
    sed -i.bak 's/FLT_EPSILON/1.19209290e-07F/' lib/djvCore/djvMath.cpp
    sed -i.bak 's/DBL_EPSILON/2.2204460492503131e-16/' lib/djvCore/djvMath.cpp
    # FFmpeg's headers have changed. DJV hasn't caught up yet
    sed -i.bak 's/PIX_FMT_RGBA/AV_PIX_FMT_RGBA/' plugins/djvFFmpegPlugin/djvFFmpegLoad.cpp
    # Replace a MSVC function that isn't yet in Mingw-w64
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_VER)/' lib/djvCore/djvStringUtil.h
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_CER)/' plugins/djvJpegPlugin/djvJpegLoad.cpp
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_CER)/' plugins/djvJpegPlugin/djvJpegSave.cpp
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_CER)/' plugins/djvPngPlugin/djvPngLoad.cpp
    sed -i.bak 's/defined(DJV_WINDOWS)/defined(DJV_WINDOWS) \&\& defined(_MSC_CER)/' plugins/djvPngPlugin/djvPngSave.cpp
    # Don't make dvjFileBrowserTest or, indeed, any tests
    sed -i.bak 's/enable_testing()/#enable_testing()/' CMakeLists.txt
    sed -i.bak 's/add_subdirectory(djvFileBrowserTest)/#add_subdirectory(djvFileBrowserTest)/' tests/CMakeLists.txt
    # Change Windows' backslashes to forward slashes to allow MinGW compilation
    # Remember that . and \ need escaping with \, which makes this hard to read
    sed -i.bak 's!\.\.\\\\.\.\\\\etc\\\\Windows\\\\djv_view.ico!../../etc/Windows/djv_view.ico!' bin/djv_view/win.rc
    do_cmake "-DENABLE_STATIC_RUNTIME=0 -DCMAKE_PREFIX_PATH=${mingw_w64_x86_64_prefix} -DCMAKE_C_FLAGS=-D__STDC_CONSTANT_MACROS -DCMAKE_CXX_FLAGS=-D__STDC_CONSTANT_MACROS"
    do_make
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

build_opencv() {
  do_git_checkout https://github.com/Itseez/opencv.git "opencv"
  cd opencv
  # This is only used for a couple of frei0r filters. Surely we can switch off more options than this?
  # WEBP is switched off because it triggers a Cmake bug that removes #define-s of EPSILON and variants
  # This needs more work
  # NOT YET: CMAKE_LIBRARY_PATH needs to find the installed Qt5 libraries
  # Because MinGW has no native Posix threads, we use the Boost emulation and must link the Boost libraries
  
    apply_patch file://${top_dir}/opencv-mutex-boost.patch
    apply_patch file://${top_dir}/opencv-boost-thread.patch
    apply_patch file://${top_dir}/opencv-wrong-slash.patch
    do_cmake "-DWITH_IPP=OFF -DWITH_DSHOW=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_opencv_apps=ON -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DBUILD_WITH_DEBUG_INFO=OFF -DWITH_WEBP=OFF -DBUILD_EXAMPLES=ON -DINSTALL_C_EXAMPLES=ON -DWITH_OPENGL=ON -DINSTALL_PYTHON_EXAMPLES=ON -DCMAKE_CXX_FLAGS=-DMINGW_HAS_SECURE_API=1 -DCMAKE_C_FLAGS=-DMINGW_HAS_SECURE_API=1 -DOPENCV_LINKER_LIBS=boost_thread_win32;boost_system"
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
  do_git_checkout https://github.com/tmeiczin/opendcp.git opendcp 0.31.0b
  cd opendcp
    export CMAKE_LIBRARY_PATH="${mingw_w64_x86_64_prefix}/lib"
    export CMAKE_INCLUDE_PATH="${mingw_w64_x86_64_prefix}/include:${mingw_w64_x86_64_prefix}/include/openjpeg-2.1"
    export CMAKE_CXX_FLAGS="-fopenmp"
    export CMAKE_C_FLAGS="-fopenmp"
    export cpu_count=1
    apply_patch file://${top_dir}/opendcp-win32.cmake.patch
    apply_patch file://${top_dir}/opendcp-libopendcp-CMakeLists.txt.patch
    apply_patch file://${top_dir}/opendcp-CMakeLists.txt.patch
#    apply_patch file://${top_dir}/opendcp-CMakeLists.txt-static.patch
#    apply_patch file://${top_dir}/opendcp-libasdcp-KM_prng.cpp.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.openjpeg-2.1.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.libs.patch
    #apply_patch file://${top_dir}/opendcp-toolchains-win32.cmake.windres.patch
#    apply_patch file://${top_dir}/opendcp-packages-CMakeLists.txt-static.patch
    do_cmake "-DINSTALL_LIB=ON -DLIB_INSTALL_PATH=${mingw_w64_x86_64_prefix}/lib -DENABLE_XMLSEC=ON -DENABLE_GUI=OFF -DBUILD_SHARED=ON -DBUILD_STATIC=OFF -DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_OPENMP=OFF"
    do_make_install
    unset CMAKE_C_FLAGS
    unset CMAKE_CXX_FLAGS
    unset CMAKE_LIBRARY_PATH
    unset CMAKE_INCLUDE_PATH
    export cpu_count=$original_cpu_count
  cd ..
}

build_dcpomatic() {
  do_git_checkout git://git.carlh.net/git/dcpomatic.git dcpomatic
  cd dcpomatic
    apply_patch file://${top_dir}/dcpomatic-wscript.patch
    apply_patch file://${top_dir}/dcpomatic-src-wx-wscript.patch
    apply_patch file://${top_dir}/dcpomatic-test-wscript.patch
     # M_PI is missing in mingw-w64
    sed -i.bak 's/M_PI/3.14159265358979323846/g' src/lib/audio_filter.cc
     # The RC file looks for wxWidgets 3.0 rc, but it's 3.1 in our build
    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic.rc
    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic_batch.rc
    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic_server.rc
    sed -i.bak 's!wx-3\.0/wx/msw/wx\.rc!wx-3.1/wx/msw/wx.rc!' platform/windows/dcpomatic_kdm.rc
    export cCFLAGS="-fpermissive"
    do_configure "configure WINRC=x86_64-w64-mingw32-windres CXX=x86_64-w64-mingw32-g++ -v -pp --prefix=${mingw_w64_x86_64_prefix} --target-windows --check-cxx-compiler=gxx --disable-tests --enable-debug" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
    export CFLAGS="${original_cflags}"
  cd ..
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

build_libpng() {
  download_and_unpack_file http://download.sourceforge.net/libpng/libpng-1.6.18.tar.xz libpng-1.6.18
  cd libpng-1.6.18
    # DBL_EPSILON 21 Feb 2015 starts to come back "undefined". I have NO IDEA why.
    grep -lr DBL_EPSILON contrib | xargs sed -i "s| DBL_EPSILON| 2.2204460492503131E-16|g"
    generic_configure_make_install "--enable-shared"
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
  do_git_checkout https://github.com/mm2/Little-CMS.git lcms2
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
    do_git_checkout https://chromium.googlesource.com/webm/libvpx "libvpx_git"
    cd libvpx_git
    apply_patch file://${top_dir}/libvpx-vp8-common-threading-h-mingw.patch
  fi
  export CROSS="$cross_prefix"
  if [[ "$bits_target" = "32" ]]; then
    do_configure "--target=x86-win32-gcc --prefix=$mingw_w64_x86_64_prefix --enable-shared --disable-static"
  else
#    do_configure "--extra-cflags=-DPTW32_STATIC_LIB --target=x86_64-win64-gcc --prefix=$mingw_w64_x86_64_prefix --enable-static --disable-shared --disable-unit-tests --disable-encode-perf-tests --disable-decode-perf-tests --enable-vp10 --enable-vp10-encoder --enable-vp10-decoder --enable-vp9-highbitdepth --enable-vp9-temporal-denoising --enable-postproc --enable-vp9-postproc"
    # libvpx only supports static building on MinGW platform
    do_configure "--target=x86_64-win64-gcc --prefix=$mingw_w64_x86_64_prefix --enable-static --disable-unit-tests --disable-encode-perf-tests --disable-decode-perf-tests --enable-vp10 --enable-vp10-encoder --enable-vp10-decoder --enable-vp9-temporal-denoising --enable-postproc --enable-vp9-postproc --enable-multithread"
  fi
  do_make_install
  # Now create the shared library
  ${cross_prefix}gcc -shared -o libvpx-1.dll -Wl,--out-implib,libvpx.dll.a -Wl,--whole-archive,libvpx.a,--no-whole-archive -lpthread || exit 1
  cp -v libvpx-1.dll $mingw_w64_x86_64_prefix/bin/libvpx-1.dll
  cp -v libvpx.dll.a $mingw_w64_x86_64_prefix/lib/libvpx.dll.a
  unset CROSS
  cd ..
}

build_libutvideo() {
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
    generic_configure "--host=$host_target --enable-shared --disable-static --cross-prefix=$cross_prefix --prefix=$mingw_w64_x86_64_prefix --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac"
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
  download_and_unpack_file http://ftp.stack.nl/pub/users/dimitri/doxygen-1.8.11.src.tar.gz doxygen-1.8.11
  cd doxygen-1.8.11
    sed -i.bak 's/WIN32/MSVC/' CMakeLists.txt
    sed -i.bak 's/if (win_static/if (win_static AND MSVC/' CMakeLists.txt
    apply_patch file://${top_dir}/doxygen-fix-casts.patch
    do_cmake
    do_make_install
  cd ..
}

build_libflite() {
#  download_and_unpack_file http://www.speech.cs.cmu.edu/flite/packed/flite-1.4/flite-1.4-release.tar.bz2 flite-1.4-release
#  cd flite-1.4-release
   download_and_unpack_file http://www.festvox.org/flite/packed/flite-2.0/flite-2.0.0-release.tar.bz2 flite-2.0.0-release
   cd flite-2.0.0-release
     apply_patch flite_64.diff
     sed -i.bak "s|i386-mingw32-|$cross_prefix|" configure*
     generic_configure
     do_make
     make install # it fails in error...
     cp ./build/x86_64-mingw32/lib/*.a $mingw_w64_x86_64_prefix/lib || exit 1
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
  download_and_unpack_file http://downloads.xiph.org/releases/opus/opus-1.1.2.tar.gz opus-1.1.2
  cd opus-1.1.2
    apply_patch file://${top_dir}/opus11.patch # allow it to work with shared builds
    generic_configure_make_install "--enable-custom-modes --enable-asm" 
  cd ..
}

build_libdvdread() {
  build_libdvdcss
  download_and_unpack_file http://download.videolan.org/pub/videolan/libdvdread/5.0.3/libdvdread-5.0.3.tar.bz2 libdvdread-5.0.3
  cd libdvdread-5.0.3
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
  download_and_unpack_file http://download.videolan.org/pub/videolan/libdvdnav/5.0.3/libdvdnav-5.0.3.tar.bz2 libdvdnav-5.0.3
  cd libdvdnav-5.0.3
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
  download_and_unpack_file ftp://sourceware.org/pub/gdb/releases/gdb-7.11.tar.xz gdb-7.11
  cd gdb-7.11
#    cd readline
#    generic_configure_make_install
#   cd ..
  generic_configure_make_install "--with-system-readline"
  cd ..
  unset LIBS
}

build_readline() {
  do_git_checkout git://git.savannah.gnu.org/readline.git readline
  cd readline
    rm configure
    apply_patch file://${top_dir}/readline-mingw32.patch
    generic_configure_make_install "--without-curses"
  cd ..
}

build_portaudio() {
  download_and_unpack_file http://www.portaudio.com/archives/pa_stable_v19_20140130.tgz portaudio
  cd portaudio
    rm configure
    apply_patch file://${top_dir}/portaudio-1-fixes-crlf.patch
    generic_configure_make_install "--with-host_os=mingw --with-winapi=wasapi ac_cv_path_AR=x86_64-w64-mingw32-ar"
  cd ..
}

build_jack() {
  download_and_unpack_file https://dl.dropboxusercontent.com/u/28869550/jack-1.9.10.tar.bz2 jack-1.9.10
  cd jack-1.9.10
    if [ ! -f "jack.built" ] ; then
      apply_patch file://${top_dir}/jack-1-fixes.patch
      export AR=x86_64-w64-mingw32-ar 
      export CC=x86_64-w64-mingw32-gcc 
      export CXX=x86_64-w64-mingw32-g++ 
#      export cpu_count=1
      do_configure "configure --prefix=${mingw_w64_x86_64_prefix} --dist-target=mingw" "./waf"
      ./waf build || exit 1
      ./waf install || exit 1
      # The Jack development libraries are, strangely, placed into a subdirectory of lib
      echo "Placing the Jack development libraries in the expected place..."
      cp -v ${mingw_w64_x86_64_prefix}/lib/jack/*dll.a ${mingw_w64_x86_64_prefix}/lib
#      export cpu_count=$original_cpu_count
    else
      echo "Jack already built."
    fi
    touch "jack.built"
  cd ..
}

build_leptonica() {
  generic_download_and_install http://www.leptonica.com/source/leptonica-1.73.tar.gz leptonica-1.73 "LIBS=-lopenjpeg --disable-silent-rules --without-libopenjpeg"
}

build_libpopt() {
  download_and_unpack_file http://rpm5.org/files/popt/popt-1.16.tar.gz popt-1.16
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
    install libtermcap-0.dll "${mingw_w64_x86_64_prefix}/../bin"
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
 download_and_unpack_file ftp://invisible-island.net/ncurses/current/ncurses-6.0-20160507.tgz ncurses-6.0-20160507
 # generic_configure "--build=x86_64-pc-linux --host=x86_64-w64-mingw32 --with-libtool --disable-termcap --enable-widec --enable-term-driver --enable-sp-funcs --without-ada --with-debug=no --with-shared=yes --with-normal=no --enable-database --with-progs --enable-interop --with-pkg-config-libdir=${mingw_w64_x86_64_prefix}/lib/pkgconfig --enable-pc-files"
  cd ncurses-6.0-20160507
    generic_configure "--build=x86_64-pc-linux --host=x86_64-w64-mingw32 --disable-termcap --enable-widec --enable-term-driver --enable-sp-funcs --without-ada --without-cxx-binding --with-debug=no --with-shared=yes --with-normal=no --enable-database --with-probs --enable-interop --with-pkg-config-libdir=${mingw_w64_x86_64_prefix}/lib/pkgconfig --enable-pc-files --disable-static --enable-shared" 
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
  generic_download_and_install http://greenwoodsoftware.com/less/less-471.tar.gz less-471
}

build_dvdbackup() {
  bzr branch lp:dvdbackup
  cd dvdbackup
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
  generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.3.tar.gz/download opencore-amr-0.1.3
  generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/vo-amrwbenc/vo-amrwbenc-0.1.2.tar.gz/download vo-amrwbenc-0.1.2
}

# NB this is kind of worse than just using the one that comes from the zeranoe script, since this one requires the -DPTHREAD_STATIC everywhere...
build_win32_pthreads() {
  download_and_unpack_file ftp://sourceware.org/pub/pthreads-win32/pthreads-w32-2-9-1-release.tar.gz   pthreads-w32-2-9-1-release
  cd pthreads-w32-2-9-1-release
#    do_make "clean GC-static CROSS=$cross_prefix" # NB no make install
     do_make "clean GC-inlined CROSS=$cross_prefix"
    cp libpthreadGC2.a $mingw_w64_x86_64_prefix/lib/libpthread.a || exit 1
    cp pthreadGC2.dll $mingw_w64_x86_64_prefix/bin/pthread.dll || exit 1
    cp pthread.def $mingw_w64_x86_64_prefix/lib/pthread.def || exit 1
#    cp libpthreadGC2.a $mingw_w64_x86_64_prefix/lib/libpthreads.a || exit 1
    cp pthread.h sched.h semaphore.h $mingw_w64_x86_64_prefix/include || exit 1
  cd ..
}

build_libdlfcn() {
  do_git_checkout git://github.com/dlfcn-win32/dlfcn-win32.git dlfcn-win32
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
  do_git_checkout https://github.com/libjpeg-turbo/libjpeg-turbo libjpeg-turbo
  cd libjpeg-turbo
    apply_patch file://${top_dir}/libjpeg-turbo-simd-yasm.patch
    do_cmake "-DENABLE_STATIC=FALSE -DENABLE_SHARED=TRUE"
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
  generic_download_and_install http://downloads.xiph.org/releases/ogg/libogg-1.3.2.tar.gz libogg-1.3.2
}

build_libvorbis() {
  generic_download_and_install http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.5.tar.gz libvorbis-1.3.5
}

build_libspeex() {
  generic_download_and_install http://downloads.xiph.org/releases/speex/speex-1.2rc2.tar.gz speex-1.2rc2 "LIBS=-lwinmm --enable-binaries"
}  

build_libspeexdsp() {
  generic_download_and_install http://downloads.xiph.org/releases/speex/speexdsp-1.2rc3.tar.gz speexdsp-1.2rc3
}

build_libtheora() {
  original_cpu_count=$cpu_count
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
      # .def files of theora use CRLF line terminators, which makes the most recent
      # GNU binutils trigger a linker error
      # ...ldd: .libs/libtheoradec-1.dll.def:3: syntax error
      sed -i -e 's#\r##g' win32/xmingw32/libtheoradec-all.def
      sed -i -e 's#\r##g' win32/xmingw32/libtheoraenc-all.def
      generic_configure_make_install
    cd ..
  #generic_download_and_install http://downloads.xiph.org/releases/theora/libtheora-1.2.0alpha1.tar.gz libtheora-1.2.0alpha1
  cpu_count=$original_cpu_count
}

build_libfribidi() {
  # generic_download_and_install http://fribidi.org/download/fribidi-0.19.5.tar.bz2 fribidi-0.19.5 # got report of still failing?
  download_and_unpack_file http://fribidi.org/download/fribidi-0.19.7.tar.bz2 fribidi-0.19.7
  cd fribidi-0.19.7
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
  generic_download_and_install https://github.com/libass/libass/releases/download/0.13.2/libass-0.13.2.tar.gz libass-0.13.2
  # fribidi, fontconfig, freetype throw them all in there for good measure, trying to help mplayer once though it didn't help [FFmpeg needed a change for fribidi here though I believe]
  sed -i.bak 's/-lass -lm/-lass -lfribidi -lfontconfig -lfreetype -lexpat -lpng -lm/' "$PKG_CONFIG_PATH/libass.pc"
}

build_gmp() {
  download_and_unpack_file https://gmplib.org/download/gmp/gmp-6.1.0.tar.bz2 gmp-6.1.0
  cd gmp-6.1.0
#    export CC_FOR_BUILD=/usr/bin/gcc
#    export CPP_FOR_BUILD=usr/bin/cpp
    generic_configure "ABI=$bits_target --disable-static --enable-shared"
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
    # Remove libxml2 autogen because it sets variables that interfere with our cross-compile
    rm -v autogen.sh
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
  download_and_unpack_file http://www.aleksey.com/xmlsec/download/xmlsec1-1.2.22.tar.gz xmlsec1-1.2.22
  cd xmlsec1-1.2.22
    apply_patch file://${top_dir}/xsltsec-Makefile.in.patch
    export GCRYPT_LIBS=-lgcrypt
    export LIBS=-lgcrypt
    generic_configure_make_install "LIBS=-lgcrypt --disable-silent-rules GCRYPT_LIBS=-lgcrypt --with-gcrypt=${mingw_w64_x86_64_prefix} --disable-silent-rules"
    unset LIBS
    unset GCRYPT_LIBS
  cd ..
}

build_libaacs() {
  do_git_checkout https://git.videolan.org/git/libaacs.git libaacs
  cd libaacs
    generic_configure_make_install "--with-libgcrypt-prefix=${mingw_w64_x86_64_prefix} --with-gpg-error-prefix=${mingw_w64_x86_64_prefix}"
  cd ..
}

build_libbdplus() {
  do_git_checkout http://git.videolan.org/git/libbdplus.git libbdplus
  cd libbdplus
    generic_configure_make_install "--with-libgcrypt-prefix=${mingw_w64_x86_64_prefix} --with-gpg-error-prefix=${mingw_w64_x86_64_prefix}"
  cd ..
}

build_libbluray() {
  do_git_checkout git://git.videolan.org/libbluray.git libbluray
  cd libbluray
    git submodule init
    git submodule update
    cd contrib/libudfread
    # Overcome invalid detection of MSVC when using MinGW
    apply_patch file://${top_dir}/libudfread-udfread-c.patch
    cd ../..
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

build_icu() {
  # First, build native ICU, whose build tools are required by cross-compiled ICU
  # Luckily, we do this only once per build.
  if [ ! -f icu.built ]; then
    download_and_unpack_file http://download.icu-project.org/files/icu4c/57.1/icu4c-57_1-src.tgz icu
    holding_path=$PATH
    export PATH=$original_path
    mv icu icu_native
    cd icu_native/source
      do_configure
      do_make || exit 1
      # Don't install this
    cd ../..
    export PATH=$holding_path
    download_and_unpack_file http://download.icu-project.org/files/icu4c/57.1/icu4c-57_1-src.tgz icu
    cd icu/source
      generic_configure_make_install "--host=x86_64-w64-mingw32 --with-cross-build=${top_dir}/sandbox/x86_64/icu_native/source"
    cd ../..
    touch icu.built
  else
    echo "ICU is already built."
  fi
}
     

build_libunistring() {
  generic_download_and_install http://ftp.gnu.org/gnu/libunistring/libunistring-0.9.5.tar.xz libunistring-0.9.5
}

build_libffi() {
  generic_download_and_install ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz libffi-3.2.1
}

build_libatomic_ops() {
  generic_download_and_install http://www.ivmaisoft.com/_bin/atomic_ops/libatomic_ops-7.4.2.tar.gz libatomic_ops-7.4.2
}

build_bdw-gc() {
  generic_download_and_install http://www.hboehm.info/gc/gc_source/gc-7.4.2.tar.gz gc-7.4.2
}

build_guile() {
  generic_download_and_install ftp://ftp.gnu.org/pub/gnu/guile/guile-2.0.11.tar.xz guile-2.0.11
}

build_autogen() {
  generic_download_and_install http://ftp.gnu.org/gnu/autogen/rel5.18.7/autogen-5.18.7.tar.xz autogen-5.18.7
}

build_liba52() {
  export CFLAGS=-std=gnu89
  generic_download_and_install http://liba52.sourceforge.net/files/a52dec-snapshot.tar.gz a52dec-0.7.5-cvs
  export CFLAGS=${original_cflags}
}

build_gnutls() {
  download_and_unpack_file ftp://ftp.gnutls.org/gcrypt/gnutls/v3.3/gnutls-3.3.22.tar.xz gnutls-3.3.22
#  do_git_checkout https://gitlab.com/gnutls/gnutls.git gnutls
  cd gnutls-3.3.22
#    git submodule init
#    git submodule update
#    make autoreconf
    generic_configure "--disable-doc --enable-local-libopts" # --disable-cxx --disable-doc --without-p11-kit --disable-local-libopts --disable-libopts-install --with-included-libtasn1" # don't need the c++ version, in an effort to cut down on size... XXXX test difference...
    do_make_install
  cd ..
  sed -i.bak 's/-lgnutls *$/-lgnutls -lnettle -lhogweed -lgmp -lcrypt32 -lws2_32 -liconv/' "$PKG_CONFIG_PATH/gnutls.pc"
}

build_libnettle() {
  download_and_unpack_file https://ftp.gnu.org/gnu/nettle/nettle-3.2.tar.gz nettle-3.2
  cd nettle-3.2
    generic_configure "--disable-openssl" # in case we have both gnutls and openssl, just use gnutls [except that gnutls uses this so...huh? https://github.com/rdp/ffmpeg-windows-build-helpers/issues/25#issuecomment-28158515
    do_make_install
  cd ..
}

build_bzlib2() {
  download_and_unpack_file http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz bzip2-1.0.6
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
  download_and_unpack_file http://zlib.net/zlib-1.2.8.tar.gz zlib-1.2.8
  cd zlib-1.2.8
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
  download_and_unpack_file http://downloads.xvid.org/downloads/xvidcore-1.3.4.tar.gz xvidcore
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
#  if [[ -f "$mingw_w64_x86_64_prefix/lib/xvidcore.dll.a" ]]; then
#    rm $mingw_w64_x86_64_prefix/lib/xvidcore.dll.a || exit 1
#    mv $mingw_w64_x86_64_prefix/lib/xvidcore.a $mingw_w64_x86_64_prefix/lib/libxvidcore.a || exit 1
#  fi
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
  download_and_unpack_file ftp://ftp.openssl.org/source/openssl-1.0.2h.tar.gz openssl-1.0.2h
  cd openssl-1.0.2h
#  export cross="$cross_prefix"
  export CROSS_COMPILE="${cross_prefix}"
#  export CC="${cross}gcc"
#  export AR="${cross}ar"
#  export RANLIB="${cross}ranlib"
  #XXXX do we need no-asm here?
  if [ "$bits_target" = "32" ]; then
    do_configure "--prefix=$mingw_w64_x86_64_prefix shared no-asm mingw" ./Configure
  else
    do_configure "--prefix=$mingw_w64_x86_64_prefix shared no-asm mingw64" ./Configure
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

build_libssh() {
  do_git_checkout git://git.libssh.org/projects/libssh.git libssh 
  mkdir libssh_build
  cd libssh
    apply_patch file://${top_dir}/libssh-win32.patch
  cd ..
  cd libssh_build
    local touch_name=$(get_small_touchfile_name already_ran_cmake "$extra_args")
    if [ ! -f $touch_name ]; then
      echo doing cmake in ../libssh with PATH=$PATH  with extra_args=$extra_args like this:
      echo cmake ../libssh -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix -DWITH_GCRYPT=ON $extra_args || exit 1
      cmake ../libssh -DENABLE_STATIC_RUNTIME=0 -DENABLE_SHARED_RUNTIME=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RANLIB=${cross_prefix}ranlib -DCMAKE_C_COMPILER=${cross_prefix}gcc -DCMAKE_CXX_COMPILER=${cross_prefix}g++ -DCMAKE_RC_COMPILER=${cross_prefix}windres -DCMAKE_INSTALL_PREFIX=$mingw_w64_x86_64_prefix -DWITH_GCRYPT=ON $extra_args || exit 1
      do_make
      do_make_install
      touch $touch_name || exit 1
    fi
  cd ..
}

build_asdcplib-cth() {
   # Use brance cth because this is the version the writer works on, and has modified
  do_git_checkout https://github.com/cth103/asdcplib-cth.git asdcplib-cth cth
#  download_and_unpack_file http://carlh.net/downloads/asdcplib-cth/libasdcp-cth-0.1.1.tar.bz2 libasdcp-cth-0.1.1
  cd asdcplib-cth
#    export PKG_CONFIG_PATH=${mingw_w64_x86_64_prefix}/lib/pkgconfig
    export CXXFLAGS="-DKM_WIN32"
    export CFLAGS="-DKM_WIN32"
    export LIBS="-lws2_32 -lcrypto -lssl -lgdi32 -lboost_filesystem -lboost_system"
    # Don't look for boost libraries ending in -mt -- all our libraries are multithreaded anyway
    sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" wscript
#    sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" test/wscript
    export CXX=x86_64-w64-mingw32-g++
    do_configure "configure -v -pp --prefix=${mingw_w64_x86_64_prefix} --libdir=${mingw_w64_x86_64_prefix}/lib --target-windows --check-cxx-compiler=gxx" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
        # The installation puts the pkgconfig file and the import DLL in the wrong place
    cp -v build/libasdcp-cth.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    cp -v build/src/libasdcp-cth.dll.a ${mingw_w64_x86_64_prefix}/lib
    cp -v build/src/libkumu-cth.dll.a ${mingw_w64_x86_64_prefix}/lib
    unset CXX
    unset CXXFLAGS
    unset CFLAGS
    unset LIBS
  cd ..
}

build_libdcp() {
  # Branches are slightly askew. 1.0 is where development takes place
  do_git_checkout https://github.com/cth103/libdcp.git libdcp 1.0
#  download_and_unpack_file http://carlh.net/downloads/libdcp/libdcp-1.3.3.tar.bz2 libdcp-1.3.3
  cd libdcp
    # M_PI is required. This is a quick way of defining it
    sed -i.bak 's/M_PI/3.14159265358979323846/' examples/make_dcp.cc
    # Don't look for boost libraries ending in -mt -- all our libraries are multithreaded anyway
    sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" wscript
    sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" test/wscript
    export CXX=x86_64-w64-mingw32-g++
    do_configure "configure -v -pp --prefix=${mingw_w64_x86_64_prefix} --target-windows --check-cxx-compiler=gxx --disable-tests --enable-debug" "./waf" # --disable-gcov
    ./waf build || exit 1
    ./waf install || exit 1
    unset CXX
        # The installation puts the pkgconfig file and the DLL import file in the wrong place
    cp -v build/libdcp-1.0.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    cp -v build/src/libdcp-1.0.dll.a ${mingw_w64_x86_64_prefix}/lib
  cd ..
}

build_libsub() {
  do_git_checkout git://git.carlh.net/git/libsub.git libsub 1.0
  cd libsub
    # Our Boost libraries are multithreaded anyway
    sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" wscript
    # The version in the development tree doesn't have an updated version number
    sed -i.bak "s/1\.1\.0devel/1.1.13/" wscript
    sed -i.bak "s/boost_lib_suffix = '-mt'/boost_lib_suffix = ''/" test/wscript
    # iostream header is needed for std::cout objects
#    apply_patch file://${top_dir}/libsub_iostream.patch
    export CXX=x86_64-w64-mingw32-g++
    # I thought this was actually the default, but no?
    export CXXFLAGS="-std=c++11"
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

build_fdk_aac() {
  #generic_download_and_install http://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-0.1.0.tar.gz/download fdk-aac-0.1.0
  do_git_checkout https://github.com/mstorsjo/fdk-aac.git fdk-aac_git
  cd fdk-aac_git
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
    fi
    generic_configure_make_install "CXXFLAGS=-Wno-narrowing --enable-example=yes"
  cd ..
}


build_libexpat() {
  generic_download_and_install http://downloads.sourceforge.net/project/expat/expat/2.1.1/expat-2.1.1.tar.bz2 expat-2.1.1
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
  download_and_unpack_file https://code.soundsoftware.ac.uk/attachments/download/1520/vamp-plugin-sdk-2.6.tar.gz vamp-plugin-sdk-2.6
  cd vamp-plugin-sdk-2.6
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
    apply_patch file://${top_dir}/rubberband-mingw-shared.patch
    generic_configure_make_install
    mv -v ${mingw_w64_x86_64_prefix}/bin/rubberband ${mingw_w64_x86_64_prefix}/bin/rubberband.exe
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
  download_and_unpack_file ftp://ftp.gnupg.org/gcrypt/libgpg-error/libgpg-error-1.22.tar.bz2 libgpg-error-1.22
  cd libgpg-error-1.22
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
  download_and_unpack_file http://download.savannah.gnu.org/releases/freetype/freetype-2.6.3.tar.bz2 freetype-2.6.3
  cd freetype-2.6.3
  # Need to make a directory for the build library
  mkdir lib
  generic_configure "--with-png=yes --host=x86_64-w64-mingw32 --build=x86_64-redhat-linux"
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
    generic_configure_make_install "ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes"
  cd ..
}

build_sdl() {
  # apparently ffmpeg expects prefix-sdl-config not sdl-config that they give us, so rename...
  hold_cflags="${CFLAGS}"
  export CFLAGS=-DDECLSPEC=  # avoid SDL trac tickets 939 and 282, not worried about optimizing yet
  generic_download_and_install http://www.libsdl.org/release/SDL-1.2.15.tar.gz SDL-1.2.15 "--disable-stdio-redirect"
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
  local old_hg_version
  if [[ -d SDL ]]; then
    cd SDL
      echo "doing hg pull -u SDL"
      old_hg_version=`hg --debug id -i`
      hg pull -u || exit 1
      hg update || exit 1 # guess you need this too if no new changes are brought down [what the...]
  else
    hg clone http://hg.libsdl.org/SDL || exit 1
    cd SDL
      old_hg_version=none-yet
  fi
  mkdir build

  local new_hg_version=`hg --debug id -i`
  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
    echo "got upstream hg changes, forcing rebuild...SDL2"
#    apply_patch file://${top_dir}/SDL2-prevent-duplicate-d3d11-declarations.patch
    cd build
      rm already*
      do_configure "--host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-shared --enable-static --disable-render-d3d" "../configure" #3d3 disabled with --disable-render-d3d due to mingw-w64-4.0.0 and SDL disagreements
      do_make_install "V=1" 
   cd ..
 else
    echo "still at hg $new_hg_version SDL2"
  fi
  cd ..  

#  generic_download_and_install "https://www.libsdl.org/tmp/SDL-2.0.4-9799.tar.gz" "SDL-2.0.4-9799" "--disable-render-d3d"

}



build_vim() {
  do_git_checkout https://github.com/vim/vim.git vim
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
      mkdir ${mingw_w64_x86_64_prefix}/share/vim && cp -Rv ../runtime/* ${mingw_w64_x86_64_prefix}/share/vim
  cd ../..
}


build_mpv() {
  do_git_checkout https://github.com/mpv-player/mpv.git mpv
  cd mpv
    ./bootstrap.py
    export DEST_OS=win32
    export TARGET=x86_64-w64-mingw32
    do_configure "configure -pp --prefix=${mingw_w64_x86_64_prefix} --enable-win32-internal-pthreads --disable-x11 --disable-debug-build --enable-gpl3 --enable-sdl2 --enable-libmpv-shared --disable-libmpv-static --enable-gpl3 " "./waf"
    # In this cross-compile for Windows, we keep the Python script up-to-date and therefore
    # must call it directly by its full name, because mpv can only explore for executables
    # with the .exe suffix.
    sed -i.bak 's/path = "youtube-dl"/path = "youtube-dl.py"/' player/lua/ytdl_hook.lua
    sed -i.bak 's/mp.find_config_file("youtube-dl")/mp.find_config_file("youtube-dl.py")/' player/lua/ytdl_hook.lua
    sed -i.bak 's/  ytdl.path, "--no-warnings"/  "python.exe", ytdl.path, "--no-warnings"/' player/lua/ytdl_hook.lua
    ./waf build || exit 1
    ./waf install || exit 1
    unset DEST_OS
    unset TARGET
  cd ..
}

build_faac() {
  generic_download_and_install http://downloads.sourceforge.net/faac/faac-1.28.tar.gz faac-1.28 "--with-mp4v2=no"
}

build_atomicparsley() {
  git clone https://github.com/evolver56k/atomicparsley.git atomicparsley
  export ac_cv_func_malloc_0_nonnull=yes
  cd atomicparsley
    rm configure
    apply_patch file://${top_dir}/atomicparsley-min.patch
    generic_configure_make_install
  cd ..
  unset ac_cv_func_malloc_0_nonnull
}

build_wx() {
  git clone https://github.com/wxWidgets/wxWidgets.git WX_3_0_BRANCH
  cd WX_3_0_BRANCH
    generic_configure_make_install "--enable-monolithic --with-opengl"
    # wx-config needs to be visible to this script when compiling
    cp -v ${mingw_w64_x86_64_prefix}/bin/wx-config ${mingw_w64_x86_64_prefix}/../bin/wx-config
  cd ..
}

build_libsndfile() {
  store_libs=$LIBS
  export LIBS="-logg -lvorbis"
  generic_download_and_install http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.25.tar.gz libsndfile-1.0.25 "--enable-experimental"
  export LIBS=$store_libs
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
  download_and_unpack_file  https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.0.tar.bz2 game-music-emu-0.6.0
  cd game-music-emu-0.6.0
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
  do_git_checkout https://github.com/nigels-com/glew.git glew
  cd glew
    cpu_count=1
    do_make extensions
    export cpu_count=$original_cpu_count
    cd build/cmake
      do_cmake "-DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF"
      do_make_install
    cd ../..
#    generic_configure_make_install
  cd ..
}

build_libwebp() {
  generic_download_and_install http://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-0.5.0.tar.gz libwebp-0.5.0
}

build_wavpack() {
  generic_download_and_install http://wavpack.com/wavpack-4.75.2.tar.bz2 wavpack-4.75.2
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
		  mkdir mediainfo
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
		cd ../../../../MediaInfo/Project/GNU/CLI
		do_configure "--host=x86_64-w64-mingw32 --prefix=$mingw_w64_x86_64_prefix --enable-debug --disable-static-libs" # --enable-staticlibs --enable-shared=no LDFLAGS=-static-libgcc"
		sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
		do_make_install
                cd ../../..
                apply_patch file://${top_dir}/mediainfo-GUI_Main_Menu-cpp.patch
                cd Project/GNU/GUI
                do_configure "--host=x86_64-w64-mingw32 --prefix=$mingw_w64_x86_64_prefix --enable-debug --with-wx-config=${mingw_w64_x86_64_prefix}/bin/wx-config --disable-static-libe"
                sed -i.bak 's/ -DSIZE_T_IS_LONG//g' Makefile
                do_make_install
#                cd ../../../../..
		cd ../../../../..
#		echo "Now returned to `pwd`"
}

build_libtool() {
  generic_download_and_install http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz libtool-2.4.6
}

build_libiberty() {
  download_and_unpack_file https://launchpad.net/ubuntu/+archive/primary/+files/libiberty_20160215.orig.tar.xz libiberty-20160215
  cd libiberty-20160215
    do_configure "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-shared --disable-static --enable-install-libiberty" "./libiberty/configure"
    do_make_install
  cd ..
}

build_exiv2() {
  do_svn_checkout svn://dev.exiv2.org/svn/trunk exiv2
  cd exiv2
    apply_patch file://${top_dir}/exiv2-makernote.patch
     cpu_count=1 # svn_version.h gets written too early otherwise
    # export LIBS="-lws2_32 -lwldap32"
     make config
     generic_configure_make_install "CXXFLAGS=-std=gnu++98"
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
  do_git_checkout git://git.code.sf.net/p/bmxlib/bmx bmxlib-bmx # 723e48
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
  # unfortunately this sed isn't enough, though I think it should be [so we add --extra-libs=-lstdc++ to FFmpegs configure] http://trac.ffmpeg.org/ticket/1539
  sed -i.bak 's/-lmodplug.*/-lmodplug -lstdc++/' "$PKG_CONFIG_PATH/libmodplug.pc" # huh ?? c++?
  sed -i.bak 's/__declspec(dllexport)//' "$mingw_w64_x86_64_prefix/include/libmodplug/modplug.h" #strip DLL import/export directives
  sed -i.bak 's/__declspec(dllimport)//' "$mingw_w64_x86_64_prefix/include/libmodplug/modplug.h"
}

build_libcaca() {
  local cur_dir2=$(pwd)/libcaca
#  do_git_checkout git://github.com/cacalabs/libcaca libcaca
  download_and_unpack_file http://caca.zoy.org/files/libcaca/libcaca-0.99.beta18.tar.gz libcaca-0.99.beta18
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
#  download_and_unpack_file http://sourceforge.net/projects/twolame/files/twolame/0.3.13/twolame-0.3.13.tar.gz/download twolame-0.3.13 # "CPPFLAGS=-DLIBTWOLAME_STATIC"
#  cd twolame-0.3.13
#    sed -i.bak 's/libtwolame_la_LDFLAGS  = -export-dynamic/libtwolame_la_LDFLAGS  = -no-undefined -export-dynamic/' libtwolame/Makefile.am
#    ./autogen.sh
#    generic_configure_make_install
#  cd ..
   do_git_checkout https://github.com/njh/twolame.git twolame
   cd twolame
#     sed -i.bak 's/libtwolame_la_LDFLAGS  = -export-dynamic/libtwolame_la_LDFLAGS  = -no-undefined -export-dynamic/' libtwolame/Makefile.am
     apply_patch file://${top_dir}/0001-mingw32-does-not-need-handholding.all.patch
     apply_patch file://${top_dir}/0002-no-undefined-on.mingw.patch
     apply_patch file://${top_dir}/0003-binary-stdin.all.patch
     apply_patch file://${top_dir}/0004-no-need-for-dllexport.mingw.patch
     apply_patch file://${top_dir}/0005-silent.mingw.patch
     sed -i.bak 's/simplefrontend doc tests/simplefrontend tests/' Makefile.am
     generic_configure_make_install
   cd ..
}

build_regex() {
  download_and_unpack_file "http://sourceforge.net/projects/mingw/files/Other/UserContributed/regex/mingw-regex-2.5.1/mingw-libgnurx-2.5.1-src.tar.gz/download" mingw-libgnurx-2.5.1
  cd mingw-libgnurx-2.5.1
    # Patch for static version
    generic_configure
#    apply_patch_p1 file://${top_dir}/libgnurx-1-build-static-lib.patch
#    do_make "-f Makefile.mingw-cross-env libgnurx.a"
    do_make
    x86_64-w64-mingw32-ranlib libregex.a || exit 1 
#    do_make "-f Makefile.mingw-cross-env install-static"
    do_make "install"
    # Some packages e.g. libcddb assume header regex.h is paired with libregex.a, not libgnurx.a
#    cp $mingw_w64_x86_64_prefix/lib/libgnurx.a $mingw_w64_x86_64_prefix/lib/libregex.a
  cd ..
}

build_boost() { 
  download_and_unpack_file "http://sourceforge.net/projects/boost/files/boost/1.60.0/boost_1_60_0.tar.bz2/download" boost_1_60_0
  cd boost_1_60_0 
    local touch_name=$(get_small_touchfile_name already_configured "$configure_options $configure_name $LDFLAGS $CFLAGS") 
    if [ ! -f  "$touch_name" ]; then 
#      ./bootstrap.sh mingw target-os=windows address-model=64 link=shared threading=multi threadapi=win32 toolset=gcc-mingw --prefix=${mingw_w64_x86_64_prefix} || exit 1
       ./bootstrap.sh mingw --prefix=${mingw_w64_x86_64_prefix} || exit 1
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
    sed -i.bak 's/case \*       : option = -pthread ; libs = rt ;/case *      : option = -pthread ;/' tools/build/src/tools/gcc.jam
    echo "using gcc : mingw : x86_64-w64-mingw32-g++ : <rc>x86_64-w64-mingw32-windres <archiver>x86_64-w64-mingw32-ar <ranlib>x86_64-w64-mingw32-ranlib ;" > user-config.jam
    # Configure and build in one step. ONLY the libraries necessary for mkvtoolnix are built.
#      ./b2 --prefix=${mingw_w64_x86_64_prefix} -j 2 --ignore-site-config --user-config=user-config.jam address-model=64 architecture=x86 binary-format=pe link=static --target-os=windows threadapi=win32 threading=multi toolset=gcc-mxe --layout=tagged --disable-icu cxxflags='-std=c++11' --with-system --with-filesystem --with-regex --with-date_time install || exit 1
#      ./b2 --prefix=${mingw_w64_x86_64_prefix} -j 2 --ignore-site-config --user-config=user-config.jam address-model=64 architecture=x86 binary-format=pe link=shared --runtime-link=shared --target-os=windows threadapi=win32 threading=multi toolset=gcc-mingw --layout=tagged --disable-icu cxxflags='-std=c++11' --with-system --with-filesystem --with-regex --with-date_time install || exit 1
      ./b2 -a -d+2 --debug-configuration --prefix=${mingw_w64_x86_64_prefix} variant=release target-os=windows toolset=gcc-mingw address-model=64 link=shared runtime-link=shared threading=multi threadapi=win32 architecture=x86 binary-format=pe --with-system --with-filesystem --with-regex --with-date_time --with-thread --with-test --user-config=user-config.jam install || exit 1
      ./b2 -a -d+2 --debug-configuration --prefix=${mingw_w64_x86_64_prefix} variant=debug target-os=windows toolset=gcc-mingw address-model=64 link=shared runtime-link=shared threading=multi threadapi=win32 architecture=x86 binary-format=pe boost.locale.winapi=on boost.locale.std=on boost.locale.icu=on boost.locale.iconv=on boost.locale.posix=off --with-locale --user-config=user-config.jam install || exit 1
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
    # Configure fixes an optimization problem with mingw 5.1.0 but in fact
    # the problem persists in 5.3.0
    sed -i.bak 's/xx86" && check_version 5\.1\.0/xamd64" \&\& check_version 5.3.0/' ac/debugging_profiling.m4
    sed -i.bak 's/\-O2/-O0/' ac/debugging_profiling.m4
    sed -i.bak 's/\-O3/-O0/' ac/debugging_profiling.m4
    sed -i.bak 's/\-O1/-O0/' ac/debugging_profiling.m4
    generic_configure "--with-boost=${mingw_w64_x86_64_prefix} --with-boost-system=boost_system --with-boost-filesystem=boost_filesystem --with-boost-date-time=boost_date_time --with-boost-regex=boost_regex --without-curl --enable-qt --enable-optimization"
    # Now we must prevent inclusion of sys_windows.cpp because our build uses shared libraries,
    # and this piece of code unfortunately tries to pull in a static version of the Windows Qt
    # platform library libqwindows.a
    sed -i.bak 's!sources("src/info/sys_windows.o!#!' Rakefile
    do_rake_and_rake_install "V=1"
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

build_poppler() {
  do_git_checkout git://git.freedesktop.org/git/poppler/poppler poppler
  cd poppler
    sed -i.bak 's!string\.h!sec_api/string_s.h!' test/perf-test.cc
    sed -i.bak 's/noinst_PROGRAMS += perf-test/noinst_PROGRAMS += /' test/Makefile.am
    # Allow installation of QT5 PDF viewer
    sed -i.bak 's/noinst_PROGRAMS = poppler_qt5viewer/bin_PROGRAMS = poppler_qt5viewer/' qt5/demos/Makefile.am
    generic_configure_make_install "CFLAGS=-DMINGW_HAS_SECURE_API LIBOPENJPEG_CFLAGS=-I${mingw_w64_x86_64_prefix}/include/openjpeg-1.5/ --enable-xpdf-headers" # "--enable-libcurl"
  cd ..
}

build_SWFTools() {
  do_git_checkout git://github.com/matthiaskramm/swftools swftools
  cd swftools
    export DISABLEPDF2SWF=true
    rm configure # Force regeneration of configure script to alleviate mingw-w64 conflicts
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
  do_git_checkout https://github.com/ddennedy/frei0r.git frei0r
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

build_snappy () {
  do_git_checkout https://github.com/google/snappy.git snappy
  cd snappy
    apply_patch file://${top_dir}/snappy-shared-dll.patch
    generic_configure_make_install
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
  do_git_checkout https://bitbucket.org/acoustid/chromaprint.git chromaprint
  cd chromaprint
    do_cmake "-DWITH_FFTW3=ON -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=ON"
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
  generic_download_and_install http://curl.haxx.se/download/curl-7.48.0.tar.bz2 curl-7.48.0 "--enable-ipv6 --with-librtmp"
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

build_asdcplib() {
  export CXXFLAGS=-DKM_WIN32
  export CFLAGS=-DKM_WIN32
  generic_download_and_install http://download.cinecert.com/asdcplib/asdcplib-2.5.12.tar.gz asdcplib-2.5.12 "--with-openssl=${mingw_w64_x86_64_prefix} --with-expat=${mingw_w64_x86_64_prefix}"
  unset CXXFLAGS
  unset CFLAGS
}



build_libtiff() {
  generic_download_and_install ftp://ftp.remotesensing.org/pub/libtiff/tiff-4.0.6.tar.gz tiff-4.0.6
}

build_opencl() {
# Method: get the headers, then create libOpenCL.a from the vendor-supplied OpenCL.dll
# on the compilation system.
# Get the headers from the source
  mkdir -p ${mingw_w64_x86_64_prefix}/include/CL && cd ${mingw_w64_x86_64_prefix}/include/CL
    wget --no-clobber https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_d3d10.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_d3d11.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_dx9_media_sharing.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_ext.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_gl_ext.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_gl.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_platform.h \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/opencl.h \
https://www.khronos.org/registry/cl/api/2.1/cl.hpp \
https://raw.githubusercontent.com/KhronosGroup/OpenCL-Headers/opencl12/cl_egl.h
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
  do_git_checkout git://git.code.sf.net/p/sox/code sox
  cd sox
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv
  fi
  generic_configure_make_install
  cd ..
}

build_wxsvg() {
  generic_download_and_install http://downloads.sourceforge.net/project/wxsvg/wxsvg/1.5.6/wxsvg-1.5.6.tar.bz2 wxsvg-1.5.6 "--with-wx-config=${mingw_w64_x86_64_prefix}/bin/wx-config"
}

build_pixman() {
  do_git_checkout https://github.com/aseprite/pixman.git pixman
  cd pixman
    generic_configure_make_install
  cd ..
}

build_cairo() {
  do_git_checkout git://anongit.freedesktop.org/git/cairo cairo
  cd cairo
    generic_configure_make_install
  cd ..
}

build_mmcommon() {
  do_git_checkout https://github.com/GNOME/mm-common.git mm-common
  cd mm-common
    generic_configure_make_install "--enable-network"
  cd ..
}

build_cairomm() {
  download_and_unpack_file http://cairographics.org/releases/cairomm-1.12.0.tar.gz cairomm-1.12.0
  cd cairomm-1.12.0
    apply_patch file://${top_dir}/cairomm-missing-M_PI.patch
    generic_configure_make_install "--with-boost"
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
    generic_configure_make_install "LIBS=-lxml2"
    unset am_cv_func_iconv
  cd ..
}


build_openssh() {
    generic_download_and_install http://mirror.bytemark.co.uk/pub/OpenBSD/OpenSSH/portable/openssh-7.2p2.tar.gz openssh-7.2p2 "LIBS=-lgdi32"
}

build_libffi() {
  generic_download_and_install ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz libffi-3.2.1
}

build_ilmbase() {
  do_git_checkout https://github.com/openexr/openexr.git openexr
  cd openexr/IlmBase
    # IlmBase is written expecting that some of its binaries will be run during compilation.
    # In a cross-compiling environment, this more difficult to do than I know how.
    # The files that the binaries generate are two quite large headers. We have generated
    # them for you, and copy them to where they're required.
    # Then we patch the Makefiles to prevent the binaries' compilation.
    cp ${top_dir}/openexr-IlmBase-Half-Makefile.am Half/Makefile.am
    cp ${top_dir}/eLut.h Half/eLut.h
    cp ${top_dir}/toFloat.h Half/toFloat.h
    cd IlmThread
    # Now apply patch to cause Windows threads to be used instead of Posix
    # Note that ILM has supplied the code; we merely enable it in Makefile.am
      apply_patch file://${top_dir}/ilmbase-ilmthread-Makefile.am.patch
    cd ..
    generic_configure_make_install "--enable-shared --enable-large-stack"
  cd ../..
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
    sed -i.bak 's/docbook-to-man/docbook2man/' man/Makefile.am
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
  do_git_checkout http://git.videolan.org/git/libudfread.git libudfread
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

build_file() {
  # Also contains libmagic
  do_git_checkout https://github.com/file/file.git file_native
  do_git_checkout https://github.com/file/file.git file
  # We use the git version of file and libmagic, which is updated more
  # often than distributions track. File requires its own binary to compile
  # its list of magic numbers. Therefore, because we are cross-compiling, 
  # we first compile a native 'file' executable, and store it in the path
  # where the mingw-w64 compilers are to be found. We must also modify
  # Makefile.am because it is not written for this kind of cross-compilation.
  cd file_native
    do_configure "--prefix=${mingw_w64_x86_64_prefix}/.. --disable-shared --enable-static"
    do_make_install
  cd ..
  cd file
    apply_patch file://${top_dir}/file-win32.patch
    generic_configure_make_install "--enable-fsect-man5"
  cd ..
}

build_cdrkit() {
  download_and_unpack_file http://pkgs.fedoraproject.org/repo/pkgs/cdrkit/cdrkit-1.1.11.tar.gz/efe08e2f3ca478486037b053acd512e9/cdrkit-1.1.11.tar.gz cdrkit-1.1.11
  cd cdrkit-1.1.11
    apply_patch_p1 file://{$top_dir}/cdrkit-1.1.11-mingw.patch
    apply_patch_p1 file://${top_dir}/cdrkit-1.1.11-cross-compile.patch
    do_cmake
    do_make
    do_make_install
  cd ..
}

build_libebur128() {
  do_git_checkout https://github.com/jiixyj/libebur128.git libebur128
  cd libebur128
    do_cmake "-DENABLE_INTERNAL_QUEUE_H=ON"
    do_make
    do_make_install
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
    sed -i.bak 's/avcodec_alloc_frame/av_frame_alloc/' scanner/inputaudio/ffmpeg/input_ffmpeg.c 
    do_cmake "-DENABLE_INTERNAL_QUEUE_H=ON"
    do_make "VERBOSE=1"
    do_make_install "VERBOSE=1"
    # The executable doesn't get installed
    cp -v loudness.exe ${mingw_w64_x86_64_prefix}/bin/loudness.exe
    cp -v libebur128-ls.dll ${mingw_w64_x86_64_prefix}/bin/libebur128-ls.dll
    cp -v libinput_ffmpeg.dll ${mingw_w64_x86_64_prefix}/bin/libinput_ffmpeg.dll
    cp -v libinput_sndfile.dll ${mingw_w64_x86_64_prefix}/bin/libinput_sndfile.dll
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
  do_git_checkout https://github.com/sekrit-twc/zimg.git zimg
  cd zimg
    sed -i.bak 's/Windows\.h/windows.h/' src/testcommon/mmap.cpp
    generic_configure_make_install "--enable-x86simd --enable-example" 
  cd ..
}

build_libcdio() {
  download_and_unpack_file file://${top_dir}/libcdio-4b5eda30.tar.gz libcdio-cdtext-testing-4b5eda3
#  do_git_checkout git://git.sv.gnu.org/libcdio.git libcdio cdtext-testing
#  cd libcdio
  cd libcdio-cdtext-testing-4b5eda3
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
  generic_download_and_install http://ftp.gnu.org/pub/gnu/gettext/gettext-0.19.7.tar.xz gettext-0.19.7 "CFLAGS=-O2 CXXFLAGS=-O2 LIBS=-lpthread"
}

build_pcre() {
  generic_download_and_install ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.38.tar.bz2 pcre-8.38 "--enable-pcre16 --enable-pcre32 --enable-newline-is-any --enable-jit --enable-utf --enable-pcregrep-libz --enable-pcregrep-libbz2 --enable-pcregrep-libreadline --enable-unicode-properties"
}

build_glib() {
  download_and_unpack_file http://ftp.gnome.org/pub/gnome/sources/glib/2.48/glib-2.48.0.tar.xz glib-2.48.0
  cd glib-2.48.0
    export glib_cv_long_long_format=I64
    export glib_cv_stack_grows=no
    # Work around mingw-w64 lacking strerror_s()
#    sed -i.bak 's/strerror_s (buf, sizeof (buf), errnum);/strerror_r (errno, buf, sizeof (buf);/' glib/gstrfuncs.c
    generic_configure_make_install "--disable-compile-warnings --disable-silent-rules CFLAGS=-DMINGW_HAS_SECURE_API"
    unset glib_cv_long_long_format
    unset glib_cv_stack_grows
  cd ..
}

build_libsigc++() {
  generic_download_and_install http://ftp.gnome.org/pub/GNOME/sources/libsigc++/2.9/libsigc++-2.9.2.tar.xz libsigc++-2.9.2
}

build_libcxml(){
  do_git_checkout https://github.com/cth103/libcxml.git libcxml
  cd libcxml
    export ORIG_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
    export PKG_CONFIG_PATH="${mingw_w64_x86_64_prefix}/lib/pkgconfig"
    # libdir must be set
    do_configure "configure WINRC=x86_64-w64-mingw32-windres CXX=x86_64-w64-mingw32-g++ -vv -pp --prefix=${mingw_w64_x86_64_prefix} --libdir=${mingw_w64_x86_64_prefix}/lib --check-cxx-compiler=gxx" "./waf"
    ./waf build || exit 1
    ./waf install || exit 1
    # The installation puts the pkgconfig file and the DLL import library in the wrong place
    cp -v build/libcxml.pc ${mingw_w64_x86_64_prefix}/lib/pkgconfig
    cp -v build/src/libcxml.dll.a ${mingw_w64_x86_64_prefix}/lib
    export PKG_CONFIG_PATH=$ORIG_PKG_CONFIG_PATH
  cd ..
}

build_glibmm() {
  # Because our threading model for our GCC does not involve posix threads, we must emulate them with
  # the Boost libraries. These provide an (almost) drop-in replacement.
  export GLIBMM_LIBS="-lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lboost_system -lsigc-2.0 -lboost_thread_win32"
  export GIOMM_LIBS="-lgio-2.0 -lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lboost_system -lsigc-2.0"
  download_and_unpack_file http://ftp.acc.umu.se/pub/GNOME/sources/glibmm/2.48/glibmm-2.48.1.tar.xz glibmm-2.48.1
  cd glibmm-2.48.1
    apply_patch file://${top_dir}/glibmm-mutex.patch
    generic_configure_make_install 
  cd ..
  unset GLIBMM_LIBS
  unset GIOMM_LIBS
}

build_libxml++ () {
  generic_download_and_install http://ftp.gnome.org/pub/GNOME/sources/libxml++/2.40/libxml++-2.40.1.tar.xz libxml++-2.40.1
}

build_libexif() {
  download_and_unpack_file http://kent.dl.sourceforge.net/project/libexif/libexif/0.6.21/libexif-0.6.21.tar.gz libexif-0.6.21
  cd libexif-0.6.21
    # We need to update autotools because a check is needed for JPEG files > 2GB
    rm configure
    generic_configure_make_install
  cd ..
}

build_libzip() {
  generic_download_and_install http://www.nih.at/libzip/libzip-1.1.2.tar.xz libzip-1.1.2
}

build_exif() {
  download_and_unpack_file http://heanet.dl.sourceforge.net/project/libexif/exif/0.6.21/exif-0.6.21.tar.bz2 exif-0.6.21
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
  generic_download_and_install http://www.hdfgroup.org/ftp/HDF5/current/src/hdf5-1.8.16.tar.bz2 hdf5-1.8.16
}

build_netcdf() {
  generic_download_and_install ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-4.4.0.tar.gz netcdf-4.4.0 "--enable-dll --disable-netcdf4"
}

build_vlc() {
  # Not built. VLC requires many static libraries, and that's not really my remit just now.
  do_git_checkout https://github.com/videolan/vlc.git vlc
  cd vlc
    generic_configure_make_install "--disable-silent-rules JACK_LIBS=-ljack JACK_CFLAGS=-L${mingw_w64_x86_64_prefix}/../lib"
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
  generic_configure_make_install "--enable-ipv6 --verbose --target-os=MINGW32 --cross-prefix=x86_64-w64-mingw32- --prefix=${mingw_w64_x86_64_prefix} --extra-libs=-lz --enable-all --enable-ffmpeg"

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
  generic_download_and_install http://ftp.gnome.org/pub/gnome/sources/pango/1.40/pango-1.40.1.tar.xz pango-1.40.1
}

build_pangomm() {
  export PANGOMM_LIBS="-lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lglibmm-2.4 -lgio-2.0 -lboost_system -lsigc-2.0 -lboost_thread_win32 -lboost_system -lcairo -lcairomm-1.0 -lpango-1.0 -lpangocairo-1.0"
  generic_download_and_install http://ftp.gnome.org/pub/GNOME/sources/pangomm/2.40/pangomm-2.40.0.tar.xz pangomm-2.40.0
  unset PANGOMM_LIBS
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
}

build_jasper() {
  download_and_unpack_file https://www.ece.uvic.ca/~frodo/jasper/software/jasper-1.900.1.zip jasper-1.900.1
  cd jasper-1.900.1
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
  mkdir build

  local new_hg_version=`hg --debug id -i`
  if [[ "$old_hg_version" != "$new_hg_version" ]]; then
    echo "got upstream hg changes, forcing rebuild...GraphicsMagick"
    cd build
      rm already*
#      generic_download_and_install ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/snapshots/GraphicsMagick-1.4.020150919.tar.xz GraphicsMagick-1.4.020150919 "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-magick-compat --disable-shared --enable-static --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix}/include CPPFLAGS=-I${mingw_w64_x86_64_prefix}" 
#      do_configure "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-magick-compat --disable-shared --enable-static --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix}/include CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
      # Add extra libraries to those required to link with libGraphicsMagick
      sed -i.bak 's/Libs: -L\${libdir} -lGraphicsMagick/Libs: -L${libdir} -lGraphicsMagick -lfreetype -lbz2 -lz -llcms2 -lpthread -lpng16 -ltiff -lgdi32 -lgdiplus -ljpeg -lwebp/' ../magick/GraphicsMagick.pc.in
      # References to a libcorelib are not needed. The library doesn't exist on my platform
      sed -i.bak 's/-lcorelib//' ../magick/GraphicsMagick.pc.in
      do_configure "--host=x86_64-w64-mingw32 --prefix=${mingw_w64_x86_64_prefix} --enable-magick-compat --without-x LDFLAGS=-L${mingw_w64_x86_64_prefix}/lib CFLAGS=-I${mingw_w64_x86_64_prefix}/include CPPFLAGS=-I${mingw_w64_x86_64_prefix}" "../configure"
      do_make_install || exit 1
    cd ..
  else
    echo "still at hg $new_hg_version GraphicsMagick"
  fi
  cd ..
}

build_get_iplayer() {
  # This isn't really "building" - just downloading the latest Perl script from Github, and bundling
  # it with a simple command to call it.
  # Note that these are both development versions, that closely track the developers' work on changes
  # to the BBC website
  curl -o ${mingw_w64_x86_64_prefix}/bin/get_iplayer.pl https://raw.githubusercontent.com/get-iplayer/get_iplayer/develop/get_iplayer
  curl -o ${mingw_w64_x86_64_prefix}/bin/get_iplayer.cmd https://raw.githubusercontent.com/get-iplayer/get_iplayer/master/windows/get_iplayer/get_iplayer.cmd
  # Change the Perl path to include the full path to my default location for this suite
  # otherwise the Perl script isn't found by the command interpreter on Windows
  sed -i.bak 's/get_iplayer.pl/"C:\\Program Files\\ffmpeg\\bin\\get_iplayer.pl"/' ${mingw_w64_x86_64_prefix}/bin/get_iplayer.cmd
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
  local extra_configure_opts="--enable-libsoxr --enable-fontconfig --enable-libass --enable-libutvideo --enable-libbluray --enable-iconv --enable-libtwolame --enable-libzvbi --enable-libcaca --enable-libmodplug --extra-libs=-lstdc++ --extra-libs=-lpsapi --enable-opengl --extra-libs=-lz --extra-libs=-lpng --enable-libvidstab --enable-libx265 --enable-decklink --extra-libs=-loleaut32 --enable-libcdio --enable-libzimg --enable-chromaprint --enable-libsnappy --enable-libebur128"

  if [[ $type = "libav" ]]; then
    # libav [ffmpeg fork]  has a few missing options?
    git_url="https://github.com/libav/libav.git"
    output_dir="libav_git"
    final_install_dir=`pwd`/${output_dir}.installed
    extra_configure_opts="--prefix=$final_install_dir" # don't install libav to the system
  fi

# The -Wno-narrowing is because libutvideo triggers a compiler strictness with the narrowing of a constant inside a curly-bracketed declaration
  extra_configure_opts="$extra_configure_opts --extra-cflags=$CFLAGS --extra-version=COMPILED_BY_JohnWarburton --extra-cxxflags=-Wno-narrowing" # extra-cflags is not needed, but adds it to the console output which I lke

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

  config_options="--arch=$arch --target-os=mingw32 --cross-prefix=$cross_prefix --pkg-config=pkg-config --disable-doc --enable-opencl --enable-gpl --enable-libtesseract --enable-libx264 --enable-avisynth --enable-libxvid --enable-libmp3lame --enable-netcdf --enable-version3 --enable-zlib --enable-librtmp --enable-libvorbis --enable-libtheora --enable-libspeex --enable-libopenjpeg --enable-gnutls --enable-libgsm --enable-libfreetype --enable-libopus --disable-w32threads --enable-frei0r --enable-filter=frei0r --enable-bzlib --enable-libxavs --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-libschroedinger --enable-libvpx --enable-libilbc --enable-libwavpack --enable-libwebp --enable-libgme --enable-libbs2b --enable-libmfx --enable-librubberband --enable-dxva2 --prefix=$mingw_w64_x86_64_prefix $extra_configure_opts --extra-cflags=$CFLAGS" # other possibilities: --enable-w32threads --enable-libflite
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
  echo "FFmpeg binaries are built."
  cd ..
}

build_dvdstyler() {
  generic_download_and_install http://sourceforge.net/projects/dvdstyler/files/dvdstyler-devel/3.0b1/DVDStyler-3.0b1.tar.bz2 DVDStyler-3.0b1 "DVDAUTHOR_PATH=${mingw_w64_x86_64_prefix}/bin/dvdauthor.exe FFMPEG_PATH=${mingw_w64_x86_64_prefix}/bin/ffmpeg.exe --with-wx-config=${mingw_w64_x86_64_prefix}/bin/wx-config"
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
  build_libffi # for glib among others
  build_doxygen
  build_libdlfcn # ffmpeg's frei0r implentation needs this <sigh>
  build_zlib # rtmp depends on it [as well as ffmpeg's optional but handy --enable-zlib]
  build_bzlib2 # in case someone wants it [ffmpeg uses it]
  build_snappy # For certain types of very fast video compression
  build_libpng # for openjpeg, needs zlib
  build_gmp # for libnettle
  build_pcre # for glib and others
  build_libnettle # needs gmp
#  build_libunistring # Needed for guile
#  build_libffi # Needed for guile
#  build_libatomic_ops # Needed for bdw-gc
#  build_bdw-gc # Needed for guile
#  build_guile # Needed for autogen
#  build_autogen # Required for gnutls to see libopts
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
  build_icu
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
  build_libxvid
  build_libxavs
  build_libsoxr
  build_libx262 
  build_libx264 # Libx264 must be installed OVER libx262. x262 is like x264 but with
                # MPEG-2 encoding on top of it. We don't want this, because the version
		# of libx264 it tracks is way behind the current version. Instead, we must
		# be happy with the command-line x262 program, and pipe data to it.
  build_libx265
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
  build_libvpx
#  build_vo_aacenc
  build_libdecklink
  build_liburiparser
  build_libilbc
#  build_icu # Needed for Qt5 / QtWebKit
  build_libmms
  build_portaudio # for JACK
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
  build_glib
  build_libsigc++
  build_glibmm
  build_libxml++
  build_libcxml
  build_jasper # JPEG2000 codec for GraphicsMagick among others
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
  build_glew
#  build_libopenjpeg
#  build_libopenjpeg2
  build_libwebp
  build_filewalk
  build_poppler
  build_SWFTools
  build_jack
  build_opencv
  build_frei0r
  build_liba52
  build_leptonica
  build_pixman
  build_libssh
  build_mmcommon
  build_cairo
  build_cairomm
  build_pango
  build_pangomm
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
  build_vim
  build_ilmbase
#  build_hdf
  build_netcdf
  build_libiberty
  build_graphicsmagick
  build_asdcplib-cth
  build_libdcp
  build_libsub
}

build_apps() {
  # now the things that use the dependencies...
#  build_less
#  build_coreutils
  build_file
  build_exif
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
  if [[ $build_mp4box = "y" ]]; then
    build_mp4box
  fi
  build_exiv2
#  build_cdrecord # NOTE: just now, cdrecord doesn't work on 64-bit mingw. It scans the emulated SCSI bus but no more.
#  build_cdrkit
  build_lsdvd
  build_fdkaac-commandline
#  build_cdrecord
  build_qt
  build_youtube-dl
# build_qt5
  build_mkvtoolnix
  build_opendcp
#  build_openssh
#  build_rsync
  build_dvdbackup
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
  build_wx
  build_wxsvg
  build_mediainfo  
  build_dvdauthor
  build_mlt # Framework, but relies on FFmpeg, Qt, and many other libraries we've built.
  build_DJV # Requires FFmpeg libraries
  build_get_iplayer
  build_dcpomatic
  build_loudness-scanner
  # Because loudness scanner installs its own out-of-date libebur128, we must re-install our own.
#  build_dvdstyler
#  build_vlc # REquires many static libraries, for good reason: but not my remit just now
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
install_cross_compiler 
# the header Windows.h needs to appear
cd ${cur_dir}/mingw-w64-x86_64/include
  ln -s windows.h Windows.h
cd -
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

# A few shared libraries have been installed into ./lib.
# They need to be in ./bin for our installation.
# TODO: CHECK THIS LIST WHEN ADDING NEW PACKAGES

echo "Copying runtime libraries that have gone to the wrong build directory."
wrong_libs=('icudt57.dll' 'icutu57.dll' 'icuin57.dll' 'icuio57.dll' 'icule57.dll' 'iculx57.dll' 'icutest57.dll' 'icuuc57.dll' 'libatomic-1.dll' 'libboost_chrono.dll' 'libboost_date_time.dll' 'libboost_filesystem.dll' 'libboost_prg_exec_monitor.dll' 'libboost_regex.dll' 'libboost_system.dll' 'libboost_locale.dll' 'libboost_thread_win32.dll' 'libboost_unit_test_framework.dll' 'libboost_timer.dll' 'libdcadec.dll' 'libgcc_s_seh-1.dll' 'libopendcp-asdcp.dll' 'libopendcp-lib.dll' 'libpthread.dll' 'libquadmath-0.dll' 'libssp-0.dll' 'libstdc++-6.dll' 'libvtv-0.dll' 'libvtv_stubs-0.dll' 'pthreadGC2.dll' 'wxmsw311u_gl_gcc_custom.dll' 'wxmsw311u_gcc_custom.dll' 'libebur128.dll')
for move in "${wrong_libs[@]}"; do
  cp -Lv "${mingw_w64_x86_64_prefix}/lib/${move}" "${mingw_w64_x86_64_prefix}/bin/${move}" || exit 1
done
echo "Runtime libraries in wrong directory now copied."

# Many DLLs are put in the compiler's directory. I don't know why, but the 
# compilers seem to find them ok.
# These libraries, too, need linking into the object binary directory

echo "Symbolic linking runtime libraries in compiler directory to executables directory."
for library in ${mingw_w64_x86_64_prefix}/../bin/*dll; do
  linkname=$(basename $library)
#  echo "Linking ${library} to ${mingw_w64_x86_64_prefix}/bin/${linkname}"
  ln -fvs ${library} ${mingw_w64_x86_64_prefix}/bin/${linkname} || exit 1
done
echo "Runtime libraries in compiler directory now symbolically linked."

# QT expects its platform plugins to be in a subdirectory of the binary directory
# named "platforms"

# Remove the symbolic link first, or we get an infinite loop
rm -v "${mingw_w64_x86_64_prefix}/bin/platforms"
ln -fvs "${mingw_w64_x86_64_prefix}/plugins/platforms" "${mingw_w64_x86_64_prefix}/bin/platforms"

echo "Stripping all binaries..."

# TODO: Check plugin directories for new things that future builds of QT5 might install

${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/bin/*.exe
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/bin/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/bearer/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/generic/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/iconengines/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/imageformats/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/platforms/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/printsupport/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/plugins/sqldrivers/*.dll
${cross_prefix}strip  -p -s -v ${mingw_w64_x86_64_prefix}/lib/frei0r-1/*.dll
echo "Binaries are stripped. Debugging versions of FFmpeg programs ending _g"
echo "are in build directory."
#echo "searching for some local exes..."
#for file in $(find_all_build_exes); do
#  echo "built $file"
#done
echo "done!"


