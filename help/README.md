### Dependencies for macOS:

```
port install libunrar; brew install ffmpeg
```
`libsamplerate` will also be installed as one of ffmpeg's dependencies.
In order for gme(s)\~.pd_darwin to work, `libgme.1.dylib` needs to be moved to `/usr/local/lib`

--------------------------------------------------

### Dependencies for Linux:

## Debian/Ubuntu:
```
apt install libsamplerate0 zlib1g libunrar5 libubsan1 libavutil56 libavcodec-extra58 libavformat58 libswresample3
```

## Arch:
```
pacman -S libsamplerate libunrar ffmpeg
```

--------------------------------------------------

### Dependencies for Windows:
Most dependencies are already included. However, ffplay\~ will require some additional FFmpeg libraries, which can be downloaded here: <https://github.com/myQwil/pd-quilt/releases/download/v0.8.3/ffmpeg.v5.1.2.Windows-amd64-32.zip>
