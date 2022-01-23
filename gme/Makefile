# Makefile for gmepd

lib.name = gmepd

# MSYS2 wants to work with .cpp files
class.sources = gme~.cpp gmes~.cpp

datafiles = gme-mask.pd gme~-help.pd gmes~-help.pd

suppress-wunused = yes
warn.flags = -Wall -Winline -Wstrict-aliasing -Wno-int-to-pointer-cast -Wno-narrowing

cflags = -I"game-music-emu/gme"

ldlibs = game-music-emu/build/gme/libgme.a
# ifeq ($(MAKECMDGOALS), alldebug)
#   build-folder := build
# else
#   build-folder := build-release
# endif
# ldlibs = game-music-emu/$(build-folder)/gme/libgme.a

ldlibs += -lz -lunrar -lsamplerate

# Windows/MSYS2 users will probably need to manually build libunrar.a
define forWindows
  ldlibs := -Wl,-Bstatic $(ldlibs)
endef

include ../pd-lib-builder/Makefile.pdlibbuilder
