# Makefile for myQwil

lib.name = myQwil

class.sources := $(patsubst %, %.c, \
muse chrd rand rind ntof fton flenc fldec slx sly same ceil delp linp linp~ \
radix 0x21 0x21~ x is has pak unpak 0x40pak 0x40unpak chrono tabread2~ tabosc2~)

datafiles := $(patsubst %, %-help.pd, \
muse chrd rand rind ntof flenc slope same ceil delp linp linp~ \
radix 0x21 0x21~ x is has pak rpak chrono tabread2~ tabosc2~ ad adsr cupq cupqb)

datafiles += $(patsubst %, %.pd, \
ad adsr add~ all~ ct cupq cupqb linp~ dollar-slice fkick~ \
hms lead0 mancalc mantissa mantr phi fmosc~ fmore~ zp zp~)

suppress-wunused = yes
warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing

include pd-lib-builder/Makefile.pdlibbuilder
