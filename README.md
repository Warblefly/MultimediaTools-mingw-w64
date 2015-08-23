# MultimediaTools-mingw-w64
Scripts and patches to compile many multimedia utilities, including FFmpeg, with mingw-w64 for 64-bit Windows

# Tools Included
By these scripts, you can compile static versions, ready to run on 64-bit Windows, of:

* FFmpeg including the kitchen sink (libfdk_aac, frei0r plugins and others not normally included)
* sox
* MP4Box
* raw2bmx and many other BBC MXF utilities and libraries
* opusenc and libopus
* lame and libmp3lame
* libcdio
* exiv2
* flac and libflac
* fdk_aac advanced CLI
* x264 cli and library
* x265 cli and library
* opencv libraries and examples
* libqt version 4
* opendcp (including GUI)
* gdb, the Gnu Debugger
* libtiff and many tiff utilities
* freetype
* fontconfig
* libjpeg2000 (for creating DCPs, etc.)
* mkvtoolsnix
* GraphicsMagick
* mediainfo (CLI)
* mpv media player
* openssl
* librubberband for pitch shifting
* rtmpdump and librtmpdump
* libsndfile

and many others and their associated libraries. The compiled programs are native Windows 64-bit binaries.

BINARY DISTRIBUTION
===================

I keep a binary tarball on my website. The script in this project automatically creates and copies it.
http://gallery.johnwarburton.net/mingw-multimedia-executables.tar.xz


BACKGROUND
==========

Supporting the cross-compilation of the very versatile FFmpeg utilities under mingw-w64, Zeranoe and others publish a set of patches and a build script to, first, compile a working mingw-w64 environment on a POSIX system, then compile a very full FFmpeg and associated libraries and utilities within mingw-w64 ready for installation on a Windows 64-bit system.

With grateful thanks to Zeranoe and other developers, I have extended this build system for my own purposes. At first, this was developed using the Cygwin compatibility suite for Windows, but now it is developed on GNU/Linux.


HOW TO
======

1. Install your favourite GNU/Linux distribution. Ensure you have development tools.
2. Use git to checkout the project.
3. Edit ./build.sh to select where you want your binaries to be dumped.
4. Run ./build.sh. This launches the other script in a controlled manner that I have tested.
5. Wait quite a long time.
6. Enjoy and share. The resultant archive file, at the time of writing, is 122MB in size.

Run the command again to incorporate updates. Only the parts that need rebuilding will be built.

I have tested neither other command lines nor other builds.

THANKS
======

* Zeranoe and associated developers. http://zeranoe.com/
* The FFmpeg developers. http://ffmpeg.org
* The whole GNU project, creators of the Gnu Compiler Collection and other utilities
* The BBC developers behind Ingest and libMXF
* Videolan, programmers of x264
* The programmers of x265
* Creator of SoX http://sox.sourceforge.net/
* All whose work is incorporated, and I hope I have preserved their licences.


LICENCE
=======

My script, very much derived from others' work, is released under the GNU Affero GPL Version 3 licence. You will find it at the top of this repository. Please adhere to it.

The version of FFmpeg built here is non-redistributable.
