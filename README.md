# YouSkipSilence

A YouTube tweak for iOS that automatically speeds up silent parts of videos. Inspired by the [skip-silence](https://github.com/vantezzen/skip-silence) browser extension by vantezzen.

## How it works
- Samples audio from the current `AVPlayerItem` with a processing tap and computes short-window RMS.
- Uses a dynamic noise-floor baseline (EMA) by default; falls back to a fixed threshold when disabled.
- Switches playback rate between normal and silence speeds with debouncing and saved-time stats.

## Defaults
- Enabled: On
- Dynamic threshold: On
- Playback speed: 1.1x
- Silence speed: 2.0x

## Build & Install
```sh
make package
```

Rootful install:
```sh
sudo dpkg -i packages/com.youskipsilence.tweak_*.deb
```

Rootless install:
```sh
make package THEOS_PACKAGE_SCHEME=rootless
```
