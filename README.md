# MultimediaTools-mingw-w64
Scripts and patches to cross-compile, for Windows 64-bit, many multimedia utilities, including FFmpeg, OpenDCP and all the BBC Avid-compatible MXF utilities.

# Tools Included
By these scripts, you can compile binaries, ready to run on 64-bit Windows, of up-to-date:

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
* x264 H.264 cli and library
* x265 HEVC (H.265) cli and library
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
<a href="http://gallery.johnwarburton.net/mingw-multimedia-executables-shared.tar.xz">http://gallery.johnwarburton.net/mingw-multimedia-executables-shared.tar.xz</a>

Some of the binaries use shared libraries, ending in .dll. Like the executable programs, they're in the /bin/ directory of the distribution. Please keep them together with the .exe programs.


BACKGROUND
==========

Supporting the cross-compilation of the very versatile FFmpeg utilities under mingw-w64, Zeranoe and others publish a set of patches and a build script to, first, compile a working mingw-w64 environment on a POSIX system, then compile a very full FFmpeg and associated libraries and utilities within mingw-w64 ready for installation on a Windows 64-bit system.

With grateful thanks to the Zeranoe and other developers especially Roger Pack, I have extended this build system for my own purposes. At first, this was developed using the Cygwin compatibility suite for Windows, but now it is developed on GNU/Linux.


HOW TO
======

1. Install your favourite GNU/Linux distribution. Ensure you have development tools.
2. Use git to checkout the project.
3. Edit ./build_shared.sh to select where you want your binaries to be dumped.
4. Make sure you've lots of swap space, and around 10GB disc space.
5. Run ./build_shared.sh. This launches the other script in a controlled manner that I have tested.
6. Wait quite a long time, maybe 12 hours, maybe a day.
7. Enjoy and share. The resultant archive file, at the time of writing, is 80MB in size.

Run the command again to incorporate updates. Note that FFmpeg won't be rebuilt merely because updated libraries have been built: FFmpeg itself requires a code change before it is freshly built.

These binaries for Windows 64-bit are tested on Windows 10, and are built both on a Fedora 22 box, and a Debian "testing" Apple G4 computer.

OTHER FILES
===========

The very useful Python script youtube-dl, an open-source project, allows video and audio files to be extracted and played (by mpv)
or downloaded from a large number of streaming video and audio sites. Although the script's name suggests it is for YouTube alone,
it works with many others. 

I have not yet written the installation script necessary to incorporate youtube-dl in my binary distribution. However, the project's
homepage, from which you can get your own copy, is: 

https://rg3.github.io/youtube-dl/

THANKS
======

* Zeranoe and associated developers. http://zeranoe.com/
* Roger D Pack, https://github.com/rdp/ffmpeg-windows-build-helpers
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
