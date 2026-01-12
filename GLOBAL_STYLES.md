# MediaBridge iOS Global Styles Guide

## Design Philosophy
**Ultra-Minimalist & Functional**
The MediaBridge iOS app is a utility companion. Its UI should be invisible, focusing entirely on the connection status and task at hand. It uses standard iOS system components where possible to feel native and lightweight.

## Color Palette

### Semantic Colors
| Role | Color | Hex (Light/Dark) | System Equivalent | Usage |
|------|-------|------------------|-------------------|-------|
| **Primary** | Bridge Blue | `#007AFF` / `#0A84FF` | `Color.blue` | Buttons, Active State, Icons |
| **Success** | Signal Green | `#34C759` / `#30D158` | `Color.green` | Connected status, Verified |
| **Error** | Alert Red | `#FF3B30` / `#FF453A` | `Color.red` | Disconnected, Errors, Destructive |
| **Background** | System Base | `#FFFFFF` / `#000000` | `Color.systemBackground` | Main screen backgrounds |
| **Secondary BG**| System Grouped | `#F2F2F7` / `#1C1C1E` | `Color.secondarySystemBackground` | List items, Cards |

### Text Colors
- **Primary Text**: `Color.primary` (Black/White)
- **Secondary Text**: `Color.secondary` (Gray) – used for IP addresses, status subtitles.
- **Accent Text**: `Color.blue` – used for actions.

## Typography

Using iOS System Font (San Francisco).

| Style | Weight | Size | Usage |
|-------|--------|------|-------|
| **Large Title** | Bold | 34pt | Main Screen Headers |
| **Title 2** | Bold | 22pt | Section Headers |
| **Headline** | Semibold | 17pt | Device Names |
| **Body** | Regular | 17pt | Description text |
| **Callout** | Regular | 16pt | Status messages |
| **Monospaced** | Regular | 32pt | PIN Display |

## Spacing & Layout

- **Standard Margin**: `16pt` (horizontal)
- **Section Spacing**: `20pt` (vertical)
- **Corner Radius**: `12pt` (Buttons, Cards)
- **Icon Size**: `24pt` (Standard symbols), `48pt` (Hero status icons)

## Components

### Buttons
- **Primary Action**: Filled Blue rounded rectangle.
  - Height: 50pt
  - Text: White, Semibold
- **Secondary Action**: Bordered or Text-only Blue.

### Status Indicators
- **Pulse Animation**: Used in "Searching" state.
- **Connection Dot**: 
  - 🟢 Green: Connected
  - 🔴 Red: Disconnected/Error
  - 🟡 Orange: Connecting/Verifying

### Lists
- Use `List` or `Form` style for PC discovery.
- Rows should have a clean layout: Icon (Left) | Text (Middle) | Arrow/Status (Right).

## Assets
- App Icon: "Bridge" concept or "WiFi" symbol.
- System Symbols (SF Symbols):
  - `laptopcomputer` (for PC)
  - `wifi` (for connection)
  - `lock.fill` (for PIN)
  - `checkmark.circle.fill` (for success)
  - `photo.on.rectangle` (for gallery)
