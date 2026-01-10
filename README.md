# YouSkipSilence

A YouTube tweak for iOS that automatically skips silent parts of videos by speeding through them. Inspired by the [skip-silence](https://github.com/vantezzen/skip-silence) browser extension by vantezzen.

## Features

- **Automatic Silence Detection**: Monitors audio levels in real-time to detect silent portions
- **Speed Through Silence**: Automatically increases playback speed during detected silence
- **Dynamic Threshold**: Automatically adjusts silence detection based on audio content (enabled by default)
- **Time Saved Tracking**: Shows how much time you've saved by skipping silence
- **Overlay Button**: Toggleable button on the video player
- **Long-Press Quick Settings**: Access settings directly from the video player

## Requirements

- iOS 11.0 or later
- [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) (>= 2.0.0)
- YouTube app (compatible with YTLitePlus)

## Installation

1. Add the repository to your package manager
2. Install YouSkipSilence
3. The tweak will be automatically enabled

## Usage

### Overlay Button
- **Single Tap**: Toggle skip silence on/off
- **Long Press**: Open quick settings popup

### Quick Settings Popup
- **Playback Speed**: Control YouTube's native playback speed (syncs with YouTube's speed settings)
- **Silence Speed**: Speed used during silent portions (default: 2.0x)
- **Volume Threshold Visualizer**: Real-time audio level indicator
  - Blue = Normal playback
  - Orange = Silence detected/sped up
- **Threshold Limit Slider**: Manually adjust silence detection sensitivity
- **Dynamic Threshold Toggle**: Enable/disable automatic threshold adjustment

### Settings (in YTLitePlus Settings)
- Enable/Disable Toggle
- Button Position (Top or Bottom)
- Dynamic Threshold Toggle
- Time Saved (Last Video)
- Time Saved (Total)
- Reset Time Saved

## Default Settings

| Setting | Default Value |
|---------|---------------|
| Tweak Enabled | On |
| Playback Speed (on enable) | 1.1x |
| Silence Speed | 2.0x |
| Dynamic Threshold | Enabled |
| Button Position | Bottom |

## How It Works

1. The tweak monitors audio levels during video playback
2. When audio drops below the threshold for a sustained period, it speeds up playback
3. When audio returns above the threshold, normal playback speed resumes
4. Time saved is calculated as: `(silence_duration) - (silence_duration / silence_speed)`

## Credits

- [vantezzen/skip-silence](https://github.com/vantezzen/skip-silence) - Original Chrome extension for silence detection logic
- [PoomSmart/YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) - Overlay button framework
- [PoomSmart/YouSpeed](https://github.com/PoomSmart/YouSpeed) - Reference for playback speed control
- [PoomSmart/YouMute](https://github.com/PoomSmart/YouMute) - Reference for audio control
- [Sohday67/YouTimeStamp](https://github.com/Sohday67/YouTimeStamp) - Reference for settings structure
- [Tonwalter888/YouShare](https://github.com/Tonwalter888/YouShare) - Reference for overlay button implementation
- [Tonwalter888/YouLoop](https://github.com/Tonwalter888/YouLoop) - Reference for toggle functionality

## License

MIT License