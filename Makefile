# Makefile for quilt

# PDLIBDIR = $(HOME)/.local/lib/pd/extra
PDLIBDIR = .

lib.name = quilt

class.sources = $(patsubst %, src/%.c, \
0x40pak 0x40unpak blunt chrd chrono delp ffplay~ fldec flenc fton gme~ gmes~ has is \
linp linp~ muse ntof pak radix rand rind same slx sly tabosc2~ tabread2~ unpak)

datafiles = $(patsubst %, abstractions/%.pd, \
ad add~ adsr all~ avg ct cupq cupqb fkick~ fmore~ fmosc~ gauge \
gme-mask hms lead0 mant-calc mantissa phi pulse~ tick zp zp~)

datafiles += $(patsubst %, help/%-help.pd, \
adsr chrd chrono cupq cupqb delp ffplay~ flenc gme~ gmes~ has is linp linp~ \
muse pak radix rand rind rpak same slope tabosc2~ tabread2~ tone)

datafiles += help/LICENSE-libgme.txt help/README.md

datadirs = blunt

# Game Music Emu
# for Windows/MSYS2, a manual build of libunrar is required
EXT = so
cflags = -I./game-music-emu/gme
gme~.class.ldlibs  = game-music-emu/build/gme/libgme.$(EXT) -lsamplerate -lz -lunrar
gmes~.class.ldlibs = $(gme~.class.ldlibs)
define forDarwin
  cflags += -I/usr/local/opt/ffmpeg@4/include
  ldflags = -L/usr/local/opt/ffmpeg@4/lib -L/opt/local/lib
  EXT = dylib
endef
define forWindows
  EXT = dll
endef

# FFplay
ffplay~.class.ldlibs = -lsamplerate -lavutil -lavcodec -lavformat -lswresample

suppress-wunused = yes
warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing

include pd-lib-builder/Makefile.pdlibbuilder
