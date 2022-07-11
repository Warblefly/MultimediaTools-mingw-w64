#!/bin/bash

cd ..
export top_dir=$(pwd)
cd -
echo "Setting top directory to $top_dir"

echo "How many CPUs?"
cpu_count="$(grep -c processor /proc/cpuinfo)"
echo "We have $cpu_count processor(s)."

mkdir -pv x86_64-w64-mingw32 || exit 1
echo "Build directory 'x86_64-w64-mingw32' created"

cd x86_64-w64-mingw32

export working_directory="$PWD"
export host="x86_64-w64-mingw32"
export prefix="$working_directory/$host"
export PATH="$working_directory/bin:/usr/local/bin:/usr/bin:/bin"

#echo "Cloning binutils..."
#git clone --depth 1 --single-branch -b binutils-2_35-branch git://sourceware.org/git/binutils-gdb.git binutils || echo "Seems we have binutils."
#echo "Binutils has arrived."

echo "Getting binutils..."
#	wget http://ftp.gnu.org/gnu/binutils/binutils-2.36.1.tar.bz2 || exit 1
#        tar xvvf binutils-2.36.1.tar.bz2 && ln -sv binutils-2.36.1 binutils
	git clone --depth 1 --single-branch -b binutils-2_38 https://github.com/bminor/binutils-gdb.git binutils || echo "Seems we have binutils."
#	git clone --depth 1 --single-branch -b binutils-2_36-branch git://sourceware.org/git/binutils-gdb.git binutils || echo "Seems we have binutils."
echo "Binutils has arrived."

#echo "Let's add the Fedora rawhide patch set."
cd binutils
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-export-demangle.h.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-no-config-h-check.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-filename-in-error-messages.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-revert-PLT-elision.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-readelf-other-sym-info.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-2.27-aarch64-ifunc.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-do-not-link-with-static-libstdc++.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/f34/f/binutils-gold-ignore-discarded-note-relocs.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-special-sections-in-groups.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-fix-testsuite-failures.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-gold-mismatched-section-flags.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/f34/f/binutils-readelf-compression-header-size.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-CVE-2019-1010204.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-gold-warn-unsupported.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-use-long-long.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/f34/f/binutils_CVE-2020-16598.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/f34/f/binutils-gdb.git-365f5fb6d0f0da83817431a275e99e6f6babbe04.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/f34/f/binutils-gdb.git-1a1c3b4cc17687091cff5a368bd6f13742bcfdf8.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/f34/f/binutils-gdb.git-014cc7f849e8209623fc99264814bce7b3b6faf2.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-2.36-branch-updates.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-testsuite-fixes.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-binutils/raw/rawhide/f/binutils-config.patch | patch -p1

#	echo "Preparing libiberty..."
#	pushd libiberty
#		autoconf
#	popd
#	echo "Libiberty prepared."
#	echo "Preparing intl..."
#	pushd intl
#		autoconf
#	popd 
#	echo "Intl prepared."
cd ..

mkdir -pv binutils-build
cd binutils-build
	if [[ ! -f binutils_configure ]]; then
		../binutils/configure --target=$host --disable-nls \
			--prefix=$working_directory --with-sysroot=$working_directory
		touch binutils_configure
	fi
	if [[ ! -f binutils_make ]]; then
		make -j $cpu_count || exit 1
		make install || exit 1 
		touch binutils_make
	fi
cd ..
echo "Binutils is made."

echo "Where is our linker?"
which x86_64-w64-mingw32-ld

echo "Checking the binary directory is in our PATH..."
echo $PATH

echo "Making the mingw link..."
ln -sv $host $working_directory/mingw

echo "Cloning the mingw-w64 headers, crt and libraries..."
git clone git://git.code.sf.net/p/mingw-w64/mingw-w64 mingw-w64 || echo "Seems we have mingw-w64."
echo "mingw-w64 has arrived."

# This is a checkout before some tcpip headers break Pulseaudio etc.
#cd mingw-w64
#	git checkout ad98746ace05548a19c25274164592111846b778
#cd ..

#cd mingw-w64
#cat ../../mingw-w64-reverse-ks.patch | patch -p1 || exit 1
#cd ..

cd mingw-w64/mingw-w64-headers
	echo "patching shlguid.h..."
	
	if [[ ! -f mingw_patched ]]; then
		cat $top_dir/shlguid.patch | patch -p0 --verbose || exit 1
		touch mingw_patched
	else
		echo "Already patched."
	fi
	echo "patching _mingw.h.in..."

	if [[ ! -f _mingw_h_in_patched ]]; then
		cat $top_dir/_mingw.h.in.patch | patch -p0 --verbose || exit 1
		touch _mingw_h_in_patched
	else
		echo "Already patched."
	fi
	
#	if [[ ! -f mingw_propvarutil_patched ]]; then
#		cat $top_dir/mingw-propvarutil.patch | patch -p0 --verbose || exit 1
#		touch mingw-propvarutil_patched
#	else
#		echo "Already patched."
#	fi

#        if [[ ! -f stpcpy_patched ]]; then
#                cat $top_dir/mingw-stpcpy.patch | patch -p0 --verbose || exit 1
#                touch stpcpy_patched
#        else
#                echo "Already patched."
#        fi
cd ../..

echo "Going to install mingw-w64 headers..."
mkdir -pv mingw-headers-build
cd mingw-headers-build

	if [[ ! -f mingw_headers_configure ]]; then
		../mingw-w64/mingw-w64-headers/configure --enable-sdk=all --enable-secure-api --prefix=$working_directory/$host --host=$host --build=x86_64-linux-gnu
		touch mingw_headers_configure
	fi
	if [[ ! -f mingw_headers_make ]]; then
		make -j $cpu_count install
		touch mingw_headers_make
	fi
cd ..
echo "Mingw-w64 headers are installed."

echo "Cloning GCC..."

#git clone --depth 1 https://github.com/gcc-mirror/gcc.git gcc || echo "Seems we have GCC."
git clone https://github.com/gcc-mirror/gcc.git gcc
cd gcc
	git checkout e6d369bbdb4eb5f03eec233ef9905013a735fd71 || echo "Correct commit of GCC." 
cd ..

#git clone --depth 1 git://gcc.gnu.org/git/gcc.git gcc-dir.tmp
#git --git-dir=gcc-dir.tmp/.git fetch --depth 1 origin 3fc88aa16f1bf661db4518d6d62869f081981981
#git --git-dir=gcc-dir.tmp/.git archive --prefix=mingw-gcc-10.2.1-20200723/ 3fc88aa16f1bf661db4518d6d62869f081981981 | gzip -v -v -9 > mingw-gcc-10.2.1-20200723.tar.gz
#rm -rf gcc-dir.tmp
#tar xvvf mingw-gcc-10.2.1-20200723.tar.gz
#rm mingw-gcc-10.2.1-20200723.tar.gz
#mv mingw-gcc-10.2.1-20200723 gcc

echo "GCC has arrived."

cd gcc
	echo "To build GCC, we need some accessories."
	if [[ ! -f gcc_accessories_source ]]; then
		wget https://gmplib.org/download/gmp/gmp-6.2.1.tar.lz || exit 1
		tar xvvf gmp-6.2.1.tar.lz && ln -sv gmp-6.2.1 gmp
		wget https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.xz || exit 1
		tar xvvf mpfr-4.1.0.tar.xz && ln -sv mpfr-4.1.0 mpfr
		wget https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz || exit 1
		tar xvvf mpc-1.2.1.tar.gz && ln -sv mpc-1.2.1 mpc
		wget https://libisl.sourceforge.io/isl-0.24.tar.xz || exit 1
		tar xvvf isl-0.24.tar.xz && ln -sv isl-0.24 isl
		touch gcc_accessories_source
	else
		echo "Accessories already downloaded and linked."
	fi
	echo "Accessories arrived."
cd ..

# Apply patch. Not sure how long this will be required

cd gcc
#	cat ${top_dir}/gcc-autoconf.patch | patch -p0
#	curl https://src.fedoraproject.org/rpms/mingw-gcc/raw/rawhide/f/mingw-gcc-config.patch | patch -p1
#	curl https://src.fedoraproject.org/rpms/mingw-gcc/raw/rawhide/f/0020-libgomp-Don-t-hard-code-MS-printf-attributes.patch | patch -p1
#	curl "https://gcc.gnu.org/bugzilla/attachment.cgi?id=53052" | patch -p0
	pushd libiberty
		autoconf -f
	popd
	pushd intl
		autoconf -f
	popd
#	cat ${top_dir}/gcc-ice.patch | patch -p0 || exit 1
cd ..

mkdir -pv gcc-build
cd gcc-build
	echo "Configuring GCC..."

	if [[ ! -f gcc_configured ]]; then
		../gcc/configure --target=$host --with-gnu-as --with-gnu-ld --verbose --without-newlib --disable-multilib --with-system-zlib --disable-nls --without-included-gettext --disable-win32-registry --enable-libgomp --enable-libgfortran --enable-languages=c,c++,fortran --prefix=$working_directory --with-sysroot=$working_directory --enable-shared --enable-threads=posix || exit 1
		touch gcc_configured
	else
		echo "GCC already configured."
	fi

	if [[ ! -f all_gcc_make ]]; then
		echo "Making GCC, c compiler only..."
		make -j $cpu_count all-gcc || exit 1
		touch all_gcc_make
	else
		echo "GCC, c compiler only, already made."
	fi

	if [[ ! -f all_gcc_make_install ]]; then
		echo "Installing GCC, c compiler only..."
		make install-gcc || exit 1
		touch all_gcc_make_install
	else
		echo "GCC, c compiler only, already installed."
	fi
	
	echo "GCC, c compiler complete and installed."
		
cd ..

mkdir -pv mingw-crt-build
cd mingw-crt-build
	echo "Configuring C runtime for Windows..."
	if [[ ! -f mingw-crt-configured ]]; then
		../mingw-w64/mingw-w64-crt/configure --prefix=$working_directory/$host --with-sysroot=$working_directory \
			--enable-lib64 --disable-lib32 --host=$host --build=x86_64-linux-gnu --disable-libarm32 --disable-libarm64
		touch mingw-crt-configured
	else
		echo "C runtime for Windows already configured."
	fi
	echo "C runtime for Windows configured."

	if [[ ! -f mingw-crt-make ]]; then
		make -j $cpu_count || exit 1
		touch mingw-crt-make
	else
		echo "C runtime for Windows already made."
	fi

	if [[ ! -f mingw-crt-make-install ]]; then
		make install || exit 1
		touch mingw-crt-make-install
	else
		echo "C runtime for Windows already installed."
	fi
	echo "C runtime for Windows complete and installed."
cd ..


mkdir -pv mingw-winpthreads-build
cd mingw-winpthreads-build
	
	echo "Configuring winpthreads library..."
	if [[ ! -f winpthreads_configured ]]; then
		../mingw-w64/mingw-w64-libraries/winpthreads/configure --prefix=$working_directory/$host --host=$host --build=x86_64-linux-gnu
		touch winpthreads_configured
	else
		echo "winpthreads already configured."
	fi

	if [[ ! -f winpthreads_make ]]; then
		make -j $cpu_count || exit 1
		touch winpthreads_make
	else
		echo "winpthreads already made."
	fi

	if [[ ! -f winpthreads_make_install ]]; then
		make install || exit 1
		touch winpthreads_make_install
	else
		echo "winpthreads already installed."
	fi
	echo "Winpthreads made and installed."
cd ..

mkdir -pv mingw-widl-build
cd mingw-widl-build
	
	echo "Configuring widl tool..."
	if [[ ! -f widl_configured ]]; then
		../mingw-w64/mingw-w64-tools/widl/configure --prefix=$working_directory/$host --target=x86_64-w64-mingw32 # --host=x86_64-linux-gnu --build=x86_64-linux-gnu
		touch widl_configure
	else
		echo "widl already configured."
	fi

	if [[ ! -f widl_make ]]; then
		make -j $cpu_count || exit 1
		touch widl_make
	else
		echo "widl already made."
	fi

	if [[ ! -f widl_make_install ]]; then
		make install || exit 1
		touch widl_make_install
	else
		echo "widl already installed."
	fi
	echo "Widl made and installed."
cd ..


cd gcc-build
	
	if [[ ! -f gcc-make ]]; then
		make -j $cpu_count || exit 1
		touch gcc-make
	else
		echo "GCC full suite already made."
	fi
	
	if [[ ! -f gcc-make-install ]]; then
		make install || exit 1
		touch gcc-make-install
	else
		echo "GCC full suite already installed."
	fi
	echo "GCC full suite made and installed."
cd ..
echo "All tools built and installed."
echo "Clean-up..."
rm -rfv binutils binutils-build gcc gcc-build mingw-crt-build mingw-headers-build mingw-w64 mingw-winpthreads-build mingw-widl-build
echo "Cleaned-up."

# Need to get the "depot_tools" for building ANGLE
#git clone --depth 1 --single-branch https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools || echo "Seems we have depot_tools."
