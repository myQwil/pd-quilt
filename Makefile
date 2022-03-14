# Makefile for quilt

# PDLIBDIR = $(HOME)/.local/lib/pd/extra
PDLIBDIR = .

lib.name = quilt

class.sources = $(shell echo src/*.c)

datafiles  = $(shell echo abstractions/*.pd)
datafiles += $(shell echo help/*.pd)
datafiles += help/LICENSE-libgme.txt help/README.md
datadirs   = blunt

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
