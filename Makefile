# Makefile for myQwil

lib.name = myQwil

class.sources := $(patsubst %, %.c, \
muse chrd rand rind ntof fton sploat gloat slx sly same ceil radix \
0x21 0x21~ x is pak unpak 0x40pak 0x40unpak stopwatch tabread2~ tabosc2~)

datafiles := $(patsubst %, %-help.pd, \
muse chrd rand rind ntof sploat slope same ceil radix 0x21 0x21~ x is pak rpak \
stopwatch adsr cupq cupqb delp linp linp~)

datafiles += $(patsubst %, %.pd, \
2^ ad adsr add~ all~ bt ct cupq cupqb delp linp linp~ dollar-slice fkick~ \
hms lead0 mancalc mantissa mantissal mantr phi fmosc~ zp zp~)

suppress-wunused = yes
warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing

include pd-lib-builder/Makefile.pdlibbuilder
