# MediaBridge iOS

A minimal iOS companion app that serves as a **file server** enabling the Windows desktop application to browse and transfer photos/videos over WiFi.

## Overview

MediaBridge iOS provides an ultra-minimal UI focused solely on connection management, while the Windows app handles all gallery, selection, and transfer UI.

### Key Features

- **TCP Socket Server** - Listens on port 2347 for incoming connections
- **Bonjour Discovery** - Broadcasts presence and discovers Windows PCs on local network
- **PIN Verification** - Secure 4-digit PIN challenge for connection approval
- **Photo Library Integration** - Access and stream photos/videos to connected clients
- **Live Photo Support** - Handles HEIC + MOV pairs seamlessly

### Connection Flow

1. 📡 **Searching** - App broadcasts presence via Bonjour/mDNS
2. 🖥️ **PC List** - User taps to connect to a discovered computer
3. 🔐 **PIN Verification** - PIN sent to Windows app for user approval
4. 📤 **Thumbnail Sync** - Automatic thumbnail synchronization
5. ✅ **Ready** - Waiting for file selection on Windows

## Architecture

```
┌─────────────────────┐         TCP Socket Protocol         ┌─────────────────────┐
│    iPhone App       │                                    │   Windows App       │
│    (File Server)    │                                    │   (Client)          │
│                     │                                    │                     │
│  ┌───────────────┐  │                                    │  ┌───────────────┐  │
│  │ TCP Server    │◄─ ─ ─ ─ Connection Request ─ ─ ─ ─ ─►│  │ TCP Client    │  │
│  │ (port 2347)   │  │                                    │  │               │  │
│  └───────────────┘  │                                    │  └───────────────┘  │
└─────────────────────┘                                    └─────────────────────┘
```

## Requirements

- iOS 15.0+
- Xcode 15+
- Swift 5.9+
- XcodeGen (for project generation)

## Setup

### Prerequisites

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd MediaBridge-iOS
   xcodegen generate
   ```

3. Open the project:
   ```bash
   open MediaBridge.xcodeproj
   ```

## Project Structure

```
MediaBridge-iOS/
├── project.yml              # XcodeGen configuration
├── Podfile                  # CocoaPods dependencies (if needed)
├── MediaBridge/
│   ├── App/
│   │   ├── MediaBridgeApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── SearchingView.swift
│   │   ├── PCListView.swift
│   │   ├── PINVerificationView.swift
│   │   ├── ConnectedView.swift
│   │   └── ReadyView.swift
│   ├── Services/
│   │   ├── TCPServerService.swift
│   │   ├── BonjourService.swift
│   │   ├── PINService.swift
│   │   ├── PhotoLibraryService.swift
│   │   └── ThumbnailService.swift
│   ├── Models/
│   │   ├── PCDevice.swift
│   │   ├── Asset.swift
│   │   └── ConnectionState.swift
│   ├── ViewModels/
│   │   └── MainViewModel.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
├── MediaBridgeTests/
└── setup.sh
```

## TCP Protocol

The app uses a custom binary TCP protocol with a 59-byte fixed header:

```
┌──────────────────────────────────────────────────────┐
│ [1 byte: Command ID]  [8 bytes: Size LE]             │
│ [50 bytes: Info (UTF-8, null-padded)]                │
└──────────────────────────────────────────────────────┘
```

### Command Reference

| ID | Command | Description |
|----|---------|-------------|
| 1 | `CONNECT` | Request connection to iPhone |
| 2 | `PIN_CHALLENGE` | Display PIN on Windows |
| 3 | `VERIFY_PIN` | User enters PIN for verification |
| 4 | `PIN_OK` | PIN verified successfully |
| 5 | `PIN_FAIL` | PIN verification failed |
| 6 | `LIST_ASSETS` | Request all asset metadata |
| 7 | `ASSETS_LIST` | Return JSON array of assets |
| 8 | `GET_THUMBNAIL` | Request thumbnail for asset |
| 9 | `THUMBNAIL_DATA` | Return JPEG thumbnail bytes |
| 10 | `GET_FULL_FILE` | Request full file data |
| 11 | `FILE_DATA` | Stream file content |
| 12 | `DISCONNECT` | Close connection gracefully |

## Security

- 🔒 **PIN Timeout**: PIN expires after 30 seconds
- ⚠️ **Failed Attempts**: 3 wrong PINs = automatic disconnect
- 📶 **Same Network**: Both devices must be on same WiFi
- ✅ **User Approval**: Windows user must explicitly allow connection

## License

DENNIS PILAT