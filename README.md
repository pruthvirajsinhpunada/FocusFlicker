# Focus Flicker

🎮 **The Anti-Distraction Shield** - A retro pixel-themed iOS app that uses biological signals to combat "zombie scrolling"

## Features

- 👁️ **Eye Tracking** - Uses Vision Framework to detect blink rate and continuous stare time
- 🌑 **Screen Dimming** - Overlay gradually darkens and shifts to grayscale when distracted
- 🏃 **Physical Reset** - Stand up + wave phone in a circle pattern to unlock colors
- 🎮 **Gamified Experience** - XP, levels, and heart lives with retro arcade aesthetics

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **Vision Framework** - Face landmark detection for eye tracking
- **CoreMotion** - Accelerometer & gyroscope for reset gesture
- **AVFoundation** - Camera access for front-facing camera

## Requirements

- iOS 17.0+
- iPhone X or later (TrueDepth camera required for eye tracking)
- Xcode 15+

## Installation

1. Clone this repository
2. Open in Xcode: `open "focus flicker"`
3. Select your iPhone as the run destination
4. Build and run

## How It Works

1. **TRACK** - The app monitors your blink rate using the front camera
2. **DETECT** - When you stare without blinking (zombie scrolling), the screen dims
3. **RESET** - Stand up and wave your phone to restore full brightness

## Screenshots

The app features a retro 8-bit pixel art aesthetic with:
- Health bar style "FOCUS METER"
- XP and leveling system
- Animated pixel eye sprite
- "GAME OVER?" overlay when in zombie mode

## Privacy

- All processing happens on-device
- No data is sent to any server
- No user accounts required

## License

MIT License
