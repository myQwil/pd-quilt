# Makefile for myQwil

  lib.name = myQwil

  class.sources = muse.c chrd.c rand.c rind.c ntof.c fton.c sploat.c gloat.c \
	logb.c graid.c same.c ceil.c radx.c !.c !~.c 0x5e.c gme~.c nsf~.c

  datafiles = !~-help.pd !-help.pd ^-help.pd 2^.pd ad.pd ad~.pd adac~.pd \
	ceil-help.pd cpt.pd cupq.pd cupqb.pd cupqbl.pd fkick~.pd fmbloc~.pd \
	freqm~.pd graid-help.pd chrd-help.pd logb-help.pd manscratch.pd \
	mantissa.pd mantissal.pd mantouch.pd mantr.pd mix~.pd muse-help.pd \
	ntof-help.pd pad.pd pad~.pd radx-help.pd rand-help.pd rind-help.pd \
	same-help.pd sploat-help.pd README.md LICENSE.md

  include Makefile.pdlibbuilder
