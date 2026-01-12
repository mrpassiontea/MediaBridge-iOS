# MediaBridge iOS UI/UX Implementation Guide

 This document outlines the technical implementation details for the MediaBridge User Interface using **SwiftUI**.

## Main Structure
The application uses a single main window with a state-driven view switcher as its root.

### `ContentView` (Root)
Uses a `ZStack` or `Group` to transition between views based on the `MainViewModel.state`.
- **Animation**: `.easeInOut` transition between states.
- **Background**: Global background color (default system).

## Detailed View Specifications

### 1. SearchingView
**State**: `searching`
- **Layout**: `VStack` centered.
- **Top**: Spacer
- **Center**:
  - Icon: `wifi` (SF Symbol), size 60pt, Blue.
  - Animation: Scale/Opacity pulse effect around the icon to indicate scanning.
  - Text: "Searching for PCs..." (Headline, Gray).
- **Bottom**: "Make sure MediaBridge is open on Windows" (Footnote, Secondary).
- **Functionality**:
  - On appear: Start Bonjour browser.
  - On tap of recognized device: Transition to `PCListView` (or direct connect if 1 device).

### 2. PCListView
**State**: `pcList` (when >0 devices found)
- **Layout**: `NavigationView` with Title "Connect to PC".
- **List**:
  - `ForEach` discovered device in `MainViewModel.devices`.
- **List Row**:
  - **Icon**: `laptopcomputer` (SF Symbol), Blue.
  - **Text**: `device.name` (Headline).
  - **Subtitle**: `device.ipAddress` (Caption, Gray).
  - **Action**: chevron or "Connect" button.
- **Interaction**: Tap row to trigger `connect(to: device)`.

### 3. PINVerificationView
**State**: `verifying`
- **Layout**: `VStack` spaced.
- **Header**: "Connection Request" (Title 2).
- **Subtext**: "Enter this PIN on your computer to approve connection." (Body).
- **PIN Display**:
  - Large Monospace Font (32-40pt).
  - Container: Rounded Rectangle Gray background.
  - Value: `viewModel.pinCode`.
- **Timeout Indicator**:
  - Circular progress view or countdown timer (30s).
- **Cancel Button**: "Cancel Request" (Red) at bottom.

### 4. ConnectedView
**State**: `connected` (Initial Phase - Syncing)
- **Layout**: `VStack`.
- **Status Hero**:
  - Icon: `arrow.triangle.2.circlepath` (spinning) or `checkmark.circle` (if done).
  - Text: "Connected to [PC Name]" (Headline).
- **Progress Section**:
  - "Syncing Thumbnails..."
  - `ProgressView` (Linear).
- **Asset Count**: "Found X photos, Y videos".

### 5. ReadyView
**State**: `ready`
- **Layout**: `VStack` centered.
- **Status**:
  - Large Checkmark Icon (Green).
  - "Ready for Transfer" (Title 2).
- **Instruction**: "Select photos on your computer to start download." (Body, Secondary).
- **Actions**:
  - "Disconnect" Button (Red text).

## View Model Integration
All views observe `MainViewModel` (StateObject).

```swift
class MainViewModel: ObservableObject {
    @Published var state: AppState = .searching
    @Published var devices: [PCDevice] = []
    @Published var pinCode: String?
    @Published var connectedDevice: PCDevice?
    // ...
}

enum AppState {
    case searching
    case pcList
    case verifying
    case connected // syncing
    case ready
}
```

## Accessibility
- **Dynamic Type**: All fonts scale.
- **VoiceOver**:
  - Status changes announced automatically.
  - Buttons have clear labels ("Connect to MacBook Pro").
  - PIN read as digits ("8, 4, 7, 2").

## Dark Mode Support
- Rely on semantic system colors (`Color.systemBackground`, `Color.label`) ensuring automatic adaptation.
