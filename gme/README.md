## \[ **gme\~** ] & \[ **gmes\~** ]

A Pd interface for the Game Music Emu library, created by Shay Green and maintained by Michael Pyne at https://bitbucket.org/mpyne/game-music-emu

This repository includes a fork of the library as a submodule.

Compatible formats include: AY, GBS, GYM, HES, KSS, NSF/NSFE, SAP, SPC, VGM/VGZ

\[ **gmes\~** ] - The multi-channel version of \[ **gme\~** ]. Not all formats will work properly with this external.

### Creation args

1. numeric list
	- Solo channels. If no args are given, all channels will be unmuted.

### Inlets

1. bang - Play/pause the currently loaded track.
	- Sends a 1 or 0 through the last outlet to indicate whether it's playing or paused.

	float - (Re)start playback of a given track number
	- Zero will stop playback.

- A file must be successfully opened for either of these to work

### Outlets

1. signal - Left channel

2. signal - Right channel

3. list - Outputs various messages including information regarding whether a file was successfully opened, whether a track is currently playing, track metadata, etc.

\[ **gmes\~** ] works with 16 signal outlets, one left and one right channel for 8 distinct voices.

### Messages

- \[ **info** \$.. ( - Prints metadata info.
	- If no args given, it will print general info. Otherwise, it will print custom info.

	- metadata needs to be surrounded with percent signs.
		- Example \[ **info** %game% - %song% (

	- Acceptable metadata terms include:
		- system, game, song, author, copyright, comment, dumper, path, length, fade, tracks

- \[ **send** \$.. ( - Sends metadata info through the
last outlet.

- \[ **mute** \$.. ( - Mute/unmute a set of channels.
	- Zero unmutes all channels.

	- The same channel repeated toggles it on and off.

	- Muting is cumulative. New calls add to the mask's current state.

- \[ **solo** \$.. ( - Solo/unsolo a set of channels.
	- Zero unmutes all channels.

	- Soloing is not cumulative. New calls start with every channel muted and only the channels specified will become unmuted. However, if the resulting mask ends up being exactly the same as before, then the mask as a whole will act like a toggle and unmute all channels.

- \[ **mask** \$1 ( - Assign directly to the mute mask.
	- Acts as a setter when an arg is given and a getter when it isn't. Sends the value through the last outlet.

- \[ **open** \$1 ( - Attempts to open a file.
	- Sends a 1 or 0 through the last outlet to indicate success or failure.

- \[ **seek** \$1 ( - Seek to a track position.

- \[ **speed** \$1 ( - Set the playback speed.

- \[ **tempo** \$1 ( - Set the tempo.
	- Not to be confused with speed. Tempo changes the rate of emulation, while speed changes the rate of playback via resampling.

	- Speed and tempo together can pitch-shift very effectively.

- \[ **play** \$1 ( - An alias for \[ **bang** (.

- \[ **stop** ( - An alias for \[ **0** (.

- \[ **time** ( - Returns both the song length and fade length in the form of a list.
