# Makefile for gmepd

  lib.name = gmepd

  class.sources = gme~.c gmes~.c

  datafiles = gme-mask.pd gme~-help.pd gmes~-help.pd

  suppress-wunused = yes
  warn.flags = -Wall -Winline -Wstrict-aliasing -Wno-int-to-pointer-cast

  cflags = -I"game-music-emu/gme"
  ldlibs = game-music-emu/build/gme/libgme.a -lz -lunrar

  include ../pd-lib-builder/Makefile.pdlibbuilder
