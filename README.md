# pd-externals
Externals I've made for pure data:

## [ntof $1 $2] & [fton $1 $2]
Similar to pd's `[mtof]` and `[ftom]` with the added ability to change the reference pitch(`$1`) and the # of tones in equal temperament(`$2`).

## [sploat $1] & [gloat $1 $2 $3]
`[sploat]` Splits a float(`$1`) into its sign, exponent, and mantissa.  
`[gloat]` Joins the mantissa(`$1`), exponent(`$2`), and sign(`$3`) to create a new float.

## [graid $1 $2 $3]
Creates `$3` number of steps between min and max values `$1` and `$2`.  
It's essentially `[expr $f1 / ($f4 / ($f3 - $f2)) + $f2]`

## [muse $...] & [chrd $...]
`[muse]` Creates a monophonic musical scale and uses various messages to quickly change the structure of the scale  
`[chrd]` The chord equivalent of `[muse]` that produces multiple outlets based on the number of creation arguments specified

## [radx $1]
A number base converter. Outputs the result in the form of a symbol.  
`$1` can be any value between 2 and 32.

## [rand $1 $2 $..]
A random number generator that seeds with the current time so that the seed is always different even after restarting pd.  
Accepts 2 arguments for a min and max value, or more than 2 arguments to create a list of numbers.

## [rind $1 $2]
A high-precision random number generator. Allows for a max value, or min and max values to be specified.

## [same]
Similar to `[change]` except that it outputs duplicate values to a second outlet.
