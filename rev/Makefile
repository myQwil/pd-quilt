# Makefile for revbinops

  lib.name = revbinops

# @- @/ @<< @>> @%

  class.sources = \
	0x400x2d.c 0x400x2f.c 0x400x3c0x3c.c 0x400x3e0x3e.c 0x400x25.c \
	0x40div.c 0x40mod.c 0x40pow.c 0x40pak.c 0x40unpak.c

  datafiles = revbinops-help.pd rpak-help.pd

  suppress-wunused = 'yes'
  warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing
  #optimization.flags = -O0 -ffast-math -funroll-loops -fomit-frame-pointer

  include ../pd-lib-builder/Makefile.pdlibbuilder
