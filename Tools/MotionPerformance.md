# Motion transition measurements

## Device log

In Settings → 3D scene → Performance diagnostics, enable Record performance.
Close Settings and test scrolling, moving the phone, opening and closing cards,
losing and reacquiring camera input, and returning from the background. Use both
photo and non-photo cards. Return to the same section, tap Prepare performance
log, then Share performance log. Save the JSON file to Files and attach it to
the chat. Preparing the log stops recording.

Recording is off by default, stops after ten minutes, and is held in bounded
memory until export. Export before force-quitting the app. Starting a new
recording replaces the previous session. The exported file remains in the app's
temporary directory until replaced or cleaned by iOS. Nothing is uploaded by
the app.

The log includes app version/build, device hardware type (not its name or unique
identifier), OS, refresh capability, scene options, relative event times,
transition durations, callback median/p95/max, long callback-gap counts, camera
delivery ages and validity counts, observed gyro pose changes, scene update
counts, scene gyro packet counts and delivery age, tracking handoffs, foreground first-update times, resident memory,
thermal state, Low Power Mode, and photo load duration. It does not include
camera images, eye/face coordinates, photos, contact content, location, or
account information. Gyro counts are changed poses observed by the UI, not raw
sensor packet counts. Resident memory does not include all render-server/GPU
memory. Callback timing still does not prove presented FPS.

Use an optimized simulator build for comparisons. Keep synthetic motion and
nonzero perspective depth active. Display callback intervals measure main-thread
availability; they do not measure GPU-presented frames or prove device FPS.

## Build and run

Run from the worktree root. Use this worktree's simulator UUID in place of
`SIMULATOR_UUID`.

```sh
xcodebuild -project CasualContacts/CasualContacts.xcodeproj \
  -scheme CasualContacts -configuration Release \
  -destination id=SIMULATOR_UUID -derivedDataPath build/motion-release \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG CODE_SIGNING_ALLOWED=NO build
xcrun simctl install SIMULATOR_UUID \
  build/motion-release/Build/Products/Release-iphonesimulator/CasualContacts.app
xcrun simctl launch SIMULATOR_UUID com.stacksdubeurre.CasualContacts \
  -ScreenshotMode YES -ScreenshotSeed YES -ScreenshotLanguage en \
  -MotionPerformanceHarness -MotionHarnessPhoto \
  -FaceScene.listEnabled YES -FaceScene.expandedEnabled YES \
  -FaceScene.cameraEnabled NO
```

This is a Release-optimized build with DEBUG branches enabled for the test
harness. It is not the exact App Store binary. The compiler uses `-O` and
whole-module optimization. Do not ship this configuration.

Wait for the list to settle, then tap the first card once. The app performs five
open/close cycles. Do not record video or query accessibility during those cycles.
After the list returns, copy `Documents/transition-motion-photo-metrics.json`
from the data container returned by:

```sh
xcrun simctl get_app_container SIMULATOR_UUID \
  com.stacksdubeurre.CasualContacts data
python3 Tools/summarize-motion-performance.py BEFORE.json AFTER.json
```

Repeat after terminating and relaunching the app. Compare the same build
configuration, simulator, fixture, and host load. Separate first-run cache costs
from warmed runs. Remove `-MotionHarnessPhoto` for the no-photo case; its output
is `transition-motion-metrics.json`.

## Instruments and limits

On this Mac's iOS 26.5 simulator, Animation Hitches reports:
`Hitches is not supported on this platform.` Do not report its trace as a valid
hitch measurement. A Time Profiler attempt also did not complete successfully;
no CPU findings are derived from that attempt.

Use simulator callback comparisons to detect regressions under a controlled
load. Use Animation Hitches on a physical device with an optimized build to
verify rendering deadlines and smoothness. Apple's guidance recommends a real
device for realistic hitch measurements:
https://developer.apple.com/documentation/xcode/improving-app-responsiveness
