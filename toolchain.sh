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

echo "Cloning binutils..."
git clone --depth 1 --single-branch -b binutils-2_35-branch git://sourceware.org/git/binutils-gdb.git binutils || echo "Seems we have binutils."
echo "Binutils has arrived."

mkdir -pv binutils-build
cd binutils-build
	if [[ ! -f binutils_configure ]]; then
		../binutils/configure --target=$host --enable-targets=$host \
			--prefix=$working_directory --with-sysroot=$working_directory
		touch binutils_configure
	fi
	if [[ ! -f binutils_make ]]; then
		make -j $cpu_count && make install
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
		../mingw-w64/mingw-w64-headers/configure --prefix=$working_directory/$host --host=$host --build=x86_64-linux-gnu
		touch mingw_headers_configure
	fi
	if [[ ! -f mingw_headers_make ]]; then
		make -j $cpu_count install
		touch mingw_headers_make
	fi
cd ..
echo "Mingw-w64 headers are installed."

echo "Cloning GCC..."
git clone --depth 1 -b releases/gcc-10 --single-branch https://github.com/gcc-mirror/gcc.git gcc || echo "Seems we have GCC."
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
		wget http://isl.gforge.inria.fr/isl-0.23.tar.xz || exit 1
		tar xvvf isl-0.23.tar.xz && ln -sv isl-0.23 isl
		touch gcc_accessories_source
	else
		echo "Accessories already downloaded and linked."
	fi
	echo "Accessories arrived."
cd ..

# Apply patch. Not sure how long this will be required

cd gcc
	cat ${top_dir}/gcc-ice.patch | patch -p0 || exit 1
cd ..

mkdir -pv gcc-build
cd gcc-build
	echo "Configuring GCC..."

	if [[ ! -f gcc_configured ]]; then
		../gcc/configure --target=$host --enable-targets=$host --enable-libgomp --enable-libgfortran --enable-languages=c,c++,fortran --enable-shared --disable-multilib --prefix=$working_directory --with-sysroot=$working_directory --enable-threads=posix || exit 1
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
#rm -rf binutils-2.34 binutils-build gcc gcc-build mingw-crt-build mingw-headers-build mingw-w64 mingw-winpthreads-build
echo "Cleaned-up."

# Need to get the "depot_tools" for building ANGLE
#git clone --depth 1 --single-branch https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools || echo "Seems we have depot_tools."
