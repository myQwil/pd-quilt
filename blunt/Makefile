# Makefile for blunt

  lib.name = blunt

  class.sources = revop.c hotop.c

  make-lib-executable = yes
  lib.setup.sources = blunt.c

  datafiles = hotbinops1-help.pd hotbinops2-help.pd hotbinops3-help.pd \
	revbinops-help.pd 0x5e-help.pd

  suppress-wunused = yes
  warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing
  #optimization.flags = -O0 -ffast-math -funroll-loops -fomit-frame-pointer

  include ../pd-lib-builder/Makefile.pdlibbuilder
