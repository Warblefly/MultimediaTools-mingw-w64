# MultimediaTools W64
Scripts and patches to cross-compile, for Windows 64-bit, many multimedia utilities, including FFmpeg, Dcp-o-matic, SoX, the mpv player, and all the BBC Avid-compatible MXF utilities. Also includes all Qt5 (version 5.11.2) libraries that will compile on mingw-w64, GraphicMagick, Poppler-utils (for PDF files) and many, many more. 

# How To Install

A binary package is available for download from this address:
<a href="http://gallery.johnwarburton.net/MultimediaTools-mingw-w64-Open-source.exe">http://gallery.johnwarburton.net/MultimediaTools-mingw-w64-Open-source.exe</a>

These files are tested here when installed to C:\Program Files\ffmpeg. Other locations may work, but have not been tested.

These binaries are for Windows 64-bit editions only, and have been tested only on Windows 10.

Your Windows installation needs to have certain packages installed:

* Python 3.5 or later
* Perl, the multi-threaded version

...and, if you use some of my scripts for on-line television viewing,

* The Python m3u8 module (run "pip install m3u8" from an Administrator prompt)

The installer sets certain environment variables for some facilities to work properly. 

* FONTCONFIG_FILE=fonts.conf
* FONTCONFIG_PATH=C:\Users\\---YOUR-USER-NAME---\AppData\Local\fontconfig
* FREI0R_PATH=C:\Program Files\ffmpeg\lib\frei0r-1
* TESSDATA_PREFIX=C:\Program Files\ffmpeg\share\ (note that TESSDATA_PREFIX is the *parent* of the tessdata language directory)
* TERMINFO=C:\Program Files\ffmpeg\share\terminfo
* VIMRUNTIME=C:\Program Files\ffmpeg\share\vim

# After Installing

You may need to run fc-cache.exe as an Administrator, to help fontconfig put a cache of your Windows fonts into a suitable place. I'd make the installer do it for you, but I haven't worked out how to do this yet.

You might also want to play with the defaults for the mpv player, in %APPDATA%\Roaming\mpv (mpv.conf). It's a highly configurable player, and you may want to adjust it manually for best performance in your environment. An example file is included in this distribution in the share directory for mpv. Copy it to where you need it.


# How To Compile
0. Compiling is becoming increasingly difficult. Source packages are constantly being updated (for which we rejoice, of course), and I am keeping up with these changes quite well. However, some changes that might break compilation go un-noticed because I only accomplish a completely clean build about once a month. Otherwise, packages such as GCC and QT-5.11.2 remain at reasonable recent release levels, with some patches applied. This does not affect the latest and greatest versions of ffmpeg, mpv, vim/gvim, x264, x265 and their associated libraries that are all compiled from development sources.
1. Ensure your development requirement is adequate. I now develop on a Docker container, using Debian Testing. Allow Docker to use all your CPUs, 8GB of RAM, and have an 80GB virtual disk.

Launch the container like this (QT compilation generates a security problem under a normal launch):
```
docker run -it --security-opt seccomp=unconfined debian:testing bash
```
2. Update everything.
```
apt update
apt upgrade
```

3. Install the pre-requisites. On Debian running under Windows, you can do this.
```
apt install software-properties-common extra-cmake-modules libsdl1.2debian libsdl1.2-dev libsdl2-2.0 libsdl2-dev ant asciidoc autoconf autoconf-archive autogen autopoint bison bzr cmake curl cvs docbook2x ed flex g++ libgdk-pixbuf2.0-dev gengetopt git gperf gtk-doc-tools gtk-update-icon-cache gyp intltool liborc-0.4 libsamplerate-dev libtasn1-bin librhash0 libtool libtool-bin lua5.3 mercurial meson nsis mm-common nasm openjdk-8-jdk patchutils pax pxz python-dev ragel rsync ronn ruby-json rake-compiler ruby-ronn sassc libspeex-dev libspeexdsp-dev ssh sshpass sssd-tools subversion libwxbase3.0-dev wget wx-common xutils-dev yasm
```
Then, switch your Java development kit to an Oracle version. You'll need this to compile libbluray:
```
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886  
apt update
apt upgrade 
add-apt-repository ppa:webupd8team/java 
apt update
apt upgrade
apt-get install oracle-java8-installer  
```
4. Link an executable, thus: ln -s /usr/bin/luac5.3 /usr/bin/luac
5. Clone my package from git (see the address at the top of this page).
6. cd into the top directory of the git tree.
7. Read the top of ./build_shared.sh, and edit the location to which scp should copy your binary archive.
8. Execute ./build_shared.sh, and give it the password for your scp when prompted.
9. Wait for a long, long time. On an eight-core i7 at 4.5GHz with 16GB RAM and solid state drives, the compile takes six hours.
10. The archive you can copy and unpack has been placed in the root of your build tree and has been sent by scp to the webserver of your choice. Note that the scp copy will only succeed if you have already used ssh to login to the remote server under the username you're using.
11. To recompile only the packages that have been updated, simply run the script again. You may need manually to clear out mpv, aom, vim and vim_console



# Tools Included
With these scripts, you can compile binaries, ready to run on 64-bit Windows. Many libraries are included. Here are some of the executables that link to these libraries. THIS LIST IS OUT OF DATE.

* libfdk_aac
  * aac-enc — simple AAC encoder including HE-AACv2 and two low-delay versions of the codec
  * fdkaac — complex and fine-tuned AAC encoder allowing adjustment of many parameters
* GraphicsMagick, an improvement on ImageMagick, including the following utilities:
  * compare — compare two images
  * composite — composite images together
  * conjure — execute a Magick Scripting Language (MSL) XML script
  * convert — convert an image or a sequence of images
  * gm — interface to many GraphicsMagic tools
  * identify — describe an image or an image sequence
  * mogrify — transform an image or an image sequence
  * montage — create a composite image in a grid from separate images
* FFmpeg
  * ffmpeg — a very full build of the multimedia file processing utility
  * ffplay — simple command-line multimedia player
  * ffprobe — prints information gleaned by FFmpeg libraries from a given file
* libfftw
  * fftw-wisdom — create pre-planned/optimised transforms for specified sizes
* SoX — the Swiss Army Knife of audio
 * sox — the command-line audio utility with many built-in effects
 * soxi — gives information about audio files
 * play — plays and optionally processes audio data using the capabilities of sox
 * rec — records audio data using the capabilities of sox
* Filezilla, the graphical file transfer utility
* mjpegtools — many tools for motion JPEG files and DVD creation
 * mpeg2enc — flexible program to encode MPEG2 video streams
 * mplex — multiplexes many types of MPEG streams
 * jpeg2yuv — pipes a sequence of JPEG files to stdout, converted to YUV
 * lav2wav — extracts audio from lav-readable files
 * lav2yuv — converts MJPEG video sequence to raw YUV data
 * lavaddwav — adds a WAV file as a soundtrak to an AVI file
 * lavpipe — creates raw YUV streams from pipe list scripts
 * lavplay — plays and edits MJPEG video, including certain hardware acceleration
 * lavtrans — converts MJPEG videos to other MJPEG video formats
 * matteblend.flt — unknown - takes 3 parameters
 * mjpeg_simd_helper — returns list of possible values for environment variable MJPEGTOOLS_SIMD_DISABLE
 * multiblend.flt — blends two MJPEG streams by selectable mask
 * png2yuv — pipes a sequence of PNG files to stdout as YUV4MPEG data stream
 * pnmtoy4m — reads raw PNM/PAM images and produces YUV4MPEG2 stream on stdout. Converts colourspace
 * ppmtoy4m — reads raw PPM images and produes YUV4MPEG2 stream out stdout. Converts colourspace
 * transist.flt — reads two frame-interlaced YUV4MPEG streams from stdin and writes out translation from one to the other
 * y4mcolorpars — generates standard SMPTE test pattern
 * y4mstabilizer — stabilizes video stream
 * y4mtopnm — reads YUV4MPEG2 stream on stdin, produces PPM, PGM or PAM images on stdout. Converts colourspace
 * y4mtoppm — reads YUV4MPEG2 stream on stdin, produces PPM, PGM or PAM images on stdout. Converts colourspace
 * ypipe — interlaces output of two YUV4MPEG-emitting programs into one output stream
 * yuv2lav — converts raw YUV data to MJPEG video sequence
 * yuvfps — resamples yuv video stream to dfferent frame rate
 * yuvinactive — sets part of incoming image to be blank or filled with colour
 * yuvplay — plays back an MJPEG file with various alterations if requested
 * y4mdenoise — denoises video according to several user-selectable methods
 * y4mscaler — scales incoming video in a flexible way
 * y4munsharp — applies unsharp filter to video, optionally legalizes output
 * pgmtoy4m — converts the PGM output of "mpeg2dec -o pgmpipe" to YUV4MPEG2
 * y4mblack — creates black video
 * y4mhist — creates text-mode histogram/vectorscope from incoming video
 * y4minterlace — creates interlaced output from double-frame-rate progressive input
 * y4mivtc — removes 2:3 pulldown correctly
 * y4mshift — shifts picture data within the frame
 * y4mspatialfilter — FIR filter for noise/bandwidth reduction without scaling
 * y4mtoyuv — converts YUV4MPEG2 to EYUV format
 * yuv4mpeg — converts EYUV to YUV4MPEG2
 * yuvmedianfilter — looks around the current point for a radius and averages values within threshold
 * yuyvtoy4m — relacks YUYV and UYVY into YUV4MPEG2
 * yuvcorrect — applies many colour and interlacing corrections
 * yuvdeinterlae — deinterlaces applying motion compensation
 * yuvdenoise — reduces noise temporally or specially, with fine-tuning
 * yuvkineco — automatically try to remove pulldown patterns
 * yuvycsnoise — denoiser especially for NTSC Y/C separation noise
 * yuvscaler — scales incoming video to many pre-set sizes
* Synaesthesia
 * synaesthesia - the original sound-to-light program
* Movit
 * libmovit - for image processing in certain applications
* libdv — processing library and some utilities for DV digital video streams
 * dubdv — inserts audio into a DV stream, discarding existing audio if any
 * encodedv — encodes incoming uncompressed video or image sequence into DV format
 * fix_headers — might fix DV headers. Documentation and code comments non-existent
 * scan_packet_headers — appears to perform basic packet detection on DV stream into stdin
 * steal_header — appears to write header from one stream onto data of another
* Swftools
  * as3compile — a stand-alone ActionScript 3.0 compiler to SWF
  * font2swf — converts a freetype-supported font to SWF
  * jpeg2swf — creates SWF from JPEG files
  * png2swf — creates SWF from PNG files
  * swfbbox — calculates, displays and manipulates bounding boxes in SWF files
  * swfc — creates SWF files from simple script files, supporting ActionScript 2.0 and ActionScript 3.0
  * swfcombine — inserts SWFs into Wrapper SWFs, contatenates SWFs, stacks SWFs or manipulates parameters
  * swfdump — retrieves data in SWFs, e.g. images, fonts, sounds; disassembles code, cross-references and bounding box data
  * swfextract — extracts movies, animations, audio, images etc., from SWF files
  * swfrender — renders SWF file to series of static images, suitable for input into film editing
  * swfstrings — outputs text data found in SWF files
  * wav2swf — converts WAV audio to SWF file
* libpng — library for manipulating, coding and decoding PNG files
 * pngfix — detects and optionally fixes many problems that might occur within PNG files
 * png-fix-itxt — fixes a PNG file written with libpng-1.6.0 or 1.6.1 that has one or more uncompressed iTXt chunks
* Chromaprint — audio fingerprint library
 * fpcalc — calculate audio fingerprint from incoming file
* libfribidi — unicode bidirectional algorithm implementation library
 * fribidi — command-line interface to GNU FriBidi library
* gavl — Gmerlin Audio Video Library
 * gavfdump — prints data from certain files through libgavl
* GDB — the GNU debugger
 * gdb — the GNU debugger compiled for mingw-w64 debugging
 * gdbserver — the GNU debugger server, for additional facilities
* dbus — library for inter-process communication
 * gdbus — a tool for working with D-Bus objects
 * gio-querymodules — GIO cache creation
 * qdbus — interrogates a D-Bus server
 * qdbusviewer — QT5 application that interrogates a D-Bus server
* libaom — the moving image compression format under development by Google and others
* DCP-o-matic
 * dcpomatic2 — a very flexible DCP creation package
 * dcpdiff — compares metadata and content, ignoring timestamps, of two DCPs
 * dcpdumpsub — extracts subtitles from DCP MXF
 * dcpinfo — outputs information about a DCP
 * dcpomatic2_batch — dcpomatic batch worker
 * dcpomatic2_cli — CLI to DCP-o-matic server
 * dcpomatic2_create — create DCP
 * dcpomatic2_kdm — DCP-o-matic KDM creator with GUI
 * dcpomatic2_kdm_cli — CLI DCP-o-matic KDM creator
 * dcpomatic2_server — DCP-o-matic server 
 * dcpomatic_server_cli — CLI to DCP-o-matic server 
* OpenDCP — create SMTPE and Interop DCP packages
 * opendcp_j2k — creates OpenDCP compliant JPEG2000 images in XYZ colourspace from TIFF files
 * opendcp_largefile — tests for large-file support
 * opendcp_mxf — wraps J2K files or audio files in OpenDCP compliant MXF containers
 * opendcp_xml — creates the XML files that provide metadata for MXF containers within a DCP
 * opendcp_xml_verify — verifies the digital signature of an XML DCP file
* openssl — package to generate, test and manipulate cryptographic keys
 * openssl — shell into libopenssl, for generating, testing and manipulating cryptographic keys and encryption/decryption
* libebur128 — library and utilities for measuring loudness to EBU R.128 standard
 * loudness — measures EBU R.128 loudness of file, and optionally tag it with this data
* taglib — library for manipulating metadata of many media file types
 * tagreader — Displays some basic tag information about a file
 * tagreader_c — as 'tagreader' but written in plain C
 * tagwriter — adds metadata to a media file
 * strip_id3v1 — removes the v1 tag in an MP* audio file
 * framelist — offers certain information about id3v1 and id3v2 tags, or APE tags     
* libzip — library and utilities for zip files
 * ziptool — modifies zip files
 * zipmerge — merges zip files
 * zipcmp — compares many details of zip files
* libOpus — encodes, decodes and manipulates audio using the Opus codec
 * opusdec — decodes Opus audio files
 * opusenc — encodes and tags Opus audio files
 * opusinfo — shows metadata about Opus audio files
* libspeex — library for encoding and decoding audio with the Speex codec
 * speexenc — encodes audio data using the Speex codec
 * speecdec — decodes compressed audio data using the Speex codec
* liborc — library for compiling and running simple programs on arrays of data
 * orc-bugreport — processor opcode testing tool
 * orcc — compiles orc instructions
* asdcp-lib utilities for testing and manipulating Digital Cinema Package (DCP) files
  * asdcp-info — show basic information about files forming part of DCPs
  * asdcp-test — manipulate, disassemble and test DCP files
  * asdcp-unwrap — unwrap DCP file elements, and re-wrap some elements
  * asdcp-util — useful asdcp-lib functions exposed through a command line utility
  * asdcp-wrap — wrap DCP elements (e.g. J2K images and audio) into DCP
  * blackwave — create silent audio elements
  * j2c-test — JP2K parser test
  * klvsplit — split KLV packets
  * klvwalk — test structure of MXF
  * kmfilegen — large file test program
  * kmrandgen — pseudo-random number generator utility
  * knuuidgen — UUID generator
  * MXFDump — test or unwrap MXF files, especially those created for DCPs
  * wavesplit — creates a WAV file for each channel in the input file
* LAME — Lame Ain't an MPEG Encoder
 * lame — the open-source MP3 encoder
* WavPack — audio compression that can be lossless
 * wavpack — compress audio losslessly (with lossy option if requested)
 * wavunpack — decompress WavPack compressed audio files
 * wvgain — ReplayGain scanner and tagger
* libx262 — library using x264 techniques to encode MPEG-2 video
 * x262 — encodes video using the MPEG-2 standard. Better than FFmpeg native coder
* libx264 — very well-maintained H.264 codec library
 * x264 — encodes video using the H.264/AVC standard
* libx265 — very well-maintained HEVC (H.265) codec library
 * x265 encodes video using the H.265/HEVC standard
* libxavs — library implementing the xavs video coding standard
 * xavx — encodes and decodes video compressed with the Xavx codec
* JACK audio server
 * jack_alias — list active Jack ports and optionally display extra information
 * jack_bufsize — set Jack buffer size
 * jack_connect — connects two Jack ports together
 * jack_cpu_load — observe the CPU load on a Jack server
 * jack_evmon — display client, port and graph events as they happen
 * jack_freewheel — testing tool to switch Jack into freewheeling mode
 * jack_latent_client — simple demo client, copying input to output
 * jack_load — example client, which loads the specified plugin and creates a client
 * jack_lsp — lists active ports
 * jack_metro — metronome
 * jack_midi_dump — listens for MIDI events on a JACK MIDI port
 * jack_midi_latency_test — measures MIDI latency and jitter
 * jack_midiseq — simple command-line MIDI sequencer
 * jack_midisine — generate sine waves
 * jack_monitor_client — monitors server inputs
 * jack_net_master — unknown
 * jack_net_slave — activate slave client
 * jack_rec — write audio from a Jack port to a file
 * jack_samplerate — prints current samplerate
 * jack_server_control — control a Jack server
 * jack_session_notify — unknown
 * jack_showtime — displays current timebase information
 * jack_simple_client — a very simple Jack client
 * jack_simple_session_client — very simple Jack clinet with session manager functions
 * jack_thru — copy input port to output port
 * jack_transport — provides control over the Jack transport system
 * jack_unload — unload a Jack client
 * jack_wait — check for Jack existence, or wait, until it either quits or gets started
 * jack_zombie — close down Jack server
 * jackd — Jack audio server daemon
* qjackctl — visual control utility for the Jack Audio Daemon
* libGLEW — the GNU OpenGL Extension Wrangler library
 * glewinfo — write OpenGL information to glewinfo.txt
 * visualinfo — comprehensively lists local machine's OpenGL capabilities
* libvpx — modern patent-free media encoding/decoding (picture, audio and more) from the WebM project
 * vpxdec — decodes moving pictures in VPn codecs including VP10
 * vpxenc — encodes moving pictures in VPn codecs including VP10
* libnettle — a low-level crypto library
 * nettle-hash — computes a file's hash using one of a group of selectable algorithms
 * nettle-lfib-stream — generates a pseudorandom stream, using the Knuth lfib (non-cryptographic) pseudorandom generator
 * nettle-pbkdf2 — PKCS #5 password-based key derivation function PBKDF2, see RFC 2898
 * pkcs1-conv — converts private and public RSA keys from PKCS #1 format to sexp format
 * sexp-conv — reads an s-expression on stdin, and outputs the same sexp on stdout, possibly with a different syntax
* libgpg-error — library that defines common error values for all GnuPG components
 * gbg-error — print all GnuPG error codes
* libsndfile — library handling and processing many types of sound files
 * sndfile-cmp — compares the PCM data of two sound files
 * sndfile-concat — concatenates audio data of incoming files. Output file has same format as first input. Channels must be identical
 * sndfile-convert — converts between many audio formats, mostly requiring no tuning settings
 * sndfile-deinterleave — splits a multichannel audio file into a group of mono files
 * sndfile-info — displays information about sound files, optionally including instruments and BWAV data
 * sndfile-interleave — merges two or more mono files into a multichannel audio file
 * sndfile-metadata-get — displays many kinds of metadata from audio files, including BWAV data
 * sndfile-metadata-set — sets many kinds of metadata in audio files, including BWAV data
 * sndfile-play — plays audio file readable by libsndfile
 * sndfile-regtest — requires libsqlite3, which we do not currently include
 * sndfile-resample — uses libsamplerate to resample files readable/writable by libsndfile. Many algorithms
 * sndfile-salvage — salvages audio data from conventional WAV files that are over 4GB in size, converts in W64 format
* LCMS — Little Colour Management System v. 2, a colour management library
 * psicc — generates ICC Postscript using colour management
 * tificc — applies a colour profile to TIFF files, with options to control CMYK printing
 * transicc — calculates conversions between colourspaces
 * jpcicc — applies a colour profile to JPEG files, with options to control CMYK printing
 * linkicc — links profiles into a single devicelink
* NetCDF —  library for creation, access, and sharing of array-oriented scientific data
 * ncgen — generates a program to create a NetCDF data set (older version)
 * ncgen3 — generates a program to create a NetCDF data set (newer version)
 * nccopy — copies and optionally compresses and chunks netCDF data
 * ncdump — converts netCDF data to human-readable form
* Glib — the GNU extension library
 * glib-compile-resources — compile a resource specification into a resource file
 * glib-compile-schemas — compile all GSettings schema files into a schema cache
 * glib-genmarshal — generates C code marshallers for callback functions of the GClosure mechanism in the GObject sublibrary of GLib
 * gobject-query — display a tree of types
 * gresource — list and extract resources that have been compiled into a resource file or included in an ELF binary
 * gsettings — configuration tool for GSettings
 * gspawn-win64-helper — assists spawning process. Not for user execution
 * gspawn-win64-helper-console — assists spawning process. Not for user execution
* AtomicParsley — the ultimate MP4 tagger
 * atomicparsley — very comprehensively manipulate tags on MP4 files
* libMXF and friends
  * avidmxfinfo — displays full details of an Avid Op-Atom MXF file
  * archive_mxf_info, unpicking OP1A MXF files (not Avid Op-Atom files)
  * bmxparse — return detailed internal information about certain media files
  * bmxtranswrap — rewrap from one MXF format to another, including broadcasters' shims
  * h264dump — analyse raw H.264 file (e.g. unwrapped with bmx2raw from OP1a MXF)
  * movdump — very detailed analysis of MP4 or QuickTime file
  * mxf2raw — unwrap MXF files
  * raw2bmx — industry standard wrapper for DPP and Avid MXF files, among others
  * writeavidmxf — obsolete utility that wraps video and audio data in an Avid Op-Atom MXF container
* gpac — MP4 manipulation utilities from GPAC
 * MP4Box — very comprehensive utility to wrap source files in MP4 container and tag in many ways
 * MP4Client — test MP4 player. Needs plugins (unfinished work)
 * MP42TS — repackage MP4 streams
* bs2b Bauer binaural processing
  * bs2bconvert — processes stereo files with Bauer binaural algorithms
  * b2sbstream — apply Bauer binaural algorithms to data stream STDIN->STDOUT
* libbz2
  * bunzip2 — uncompress files compressed with BZ2 algorithm
  * bzcat — uncompress files compressed with BZ2 algorithm to STDOUT
  * bzip2 — compress files with BZ2 algorithm
  * bzip2recover — attempt to repair a BZ2 compressed file
* libcaca — library to 'display' images on a text-only terminal
  * cacaclock — displays a clock. Font not found, at present
  * cacademo — shows some capabilities of libcaca on a standard text-only terminal
  * cacafire — simulates flames on a text terminal
  * cacaplay — replays libcaca animation files
  * cacaview — display BMP images on a text terminal
  * img2txt — convert a BMP image to text, with a choice of encoding
* libQT5
  * canbusutil — display data received via the CanBUS automotive protocol
  * qml — interprets/plays QML language
  * qmlscene — loads and displays QML documents even before the application is complete
  * qmltestrunner — runs tests in QML language programs
  * qtdiag — retrieve much information relating to QT5's interaction with a host
  * qtpaths — command line client to QStandardPaths
  * qtplugininfo — Qt5 plugin meta-data dumper
  * xmlpatterns — runs XQuery queries
  * xmlpatternsvalidator — validates XML patterns
* Tesseract — well-maintained optical character recognition (OCR) package
 * tesseract — command-line OCR
* libtermcap
  * captoinfo — translates termcap entries
  * clear — clears the terminal window or screen
  * infocmp — displays information about current terminal, or named terminal
  * infotocap — translates terminfo entry to termcap entry
  * tabs — displays or manipulates tab stops
* libcdio
  * audio — a simple command-line CD player (requires development)
  * cdchange — prompts user to change CD, then detects change
  * cd-drive — retrieves and displays information about CD drive(s)
  * cd-info — retrieves and displays information from inserted CD
  * cdio-eject — eject a CD
  * cd-paranoia — uses libparanoia to perform accurate reading of CD-DA
  * cd-read — performs raw block reading of a CD or file image
  * cdtext — read and display CDTEXT from inserted CD
  * device — read and display capabilities of CD drives
  * discid — calculate ID from inserted audio CD for CDDB enquiry
  * drives — query all drives capable of holding optical media
  * eject — ejects optical disc from given drive
  * extract — extract the full contents of either an UDF or ISO9660 image file.
  * isofile — test program to extract one file from an ISO9660 image
  * isofile2 — test program to extract a file from a CDRWIN cue/bin CD image
  * isofuzzy — test program to show fuzzy ISO-9660 detection/reading
  * iso-info — display information about an ISO9660 image file
  * isolist — show directories found in an ISO9660 image file
  * isolsn — get a file path for a given LSN of an ISO-9660 image
  * iso-read — extract a named file from an ISO9660 image
  * isorr — demo showing using libiso9660 how to see if a file has Rock-Ridge Extensions
  * logging — program showing how to set log verbosity
  * mmc1 — a demo program showing the 'INQUIRY' command given to an optical drive
  * mmc2 — MMC command to list CD and drive features from a SCSI-MMC GET_CONFIGURATION command
  * mmc2a — prints MMC MODE_SENSE page 2A parameters. Page 2a are the CD/DVD Capabilities and Mechanical Status
  * mmc3 — a further demo program
  * mmc-tool — issues libcdio multimedia commands
  * sample3 — discovers the type of CD inserted by using cdio_guess_cd_type()
  * sample4 — discovers the type of CD inserted by using cdio_guess_cd_type()
  * tracks — shows logical sector numbers for each track on an audio CD (CD-DA)
  * udf1 — demonstrates how to list files contained within a UDF image
  * udffile — simple program using libudf to extract a file within a UDF image
* libdvdread — library for reading DVDs
 * lsdvd — list contents of DVD, in detail
* lua — interpreted language
 * lua — lua language interpreter (version 5.2.3)
 * luac — lua language compiler (version 5.2.3)
* Mediainfo — library and utility for parsing many types of media files
 * mediainfo — command-line program for recognising and displaying data about many types of media files
 * mediainfo-gui — the GUI for Mediainfo. Temporarily lacks icons
* MLT — Multimedia Framework
 * melt — command-line interface to MLT libraries, plugins, filters, etc.
* GnuTLS
  * certtool — create, test and display certificates and their data
  * gnutls-cli — GnuTLS client shell
  * gnutls-cli-debug — sets up multiple TLS connections to a server to test and query its capabilities
  * gnutls-serv — server that listens to incoming TLS connections
  * ocsptool — parses and prints information about OCSP requests/responses, generates requests and verifies responses
  * pkstool — generates random keys for use with TLS-PSK.  The keys are stored in hexadecimal format in a key file
  * srptool — emulates the programs in the Stanford SRP (Secure Remote Password) libraries
* libjpeg
  * cjpeg — the original program to convert bitmaps to JPEG files
  * djpeg — the original program to convert JPEG files to bitmaps
  * jpegtrans — manipulate JPEG files without recoding
  * rdjpgcom — reads and displays comments found in JPEG files
  * wrjpgcom — writes and replaces comments into JPEG files
* libjpeg-turbo
 * tjbench — benchmark and test libjpeg-turbo
* OpenJPEG and OpenJPEG2 — create, decode and manipulate JPEG 2000 images
 * opj_compress — the standard JPEG 2000 compressor. Compresses with many options
 * opj_decompress — the standard JPEG 2000 decompressor. Decompresses to several formats
 * opj_dump — dumps JPEG 2000 datastream
* OpenCV — artificial intelligence applied to imaging
 * opencv_annotation — add annotations to images
 * opencv_createsamples — produces dataset of positive samples in a format that is supported by both opencv_haartraining and opencv_traincascade applications
 * opencv_traincascade — trains cascade classifier to produce data for identifying objects within images
* libcddb
  * cddb_query — retrieves CD data from server (crashes, cause unknown)
* libbluray
  * bd_info — displays information about a Blu-Ray disc
* libTIFF
  * bmp2tiff — converts and optionally compresses BMP to TIFF
  * fax2ps — converts TIFF fax image to Postscript
  * fax2tiff — converts raw fax data to TIFF
  * gif2tiff — converts GIF file to TIFF
  * pal2rgb — converts palletized TIFF file to full-colour RGB TIFF file
  * ppm2tiff — converts PPM file to TIFF file
  * ras2tiff — converts a file in the Sun rasterfile format to TIFF
  * raw2tiff — converts a raw byte sequence into TIFF
  * rgb2ycbcr — converts RGB TIFF into YCbCr TIFF using Rec.601 coefficients (hard-coded)
  * thumbnail — creates a TIFF file with embedded thumbnail image
  * tiff2bw — converts colour TIFF file to monochrome, with simple fixed coefficients
  * tiff2pdf — generates PDF equivalent of TIFF file including image conversion
  * tiff2ps — generates PostScript equivalent of TIFF file including image conversion
  * tiff2rgba — converts a TIFF file to RGBA colourspace
  * tiffcmp — compares image data of two TIFF files
  * tiffcp — combines and converts TIFF images. Image data is not altered, but its representation may be changed
  * tiffcrop — crops and optionally converts TIFF images
  * tiffdither — converts greyscale TIFF to bilevel with dithering
  * tiffdump — retrieve much information about TIFF files
  * tiffinfo — retrieve human-readable information about TIFF files
  * tiffmedian — applies the median cut transform to a TIFF file to generate a palletized image
  * tiffset — sets tags within TIFF files
  * tiffsplit — splits a multi-page or multi-image TIFF file into individual images
* librtmp — handlers for RTMP content
 * rtmpdump — dumps media content streamed over RTMP
 * rtmpgw — gateways between RTMP and HTTP
 * rtmpsrv — logs connect and play parameters from client that connects to it then invokes rtmpdump with those parameters to retrieve the stream
 * rtmpsuck — transparent proxy that tees data to a file while client also retrieves RTMP data
* poppler — library and utilities to manipulate, generate, read and convert PDF files
 * pdfdetach — lists and saves attachments found in PDF files
 * pdffonts — lists fonts found in PDF files
 * pdfimages — discovers images within PDF files and saves them
 * pdfinfo — prints information about PDF files
 * pdfseparate — splits multi-page PDF file into its constituent pages
 * pdftohtml — converts PDF files into HTML files, with many user-selectable options
 * pdftoppm — converts PDF files into PPM graphics files
 * pdftops — remakes PDF files as Postscript files
 * pdftotext — extracts text from PDF files, with control over layout and parsed areas
 * pdfunite — joins many PDF files into one
 * poppler-qt5viewer — displays PDF file in graphical window: a simple PDF reader program
* cuetools — manipulates CUE and BIN files associated with audio CD mastering or ripping
 * cueconvert — converts between CUE and TOC formats
 * cuebreakpoints —  prints the breakpoints from a CUE or TOC file
 * cueprint — prints disc and track information for a CUE or TOC file
 * cuetag — tags files based on CUE or TOC information
* libpcre — Perl-compatible regular expression library
 * pcregrep — grep using the PCRE regular expression library, compatible with the regular expressions of Perl 5
 * pcretest — performs tests upon regular expressions using the PCRE library
* Leptonica — image processing package
  * convertsegfilestopdf — converts all segmented image files in the given directory with matching substring to a mixed-raster pdf
  * convertsegfilestops — converts all segmented image files in the given directory with matching substring to a mixed-raster ps
  * converttopdf — converts all image files in the given directory with matching substring to a pdf
  * converttops — converts all image files in the given directory with matching substring to a ps
  * fileinfo — provide low-level input about image files, comparing data to header
  * printimage — converts image to PostScript, optionally sends to lpr-style printer. Very insecure program
  * printsplitimage — like printimage but splits image across any number of pages. Also insecure
  * printtiff — like printimage but handles vertical scaling of fax files correctly. Also insecure
  * splitimage2pdf — converts image to PDF, split across pages in two dimensions
  * xtractprotos — extracts prototypes from source files
* Youtube-DL — Python program for downloading media files from many websites including YouTube
 * youtube-dl — command-line interface for the above
* libcurl
  * curl — extremely versatile URL grabber
* libwebp — Google's static image format
  * cwebp — compress image to webp image
  * dwebp — decompress webp image
* libdcadec — DTS Coherent Acoustics decoding library
  * dcadec — decode DTS files and optionally provide information about them
* ICU — International Components for Unicode
  * derb — disassembles and saves resource bundle files
  * genbrk — reads in break interation rules text, and writes out the binary data
  * genccode — reads binary input files and creates a .c file with a byte array containing the input data
  * gencfu — reads in Unicode confusable character definitions and writes out the binary data
  * gencmn — takes a set of files and packages them as an ICU memory-mappable data file
  * gencnval — reads convrtrs.txt and creates icudt56l_cnvalias.icu
  * gendict — reads in a word list, and writes out a string trie dictionary
  * gennorm2 — reads input files with normalization data and creates a binary or .c file with the data
  * genrb — reads a list of resource bundle source files, and creates binary version of resource bundles
  * gensprep — reads specified files and creates a binary file with the StringPrep profile data
  * icuinfo — returns information on ICU implementation
  * icupkg — extracts and/or modifies ICU .dat archive
  * makeconv — reads .ucm codepage mapping files and writes .cnv file
  * pkgdata — produces packaged ICU data from the given list(s) of files
  * uconv — intelligently converts from one character set to another following ICU standards
* Mediainfo — libraries and executable to parse many types of media files
 * mediainfo — command-line media file parser
 * mediainfo-gui — GUI to mediainfo. Icons lacking at time of writing
* Get_Iplayer — package to download and save BBC iPlayer programmes, and hear live radio. Licence-fee payers may also watch live TV
 * get_iplayer.cmd — command-line launcher for get_iplayer
 * get_iplayer.pl — Perl program interacting with BBC iPlayer media servers
* gettext — tools providing a framework to help other GNU packages produce multi-lingual messages
 * envsubst — Substitutes the values of environment variables, copying STDIN->STDOUT
 * gettext — display native language translation of a textual message *
 * msgattrib — filters the messages of a translation catalog according to their attributes, and manipulates the attributes
 * msgcat — concatenates and merges specified PO files
 * msgcmp — compares two Uniforum style .po files to check that both contain the same set of msgid strings
 * msgcomm — finds messages that are common to two or more of the specified PO files
 * msgconv — converts a translation catalogue to a different character encoding
 * msgen — creates an English translation catalogue
 * msgexec — applies a command to all translations of a translation catalogue
 * msgfilter — applies a filter to all translations of a translation catalogue
 * msgfmt — generates binary message catalogue from textual translation description
 * msggrep — extracts all messages of a translation catalogue that match a given pattern or belong to some given source files
 * msginit — creates a new PO file, initializing the meta information with values from the user's environment
 * msgmerge — merges two Uniforum style .po files together
 * msgunfmt — convertsbinary message catalogue to Uniforum style .po file
 * msguniq — unifies duplicate translations in a translation catalogue
 * ngettext — displays native language translation of a textual message whose grammatical form depends on a number
 * recode-sr-latin — recodes Serbian text from Cyrillic to Latin script, STDIN->STDOUT
 * xgettext — extracts translatable strings from input files
* DJV — versatile and accurate professional image sequence decoder and viewer
  * djv_convert — batch processing and conversion of images and video files
  * djv_info — report basic information on all video and image files within a directory
  * djv_ls — directory listing
  * djv_view — versatile viewer for high-end video files or image sequences
  * djvGlslTest — test graphic manipulation capabilities
  * djvImagePlayTest — test rendering speed
  * djvImageViewTest — test rendering capability
  * djvTest
  * djvWidgetTest — test many different widget types
* GTK+-3 The GIMP Toolkit widget set, version 3
* doxygen — generate and update in-code documentation
* liba52 — decode and separate A52 audio (Dolby AC-3)
 * a52dec — decodes and outputs audio from AC-3 encoded streams
 * extract_a52 — demultiplexes AC-3 audio from transport stream
* librubberband — pitch and tempo shifting
 * rubberband — manipulates pitch and tempo of audio files. Inferior to facility in SoX
* libgcrypt
  * dumpsexp — debug tool for S-expressions
  * hmac256 — compute an HMAC-SHA-256 message authentication code
  * mpicalc — Reverse Polish Notation interactive big integer calculator
* wxWidgets — GUI library
 * wxrc — compiles binary resource files
* MPV — modern multimedia player using FFmpeg libav* foundation
 * mpv — player for multimedia files
* dvdauthor — very comprehensive toolkit for DVD authoring
 * dvdauthor — creates DVD file structure using source files controlled by XML
 * mpeg2desc — multiplex or demultiplex streams using MPEG2 containers
 * dvdunauthor — removes DVD file structure, deleting your work
 * dvdbackup — rip DVDs including CSS-protected discs
 * spumux — encodes subtitles and multiplexes them into an MPEG-2 program stream
 * spuunmux — demultiplexes subtitles from an existing MPEG-2 program stream
* exif — query and modify exif data within image files
* exiv2 — query exif data within image files, more fine-grained than exif
* fontconfig
  * fc-cache — build font information caches
  * fc-cat — read font information cache
  * fc-list — list fonts known to fontconfig
  * fc-match — list best font matching a given pattern
  * fc-pattern — list best font matching a given pattern
  * fc-query — query font file and return pattern
  * fc-scan — scan font files and directories, and print resulting pattern(s)
  * fc-validate — validate font files and print results
* libiconv — handle text encoding and conversions between encodings
 * iconv — convert text from one encoding to another encoding
* Gcal — the very flexible GNU calendar program
 * gcal — phenomenally powerful calendar printing and calculation program
* libFLAC
 * flac — very comprehensive FLAC encoder and decoder
 * metaflac — very comprehensive parser and editor for FLAC metadata
* MkvToolNix — libraries and utilities for examining and manipulating files in Matroska containers
 * mkvextract — extract files, tags, attachments and/or chapters from Matroska containers
 * mkvinfo — very detailed parser for Matroska containers
 * mkvmerge — create Matroska files with very fine-grained control
 * mkvpropedit — detailed control/listing of properties of Matroska file
 * mkvtoolnix-gui — Qt5 interface to perform many operations creating, parsing and editing Matroska files
* ncurses — library for control over many types of text terminal and virtual terminals
 * reset — attempts to reset a terminal to sensible defaults after a problem
 * tic — compiles or translates terminal information between termcap and terminfo
 * toe — creates table of entries of terminals known to local installation of ncurses
 * tput — initialize a terminal or query terminfo database
 * tset — reset a terminal
* libtwolame — library to encode MPEG Layer II audio (MP2)
 * twolame — encoder for MPEG Layer II audio (MP2)
* Vim — Vi Improved, a version of the venerable vi screen editing program
 * vim — the original editor running in a command shell window
 * gvim — Vim running in a Windows graphical window, with menus, etc.
* libXML2 — library for handling XML
 * xmlcatalog — parses the catalog file and queries it for the entities
 * xmllint — parses the XML files and returns the result(s) of the parsing
* libxslt — processor library for XML transformations
 * xsltproc — processes XML file with stylesheet


BINARY DISTRIBUTION
===================

I keep a binary installer on my website.
<a href="http://gallery.johnwarburton.net/MultimediaTools-mingw-w64-Open-source.exe">http://gallery.johnwarburton.net/MultimediaTools-mingw-w64-Open-source.exe</a>

Some of the binaries use shared libraries, ending in .dll. Like the executable programs, they're in the /bin/ directory of the distribution. Please keep them together with the .exe programs.


BACKGROUND
==========

Supporting the cross-compilation of the very versatile FFmpeg utilities under mingw-w64, Roger Pack with Zeranoe and others publish a set of patches and a build script to, first, compile a working mingw-w64 environment on a POSIX system, then compile a very full FFmpeg and associated libraries and utilities within mingw-w64 ready for installation on a Windows 64-bit system.

With grateful thanks to the Zeranoe and other developers especially Roger Pack, I have extended this build system for my own purposes. At first, this was developed using the Cygwin compatibility suite for Windows, but now it is developed on GNU/Linux.


THANKS
======

* Zeranoe and associated developers. http://zeranoe.com/
* Roger D Pack, https://github.com/rdp/ffmpeg-windows-build-helpers
* Carl, the creator and maintainer of DCP-o-Matic 
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

