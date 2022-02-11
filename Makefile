# Makefile for xtra

# PDLIBDIR = $(HOME)/.local/lib/pd/extra
PDLIBDIR = .

lib.name = xtra

class.sources = $(patsubst %, src/%.c, \
0x40pak 0x40unpak blunt chrd chrono delp ffplay~ fldec flenc fton has is \
linp linp~ muse ntof pak radix rand rind same slx sly tabosc2~ tabread2~ unpak)
class.sources += $(patsubst %, src/%.cpp, gme~ gmes~)

datafiles = $(patsubst %, abstractions/%.pd, \
ad add~ adsr all~ ct cupq cupqb fkick~ fmore~ fmosc~ \
gme-mask hms lead0 mant-calc mantissa phi pulse~ zp zp~)

datafiles += $(patsubst %, help/%-help.pd, \
adsr chrd chrono cupq cupqb delp ffplay~ flenc gme~ gmes~ has is linp linp~ \
muse pak radix rand rind rpak same slope tabosc2~ tabread2~ tone)

datafiles += help/libgme-LICENSE.txt

# Blunt
blunt.class.sources = $(patsubst %, src/%.c, hotop revop)
datadirs = blunt

# Game Music Emu
cflags = -I"game-music-emu/gme"
gme~.class.ldlibs  = game-music-emu/build/gme/libgme.so -lsamplerate -lz -lunrar
gmes~.class.ldlibs = $(gme~.class.ldlibs)
define forWindows
  gme~.class.ldlibs  := -Wl,-Bstatic $(gme~.class.ldlibs)
endef

# FFplay
ffplay~.class.ldlibs = -lsamplerate -lavutil -lavcodec -lavformat -lswresample

suppress-wunused = yes
warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing

include pd-lib-builder/Makefile.pdlibbuilder
