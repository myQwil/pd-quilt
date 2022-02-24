### Dependencies for macOS:

```
port install libunrar; brew install ffmpeg@4
```
In order for gme(s)\~.pd_darwin to work, `libgme.1.dylib` needs to be moved to `/usr/local/lib`

--------------------------------------------------

### Dependencies for Debian/Ubuntu:

```
apt install libsamplerate0 zlib1g libunrar5 libubsan1 libavutil56 libavcodec-extra58 libavformat58 libswresample3
```

--------------------------------------------------

### Dependencies for Windows:
Most dependencies are already included. However, ffplay\~ will require some additional FFmpeg libraries, which can be downloaded here: <https://github.com/myQwil/pd-quilt/releases/download/v0.7.7/ffmpeg.v4.4.1.Windows-amd64-32.zip>
