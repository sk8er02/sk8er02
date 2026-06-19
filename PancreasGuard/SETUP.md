# PancreasGuard - Setup Guide

## Prerequisites
- Mac with Xcode 15+ installed
- Apple Developer account (free for device testing, $99/year for App Store)
- Apple Watch Series 6+ paired with iPhone (for full sensor access)
- iOS 17+ / watchOS 10+

## Creating the Xcode Project

1. **Open Xcode** > File > New > Project
2. Choose **App** template, set:
   - Product Name: `PancreasGuard`
   - Organization Identifier: `com.pancreasguard` (or your own)
   - Interface: SwiftUI
   - Storage: SwiftData
3. Add a **watchOS App** target:
   - File > New > Target > watchOS > App
   - Name: `PancreasGuardWatch`

## Adding Source Files

### iOS App Target (`PancreasGuard`)
Copy into the iOS target:
- `PancreasGuard/App/` - App entry point and content view
- `PancreasGuard/Views/` - All SwiftUI views
- `PancreasGuard/Services/` - HealthKitManager, AlertEngine
- `Shared/` - All shared models and utilities

### watchOS App Target (`PancreasGuardWatch`)
Copy into the watchOS target:
- `PancreasGuardWatch/App/` - Watch app entry point
- `PancreasGuardWatch/Views/` - Watch-specific views
- `PancreasGuardWatch/Services/` - BackgroundMonitor, WatchConnectivity
- `Shared/` - All shared models and utilities (add to both targets)

## Enabling Capabilities

### For both targets:
1. Select target > Signing & Capabilities
2. Click **+ Capability** > **HealthKit**
3. Check "Background Delivery" under HealthKit
4. Add the `.entitlements` file to the target's build settings

### iOS target additionally:
- Add `Info.plist` entries for `NSHealthShareUsageDescription`

## Running on Device
- HealthKit requires a **real device** — the Simulator doesn't provide sensor data
- Pair your Apple Watch with your iPhone
- Select the Apple Watch scheme in Xcode to deploy the watch app
- Both apps must be installed for WatchConnectivity to work

## Testing the Risk Engine
The `RiskScoringEngine` can be unit tested with mock data without a device.
Create a test target and instantiate `RiskScoringEngine` with custom baselines.

## App Store Submission Notes
- Category: Health & Fitness
- Include medical disclaimer in App Store description
- Declare HealthKit data types in App Privacy nutrition labels
- All data stays on-device (no server component)
- Do NOT make diagnostic claims in marketing materials
