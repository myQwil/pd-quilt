# Makefile for quilt

# PDLIBDIR = $(HOME)/.local/lib/pd/extra
PDLIBDIR = .

lib.name = quilt

cflags = -DBLUNT=1 \
-DDATE=\"$(shell date -u +%F)\" \
-DTIME=\"$(shell date -u +%T)\"

class.sources = $(wildcard $(shell pwd)/src/*.c)

datafiles  = $(wildcard abstractions/*.pd) $(wildcard help/*.pd)
datafiles += help/libgme-LICENSE.txt help/README.md
datadirs   = blunt

# Game Music Emu
EXT = so
cflags += -I./game-music-emu/gme
gme~.class.ldlibs  = game-music-emu/build/gme/libgme.$(EXT) -lsamplerate -lz -lunrar
gmes~.class.ldlibs = $(gme~.class.ldlibs)
define forDarwin
  ldflags = -L/opt/local/lib
  EXT = dylib
endef
define forWindows
  EXT = dll
endef

# FFplay
ffplay~.class.ldlibs = -lsamplerate -lavutil -lavcodec -lavformat -lswresample

warn.flags = -Wall -Wextra -Wshadow -Winline -Wstrict-aliasing -Wno-cast-function-type

include pd-lib-builder/Makefile.pdlibbuilder
