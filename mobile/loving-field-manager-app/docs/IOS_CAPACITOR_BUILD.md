# iOS Build Instructions

## Prerequisites

| Requirement | Notes |
|---|---|
| macOS | Required for iOS build. |
| Xcode | Install from App Store. |
| Apple Developer account | Required for physical device or TestFlight. |
| Node.js | Use current LTS. |
| CocoaPods | Xcode usually handles this, but install if Capacitor asks. |

## Commands

```bash
npm install
npm run verify:ui-lock
npm run build
npm run ios:init
npm run ios:sync
npm run ios:open
```

## Xcode steps

1. Open the iOS project through `npm run ios:open`.
2. Select the App target.
3. Set Team under Signing & Capabilities.
4. Confirm Bundle Identifier: `com.loving.fieldmanager`.
5. Confirm Display Name: `LOVING Field Manager`.
6. Add camera permission text if Xcode requests it:
   - `NSCameraUsageDescription`: `LOVING Field Manager uses the camera to capture required field proof photos.`
   - `NSPhotoLibraryUsageDescription`: `LOVING Field Manager can select proof photos from the photo library.`
7. Run on simulator first.
8. Run on real iPhone second.
9. Only publish to TestFlight after Meg approves the visual and behavior test results.

## Do not skip

Run `npm run verify:ui-lock` before syncing iOS. If the visual CSS has changed, stop.
