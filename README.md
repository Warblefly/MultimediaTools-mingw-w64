# MultimediaTools-mingw-w64
Scripts and patches to cross-compile, for Windows 64-bit, many multimedia utilities, including FFmpeg, OpenDCP and all the BBC Avid-compatible MXF utilities.

# How To Install
A binary package is available for download from this address:
<a href="http://gallery.johnwarburton.net/mingw-multimedia-executables-shared.tar.xz">http://gallery.johnwarburton.net/mingw-multimedia-executables-shared.tar.xz</a>
These binaries are for Windows 64-bit editions only, and hae been tested only on Windows 10.

# How To Compile
1. Ensure your development requirement is adequate. Spin up a Linux Debian image on AWS if you don't already have a GNU/Linux development environment, and give it around 25GB of space. The t2.micro machine type (which falls within the 'Free Tier' for new customers) is sufficient but very slow. I personally use the c4.xlarge for the few hours a full compilation takes.
2. Update to Debian Testing (or your favourite up-to-date distribution), so you have the latest compilers and other tools.
3. Install the pre-requisites. On Debian Testing, you can execute this command:
apt-get install gcc cmake libtool libtool-bin git  autopoint rake autogen xsltproc asciidoc doxygen ruby gperf bzr pax ed g++ bison flex cvs yasm gettext automake autoconf subversion mercurial texinfo pkg-config curl pxz
4. Then install the 'drake' make system that runs under Ruby: gem install drake
5. Clone my package from git (see the address at the top of this page).
6. cd into the top directory of the git tree.
7. Execute ./build_script
8. Wait for about two days on a t2.micro instance.
9. The archive you can copy and unpack has been placed in the root of your build tree.


# Tools Included
With these scripts, you can compile binaries, ready to run on 64-bit Windows, of up-to-date:

* FFmpeg including the kitchen sink (libfdk_aac, frei0r plugins and others not normally included)
* sox
* MP4Box and many other tools from the GPAC project
* raw2bmx and many other BBC MXF utilities and libraries
* opusenc and libopus
* lame and libmp3lame
* libcdio
* tesseract optical character recognition
* exiv2
* youtube-dl
* flac and libflac
* fdk_aac advanced CLI
* x264 H.264 cli and library
* x262 MPEG2 video cli
* x265 HEVC (H.265) cli and library
* opencv libraries and examples
* libqt version 5
* opendcp (not including GUI)
* gdb, the Gnu Debugger
* libtiff and many tiff utilities
* freetype
* fontconfig
* libjpeg2000 (for creating DCPs, etc.)
* mkvtoolsnix
* GraphicsMagick
* mediainfo (CLI)
* mpv media player
* DJV viewer for many professional video image sequence formats
* openssl
* librubberband for pitch shifting
* rtmpdump and librtmpdump
* libsndfile

and many others and their associated libraries. The compiled programs are native Windows 64-bit binaries.

BINARY DISTRIBUTION
===================

I keep a binary tarball on my website.
<a href="http://gallery.johnwarburton.net/mingw-multimedia-executables-shared.tar.xz">http://gallery.johnwarburton.net/mingw-multimedia-executables-shared.tar.xz</a>

Some of the binaries use shared libraries, ending in .dll. Like the executable programs, they're in the /bin/ directory of the distribution. Please keep them together with the .exe programs.


BACKGROUND
==========

Supporting the cross-compilation of the very versatile FFmpeg utilities under mingw-w64, Zeranoe and others publish a set of patches and a build script to, first, compile a working mingw-w64 environment on a POSIX system, then compile a very full FFmpeg and associated libraries and utilities within mingw-w64 ready for installation on a Windows 64-bit system.

With grateful thanks to the Zeranoe and other developers especially Roger Pack, I have extended this build system for my own purposes. At first, this was developed using the Cygwin compatibility suite for Windows, but now it is developed on GNU/Linux.


INSTALLATION
============

This package is designed for 64-bit Windows 10, and is not tested with any other version of Windows.

Your Windows installation needs to have certain packages installed:

* Python 3.5 or later
* Perl, the multi-threaded version

...and, if you use some of my scripts for on-line television viewing,

* The Python m3u8 module (run "pip install m3u8" from an Administrator prompt)

Unpack the archive in a convenient directory on your Windows box. I use C:\Program Files\ffmpeg

The result is that you have these directories:
* C:\Program Files\ffmpeg\bin\
* C:\Program Files\ffmpeg\lib\
* C:\Program Files\ffmpeg\share\
* C:\Program Files\ffmpeg\etc\

Within lib\ and share\, there are subdirectories whose purpose is indicated by their names.

You must set certain environment variables for some facilities to work properly. These are examples from my own system, but I cannot guarantee they are all correct, because they may reference facilities that I personally don't test (yet).

* FONTCONFIG_FILE=fonts.conf
* FONTCONFIG_PATH=C:\Program Files\ffmpeg\etc\fonts
* FREI0R_PATH=C:\Program Files\ffmpeg\lib\frei0r-1
* TESSDATA_PREFIX=C:\Program Files\ffmpeg\share\ (note that TESSDATA_PREFIX is the *parent* of the tessdata language directory)



THANKS
======

* Zeranoe and associated developers. http://zeranoe.com/
* Roger D Pack, https://github.com/rdp/ffmpeg-windows-build-helpers
* The GPAC project http://www.gpac-licensing.com/
* The FFmpeg developers. http://ffmpeg.org
* The whole GNU project, creators of the Gnu Compiler Collection and other utilities
* The BBC developers behind Ingest and libMXF
* Videolan, programmers of x264
* The programmers of x265
* Creator of SoX http://sox.sourceforge.net/
* All whose work is incorporated, and I hope I have preserved their licences.


LICENCE
=======

My script, very much derived from others' work, is released under the GNU Affero GPL Version 3 licence. You will find it at the top of this repository. Please adhere to it. All other programs have their own open source licences, which can be found within their source trees.

The version of FFmpeg built here is non-redistributable.
