# Makefile for blunt

lib.name = blunt

class.sources = hotop.c revop.c

make-lib-executable = yes
lib.setup.sources = blunt.c

datafiles := $(patsubst %, hotbinops%-help.pd, 1 2 3) \
revbinops-help.pd 0x5e-help.pd

suppress-wunused = yes
warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing

include ../pd-lib-builder/Makefile.pdlibbuilder
