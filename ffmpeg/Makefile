# Makefile for ffmpeg

lib.name = ffmpeg

class.sources = ffplay~.c

datafiles = ffplay~-help.pd

suppress-wunused = yes
warn.flags = -Wall -Winline -Wstrict-aliasing -Wshadow

ldlibs = -lavutil -lavcodec -lavformat -lswresample -l:libsamplerate.a

include ../pd-lib-builder/Makefile.pdlibbuilder
