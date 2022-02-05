# PdXtra
## A collection of pure data externals
Additional README files are included in sub-folders.

--------------------------------------------------

## \[ **ntof** ] & \[ **fton** ]

Similar to pd's \[ **mtof** ] and \[ **ftom** ] objects but with modifiable reference pitch and number of tones in equal temperament.

### Creation args

1. float - Reference pitch

2. float - Number of tones in equal temperament

### Inlets

1. float
	- \[ **ntof** ] - MIDI note
	- \[ **fton** ] - frequency

2. float - Reference pitch

3. float - Number of tones in equal temperament

### Outlets

1. float
	- \[ **ntof** ] - frequency
	- \[ **fton** ] - MIDI note

### Messages

- \[ **ref** \$1 ( - Set the reference pitch.

- \[ **tet** \$1 ( - Set the number of tones.

- \[ **set** \$1 \$2 ( - Set the reference pitch and number of tones respectively.
	- A numeric list also does this.

--------------------------------------------------

## \[ **muse** ] & \[ **chrd** ]

\[ **muse** ] - Creates a musical scale and uses various messages to quickly change the structure of the scale.

\[ **chrd** ] - The chord equivalent of \[ **muse** ] that produces multiple outlets based on the number of creation arguments specified.

### Creation args

1. numeric list
	- The first arg acts as the root note.

	- All args that follow act as intervals relative to the root note.

	- The calculation for determining notes is essentially:
	```c
	root_note + interval + octave * (interval / scale_size)
	```

### Inlets

1. float - A scale index
	- Indexes smaller or larger than the scale's size will rotate to lower or higher octaves.

	list - To reassign the root + intervals with
	- The size of the scale will also be changed based on the size of the list, unless strict mode is turned on.

- The inlets that follow will match the number of creation args and be associated with a specific interval or root.

### Outlets for \[ **muse** ]

1. float - The frequency of the scale index

2. float - The midi note of the scale index

### Outlets for \[ **chrd** ]

- The frequencies or midi notes of the creation args.
	- Outputs frequencies by default, but this can be changed to midi notes by sending the message \[ midi 1 (.

### Messages

- \[ **print** \$1 ( - Print the current state of the scale.
	- A label is optional to help determine where the print request came from.

- \[ **size** \$1 ( - Set the size of the scale.
	- When the requested size is bigger than the array's allocated size, the array will be resized and the inlets' float slots will be re-associated with the new addresses.
		- Arrays have a resizing cap of 1024 floats.

- \[ **ref** \$1 ( - Set the reference pitch.

- \[ **tet** \$1 ( - Set the number of tones per octave.

- \[ **oct** \$1 ( - Set the number of semitone steps per octave.

- \[ **ot** \$1 ( - oct and tet combined. Assigns them to the same value.

- \[ **strict** \$1 ( - Set strict mode to on ( 1 ) or off ( 0 ) with off as the default.

- \[ **slice** \$1 \$2 \$3 ( - Send a slice of the scale through the second outlet.
	- Based on Python's slice notation, with the args being start index, stop index, and step amount, respectively.

- \[ **send** \$.. ( - Send an alteration of the scale through the second inlet without actually changing the internal scale.
	- No args sends the unaltered scale.

- \[ **@\$1** \$.. ( - Reassign with a list, starting from a given index ( $1 ).
	- If no index is specified, the offset will default to zero.

	- Adheres to strict mode.

- \[ **!\$1** \$.. ( - Lazy reassignment that ignores strict mode.

- \[ **#\$1** \$.. ( - Strict reassignment that ignores strict mode.
	- This is also useful for changing the root note with \[ **#** $1 (

### Float Notation

- Non-whole numbers will return a note between two intervals.

- A float followed by an operator and another float (without spaces between them), Ex: \[ **1+2** (, will interpret the 1st float as the scale index, and the 2nd float as a last-minute adjustment to the value at that index in semitones.
	- This will not reassign the value at that index.

	- The example given would return the 1st interval, raised by 2 semitones.

### List Notation

- Non-numeric args will be skipped.

- An operator (`+`, `-`, `*`, `/`) followed by a number will perform this operation on the current value at a given index.
	- the operator just on its own will default to calculating with 1 .

- An operator repeated (`--`, `++`, `**`, `//`) will perform the same operation for every index that follows.
	- A number before the operator acts as an iterator, such that the operation will only be performed for that many intervals. This may also implicitly change the scale size if strict mode is off, or if the list itself is not strict.

	- A number after the operator acts as the amount. If none is specified, the operator will default to calculating with 1.

	- Example: \[ **foo** 2++4 ( skips the root note and raises the first 2 intervals by 4 semitones.

	- If the iterator is negative, the size of the scale is added to it to make it work in reverse.

- `<`, `>`, `<<`, `>>` are inversion operators.
	- Similar to the double operators, a number before them specifies the iterator, and a number after them specifies the amount.

	- `<` and `>` will invert the scale without moving the root note (or whichever note is at its starting point).
		- Ex: \[ **>** ( sent to a major scale would change it to Dorian mode, while \[ **>2** ( would change it to Phrygian mode.

- An ampersand followed by a number is a reference to the note at that index.
	- Example: \[ **#1** &2 &1 ( would swap the 1st and 2nd intervals.

--------------------------------------------------

## \[ **rand** ]

A random number generator that seeds with the current time so that the seed is always different even after restarting pd.

### Creation Args

For 1 arg:
1. float - Max

For 2 or no args:
1. float - Min

2. float - Max

- More accurately, these are start and stop values. This means that the difference between `max` and `min` will always equal the correct range.
	- We can also allow non-whole numbers to make fringe values less likely to occur.

	- Example: \[ **rand** 2.8 5.2 ] will mostly output 3's and 4's, but there will also be the occasional 2's and 5's.

For 3 or more args:

1. numeric list
	- The random number's range will be the size of the list and the result will be used as an index to output one of the list's items.
	- You can also make a small list using a `f-s-f` pattern of args. Example: \[ **rand** 2 or 5 ] will output either 2 or 5 .

### Inlets

1. bang - Trigger a new random number

- The inlets that follow will reflect the creation args.

### Outlets

1. float - Random number

### Messages

- \[ **seed** \$1 ( - Set the state with a new seed.
	- If no args are given, the state will be determined by the current time.

- \[ **state** \$1 ( - Print the current state.
	- A label is optional to help determine where it came from.

- \[ **nop** \$1 ( - Turn on/off No-Repeat mode.
	- Prevents repeat values by decreasing the range by 1 and starting from the previous value, plus 1.

	- nop's value is also interpreted as the maximum number of times a number can occur in a row.

- \[ **mode** \$1 ( - Force list mode or range mode.
	- Range mode - The first two numbers are treated like min/max values and range is determined by their difference.

	- List mode - The range is derived from the size of the list and the result will be used as an index to output one of the list's items.

- \[ **size** \$1 ( - Set the size of the float list.
	- When the requested size is bigger than the array's allocated size, the array will be resized and the inlets' float slots will be re-associated with the new addresses.
		- Arrays have a resizing cap of 1024 floats.

--------------------------------------------------

## \[ **rind** ]

A high-precision random number generator. Allows for a max value, or min and max values to be specified.

### Creation Args

For 1 arg:
1. float - Max

For 2 or no args:
1. float - Min

2. float - Max
### Inlets

1. bang - Trigger a new random number

- The inlets that follow will reflect the creation args.

### Outlets

1. float - Random number

### Messages

- \[ **seed** \$1 ( - Set the state with a new seed.
	- If no args are given, the state will be determined by the current time.

- \[ **state** \$1 ( - Print the current state.
	- A label is optional to help determine where it came from.

--------------------------------------------------

## \[ **flenc** ] & \[ **fldec** ]

float-encode & float-decode

\[ **flenc** ] - Joins the mantissa, exponent, and sign to create a new float.

\[ **fldec** ] - Splits a float into its sign, exponent, and mantissa.

### Inlets & Creation args for \[ **flenc** ]

1. float - Mantissa

2. float - Exponent

3. float - Sign

### Inlets & Creation args for \[ **fldec** ]

1. float - The float to be split

### Outlets

The oulets of these externals are the same as the inlets of the other.

### Messages

- \[ **m** \$1 ( - Set the mantissa.

- \[ **e** \$1 ( - Set the exponent.

- \[ **s** \$1 ( - Set the sign.

- \[ **f** \$1 ( - Set the float.

- \[ **u** \$1 ( - Set an unsigned int whose bits are unified with that of the float's.

--------------------------------------------------

## \[ **radix** ]

A gui number box that uses a custom number base between 2 and 64.

### Creation Args

1. float - Radix

2. float - Precision level

3. float - E-notation radix
	- By default. it's the same as the main radix.

### Inlets

1. float

### Outlets

1. float

- Works exactly the same as any number box. The main difference is how the number is displayed

### Messages

- \[ **base** \$1 ( - Set the radix.

- \[ **e** \$1 ( - Set the e-notation radix.

- \[ **be** \$1 ( - Set the radix and e-notation radix simultaneously.

- \[ **p** \$1 ( - Set the precision level.

- \[ **fs** \$1 ( - Set the font size.

- \[ **fw** \$1 ( - Set the font width.
	- More accurately, the width that the border _thinks_ the font is so that it resizes accordingly.

--------------------------------------------------

## \[ **slx** ] & \[ **sly** ]

Slope objects.

These can be thought of as sliders without the gui interface. They use the line equation in slope-intercept form with either a linear or logarithmic method.

\[ **sly** ] - Solves for y ( y = mx + b )

\[ **slx** ] - Solves for x ( x = (y-b) / m ).

Only, for these objects, we use a slightly altered equation with min and max values:
```
m = (max - min) / run
y = m * x + min
x = (y - min) / m
```

### Creation Args

1. float - Min

2. float - Max

3. float - Run

### Inlets

1. float
	- \[ **sly** ] receives x 
	- \[ **slx** ] receives y 

- The inlets that follow are the same as the creation args.

### Outlets

1. float
	- \[ **sly** ] outputs the solution for y 
	- \[ **slx** ] outputs the solution for x 

### Messages

- \[ **min** \$1 ( - Set the min.

- \[ **max** \$1 ( - Set the max.

- \[ **run** \$1 ( - Set the run.

- \[ **log** \$1 ( - Set whether to use the logarithmic method.
	- With this method, the equation looks like this:
	```
	m = log(max / min) / run
	y = exp(m * x) * min
	x = log(y / min) / m
	```

--------------------------------------------------

## \[ **is** ]

Checks an atom's type or message.

### Creation Args

1. symbol - The type or message to check for.
	- 'b', 'f', 's', 'l', and 'p' can be used as shorthand for 'bang', 'float', 'symbol', 'list', and 'pointer' respectively.

### Inlets

1. atom - The atom whose type will be checked

2. atom - The type to check for
	- Will accept either a message or an atom of the type.

### Outlets

1. float - 1 for true or 0 for false

### Messages

- \[ **set** \$1 ( - Set the type to check for.

--------------------------------------------------

## \[ **has** ]

Checks if a list contains a specific atom value.

### Creation Args

1. atom - The atom to check for

### Inlets

1. list - The list whose contents will be checked

2. atom - The atom to check for

### Outlets

1. float - 1 for true or 0 for false

### Messages

- \[ **set** \$1 ( - Set the atom to check for.

--------------------------------------------------

## \[ **pak** ] & \[ **unpak** ]

Similar to pd's \[ **pack** ] and \[ **unpack** ] objects but with special 'lazy' inlets/outlets that allow anything to pass through them.

### Inlets/Outlets & Creation args

- As with pack/unpack, creation args will determine how many inlets or outlets there are.

- 'f', 's', or 'p' will create strict type-checking inlets/outlets of float, symbol, or pointer types respectively.

- 'a' or a number creates a lazy type.

- 'b' turns into a lazy 'bang'.

- Unrecognized symbols become lazy types with the symbol as the initial value.

### Messages

- \[ **.** \$1 ( - Skip an inlet.
	- Multiple dots (with spaces between them) will skip multiple inlets.

	- This works for any inlet. The inlet it gets sent to will act as an offset for the inlets that follow.

- \[ **mute** \$1 ( - Set the error-muting bit-mask.
	- A bit mask of 0 will unmute all inlets/outlets, while a bit mask of -1 will mute all of them.

--------------------------------------------------

## \[ **tabread2\~** ] & \[ **tabosc2\~** ]

Table reader/oscillator that uses linear interpolation

Much like \[ **tabread4\~** ] and \[ **tabosc4\~** ], these objects work best with tables whose size is a power of 2, plus three. Linear interpolation really only requires 1 additional point, such that the first and last points are the same value, but for the sake of compatibility, the wave starts at index 1, while index 0 is just ignored. Pd's 4-point interpolation has 1 look-behind point and expects the beginning of the wave to be at index 1. Messages like sinesum and cosinesum generate arrays with this in mind.

### Creation Args

1. symbol - Table name

2. float - Threshold
	- The percentage of each point that should remain as the original value.
	
	- If the threshold is 0.9, that means that only the last 10% of the point will be dedicated to interpolation.

### Inlets

1. signal - Frequency

2. signal - Threshold

3. float
	- \[ **tabread2\~** ] - Onset
		- You can use this to improve the accuracy of indexing into the array.
	- \[ **tabosc2\~** ] - Phase Index

### Outlets

1. signal - Interpolated table

### Messages

- \[ **set** \$1 ( - Set the table name.

[ **tabosc2\~** ] :

- \[ **ft1** \$1 ( - Set the phase index.

--------------------------------------------------

## \[ **chrono** ]

A timer object with pause and lap functions.

### Creation Args

1. float - Tempo unit

2. symbol - Tempo unit name

- These args can be written in any order.

### Inlets

1. bang - Resets the timer

	float - Resets the timer with an initial delay

2. bang - Output elapsed time

### Outlets

1. float - Elapsed time

2. list - Lap info

3. float - Pause state
	- 0 for paused, 1 for unpaused

### Messages

- \[ **pause** ( - Pause/resume the timer.

- \[ **lap** ( - Send the lap time and total time as a list through the 2nd outlet.

- \[ **delay** $1 ( - Add delay.
	- If more delay is added than time has elapsed since the last reset, the timer will begin counting down to zero.

--------------------------------------------------

## \[ **delp** ]

A delay object with a pause function.

### Creation Args

1. float - Delay time

1. float - Tempo unit

2. symbol - Tempo unit name

- The last two args can be written in any order.

### Inlets

1. bang - Resets delay

	float - Sets the delay and starts

2. float - Sets the delay but doesn't start

### Outlets

1. bang - Sent after delay period has ended

2. float - Remaining time

3. float - Pause state
	- 0 for paused, 1 for unpaused

### Messages

- \[ **pause** ( - Pause/resume the delay.

- \[ **time** ( - Output remaining time.

- \[ **delay** $1 ( - Add delay.
	- If the delay has already ended, this will not re-activate it.

--------------------------------------------------

## \[ **linp** ] & \[ **linp\~** ]

\[ **line** ] and \[ **line\~** ] objects with a pause function.

### Creation Args for [ **linp** ]

1. float - Initial value

2. float - Time grain in milliseconds

### Inlets

- Exactly the same as \[ **line** ] and \[ **line\~** ]

### Outlets

1. The ramp value

2. float - Pause state
	- 0 for paused, 1 for unpaused

### Messages

- \[ **pause** ( - Pause/resume the delay.
