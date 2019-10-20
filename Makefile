# Makefile for myQwil

  lib.name = myQwil

  class.sources = \
	muse.c chrd.c rand.c rind.c ntof.c fton.c sploat.c gloat.c \
	grdnt.c same.c ceil.c radix.c !.c !~.c gme~.cpp gmes~.cpp \
	x.c is.c pak.c unpak.c 0x40pak.c 0x40unpak.c

  datafiles = !-help.pd !~-help.pd 2^.pd ad.pd ad~.pd adac~.pd same-help.pd \
	bt.pd ct.pd cupq.pd cupq-help.pd cupqb.pd cupqb-help.pd fmod~.pd fmad~.pd \
	muse-help.pd chrd-help.pd ceil-help.pd logb-help.pd phi.pd tie.pd mix~.pd \
	mantissa.pd mantissal.pd mantouch.pd manscratch.pd mantr.pd gme-mask.pd \
	ntof-help.pd zp.pd zp~.pd radix-help.pd rand-help.pd rind-help.pd \
	sploat-help.pd is-help.pd pak-help.pd rpak-help.pd gme~-help.pd \
	x-help.pd adsr.pd adsr-help.pd fkick~.pd grdnt-help.pd \
	dep.pd dep-help.pd linp.pd linp-help.pd linp~.pd linp~-help.pd \
	README.md LICENSE.md

  suppress-wunused = yes
  warn.flags = -Wall -Wshadow -Winline -Wstrict-aliasing
  #optimization.flags = -O0 -ffast-math -funroll-loops -fomit-frame-pointer

  include pd-lib-builder/Makefile.pdlibbuilder
