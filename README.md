# Checkera — iOS

Checkera is a daily-task and timeline planner for iOS, built with **SwiftUI** and **SwiftData** (iOS 17+). It includes a home timeline, a task editor, quiet-hours / sleep-window settings, local notifications, and a Today **WidgetKit** widget.

## Requirements

- Xcode 15 or newer
- iOS 17.0+ deployment target
- Swift 5.10
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (the Xcode project is generated from `project.yml`)

## Getting started

```bash
# 1. Generate the Xcode project from project.yml
brew install xcodegen
xcodegen generate

# 2. Open it
open Checkera.xcodeproj
```

Then, in Xcode, select the **Checkera** target → **Signing & Capabilities** and set your own development team before building to a device.

## Project structure

| Path | Description |
|------|-------------|
| `Checkera/` | App source — `App/`, `Features/` (Home, Task Editor, Settings), `Models/`, `Persistence/` (SwiftData), `Services/`, `Components/`, `Resources/` |
| `CheckeraWidget/` | Today timeline widget (WidgetKit) |
| `CheckeraTests/` | Unit tests (Swift Testing) |
| `Scripts/` | Asset-generation helpers (require external brand assets; not needed to build) |
| `project.yml` | XcodeGen project definition |

## Running tests

Use the `CheckeraTests` scheme in Xcode (**⌘U**), or:

```bash
xcodebuild test -project Checkera.xcodeproj -scheme Checkera -destination 'platform=iOS Simulator,name=iPhone 15'
```
