# VocalWriter Mobile Experiment

An accessible native iPhone prototype around the VocalWriter C engine.

## Current milestone

- Native SwiftUI Song, Tracks, Notes, and Player tabs.
- VoiceOver-friendly note rows with edit, transpose, resize, reorder, preview,
  and delete actions.
- Adjustable note pitch through the VoiceOver swipe-up/down gesture.
- Magic Tap playback toggle.
- Native C bridge that renders the selected track to a WAV file and plays it.
- A small Daisy Bell example loaded on first launch.

## Build

1. Install XcodeGen (`brew install xcodegen`) if needed.
2. Run `xcodegen generate` in this directory.
3. Open `VocalWriterMobile.xcodeproj`.
4. Select your development team and an attached iPhone.
5. Build and run.

The legacy VocalWriter resources in this experiment are for personal
sideloading and preservation work only. Do not distribute the built app or
resources without permission from their copyright holder.

