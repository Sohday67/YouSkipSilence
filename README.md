# YouSkipSilence

A YouTube tweak for iOS that automatically speeds up silent parts of videos. Inspired by the [skip-silence](https://github.com/vantezzen/skip-silence) browser extension by vantezzen.

## How it works
- Samples the currently playing audio with an `MTAudioProcessingTap`, computes RMS, and decides when silence is present.
- Applies a dynamic noise-floor baseline (EMA) by default, with a fixed-threshold fallback.
- Switches the player rate between playback and silence speeds, while tracking time saved.

## Defaults
- Enabled: **On**
- Dynamic threshold: **On**
- Playback speed: **1.1x**
- Silence speed: **2.0x**

## Build & Install
```bash
make package
```
Install the resulting `.deb` with your preferred package manager (rootful or rootless, depending on your device and Theos setup).
