# Makefile for gmepd

  lib.name = gmepd

  class.sources = gme~.cpp gmes~.cpp

  datafiles = gme-mask.pd gme~-help.pd gmes~-help.pd

  suppress-wunused = yes
  warn.flags = -Wall -Winline -Wstrict-aliasing -Wno-int-to-pointer-cast

  cflags = -I"game-music-emu/gme"
  ldlibs = game-music-emu/build/gme/libgme.a

  define forWindows
    ldlibs += -Wl,-Bstatic -lz -lunrar
  endef

  define forLinux
    ldlibs += -lz -lunrar
  endef

  define forDarwin
    ldlibs += -lz -lunrar
  endef

  include ../pd-lib-builder/Makefile.pdlibbuilder
