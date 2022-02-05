## \[ **ffplay\~** ]

An implementation of FFmpeg for audio playback of almost any media format

When building, the FFmpeg libraries are dynamically linked by default, which means that you'll need a local installation of these libraries in order for the external to work.

Includes the following features:

- play/pause and seek functionality.

- changing the speed of playback.

- reading and iterating through m3u playlists.
	- It reads _pseudo_ m3u playlists. Each line in the m3u should be just the file name, preceded by a path relative to the location of the m3u if necessary.

- opening files from http urls.

- retrieving metadata.

### Creation args

1. numeric list
	- The channel layout. Defaults to stereo if no args given.

	- In the help file, you'll notice ffplay~ has the creation arguments `1 2 5 6`. The 5 and 6 represent rear-left and rear-right channels.

	- A full list of available channels can be found here: <https://github.com/FFmpeg/FFmpeg/blob/master/libavutil/channel_layout.h>

### Inlets

1. bang - Play/pause the currently loaded track.
	- Sends a 1 or 0 through the last outlet to indicate whether it's playing or paused.

	float - (Re)start playback of a given track number
	- Zero will stop playback.

- A file must be successfully opened for either of these to work

### Outlets

1. signal - Left channel

2. signal - Right channel
	- The number of signal outlets there are depends on the number of creation args given, but no args will default to stereo.

3. list - Outputs various messages including information regarding whether a file was successfully opened, whether a track is currently playing, track metadata, etc.

### Messages

- \[ **info** \$.. ( - Prints metadata info.
	- If no args given, it will print general info. Otherwise, it will print custom info.

	- metadata needs to be surrounded with percent signs.
		- Example \[ **info** %artist% - %title% (

- \[ **send** \$.. ( - Sends metadata info through the
last outlet.

- \[ **open** \$1 ( - Attempts to open a file.
	- Sends a 1 or 0 through the last outlet to indicate success or failure.

- \[ **seek** \$1 ( - Seek to a track position.

- \[ **speed** \$1 ( - Set the playback speed.

- \[ **play** \$1 ( - An alias for \[ **bang** (.

- \[ **stop** ( - An alias for \[ **0** (.

- \[ **tracks** ( - Returns the total number of tracks within the current playlist.

- \[ **pos** ( - Returns the track position.
