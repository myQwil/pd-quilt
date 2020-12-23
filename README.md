# pdxtra
Externals I've made for pure data:

## [gme~ $..] & [gmes~ $..]
A Pd interface for the Game Music Emu library, created by Shay Green and maintained by Michael Pyne at https://bitbucket.org/mpyne/game-music-emu
This repository includes a fork of the library as a submodule.
Compatible formats include: AY, GBS, GYM, HES, KSS, NSF/NSFE, SAP, SPC, VGM/VGZ
If numbers are provided as creation args, the channels pertaining to the numbers will be the only channels that play, while the rest will be muted.
Some formats work with gmes~ , the multi-channel version of gme~ .
To build these externals, simply include libgme.so/dll/dylib in the linking phase of building.
By default, the library will build and link statically. If you have ubsan enabled, be sure to add `-lubsan` to the linking phase.

## [pak $..] & [unpak $..]
A lazy version of pack/unpack objects with anything inlets/outlets. While these objects allow for strict type checking as with pack/unpack, by default, they aim to allow for any atom type to pass through, and they refrain from printing out error messages even when the the strict type checker receives an incorrect atom type.

## [ntof $1 $2] & [fton $1 $2]
Similar to pd's `[mtof]` and `[ftom]` with the added ability to change the reference pitch(`$1`) and the # of tones in equal temperament(`$2`).

## [sploat $1] & [gloat $1 $2 $3]
`[sploat]` Splits a float(`$1`) into its sign, exponent, and mantissa.
`[gloat]` Joins the mantissa(`$1`), exponent(`$2`), and sign(`$3`) to create a new float.

## [muse $..] & [chrd $..]
`[muse]` Creates a musical scale and uses various messages to quickly change the structure of the scale
`[chrd]` The chord equivalent of `[muse]` that produces multiple outlets based on the number of creation arguments specified

## [radix $1]
A gui number box that uses a custom number base between 2 and 64.

## [rand $1 $2 $..]
A random number generator that seeds with the current time so that the seed is always different even after restarting pd.
Accepts 2 arguments for a min and max value, or more than 2 arguments to create a list of numbers.

## [rind $1 $2]
A high-precision random number generator. Allows for a max value, or min and max values to be specified.

## [slx $1 $2 $3] & [sly $1 $2 $3]
Line equation in slope-intercept form.
sly solves for y (y = mx + b) while slx solves for x (x = (y-b) / m).
The slope can be either linear or logarithmic.

## [same]
Similar to `[change]` except that it outputs duplicate values to a second outlet.
