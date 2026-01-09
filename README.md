# YouSkipSilence

A YouTube tweak for iOS that automatically skips silent parts of videos. Inspired by the [skip-silence](https://github.com/vantezzen/skip-silence) browser extension by vantezzen.

## Features

- **Automatic Silence Detection**: Speeds up video during silent parts and returns to normal speed when audio returns
- **Dynamic Threshold**: Automatically adjusts the silence detection threshold based on audio levels (enabled by default)
- **Customizable Speeds**:
  - Playback Speed: 1.1x - 1.5x (or custom)
  - Silence Speed: 1.5x - 4.0x (or custom)
- **Overlay Button**: Easy toggle on/off with visual feedback (icon changes when enabled)
- **Long Press Settings**: Quick access to settings popup by long-pressing the button
- **Time Saved Tracking**: See how much time the extension has saved:
  - Current video time saved
  - Last video time saved
  - Total time saved across all videos
  - Option to reset time saved stats
- **Default Settings**: Playback speed 1.1x, Silence speed 2x

## Requirements

- iOS 11.0 or later
- [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) (>= 2.0.0)
- YouTube app (YTLite compatible)

## Installation

1. Add the repository to your package manager
2. Install YTVideoOverlay if not already installed
3. Install YouSkipSilence

## Usage

1. **Enable/Disable**: Tap the Skip Silence button in the video player overlay
2. **Settings**: Long press the button to access settings popup with:
   - Playback speed options (1.1x - 1.5x or custom)
   - Silence speed options (1.5x - 4.0x or custom)
   - Dynamic threshold toggle
   - Time saved statistics (current video, last video, total)
   - Reset time saved button

## Building

### Requirements
- [Theos](https://theos.dev/)
- iOS SDK

### Build Commands
```bash
make package
```

For rootless jailbreaks:
```bash
make package THEOS_PACKAGE_SCHEME=rootless
```

## Credits

- Inspired by [skip-silence](https://github.com/vantezzen/skip-silence) by vantezzen
- Built using [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) by PoomSmart
- Reference implementations from [YouTimeStamp](https://github.com/Sohday67/YouTimeStamp) and [YouShare](https://github.com/Tonwalter888/YouShare)

## License

MIT License
