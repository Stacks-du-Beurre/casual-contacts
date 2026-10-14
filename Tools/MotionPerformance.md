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
counts, scene gyro packet counts and delivery/render ages, tracking handoffs, foreground first-update times, resident memory,
thermal state, Low Power Mode, and photo load duration. It does not include
camera images, eye/face coordinates, photos, contact content, location, or
account information. Gyro counts are changed poses observed by the UI, not raw
sensor packet counts. Resident memory does not include all render-server/GPU
memory. Callback timing still does not prove presented FPS.

Scroll-phase events identify interacting, decelerating, animating, and idle
intervals. Gyro-fallback events distinguish missing samples, stale samples, and
an invalid projected viewpoint. Gyro delivery now runs on a serial background
queue; `maximumGyroAgeMS` measures delivery age there, while
`maximumGyroRenderAgeMS` measures the newest sample's age when the display
callback consumes it. This differs from build 58, which delivered gyro samples
on the main queue.

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

For scrolling, add `-MotionScrollHarness`. The app performs five down/up cycles
with continuous motion and writes `scroll-motion-photo-metrics.json`. The
targeted UI test is `testListScrollsWithContinuousMotionAndPhoto`.

## October 14 interaction retest

Release-optimized simulator runs used active mock motion and 60 mm scene depth,
without video recording during measurement. Five enter and five exit cycles
passed for both photo and non-photo cases; five photo scroll cycles passed.
Sixteen focused unit tests passed for geometry, photo fade/cache behavior, and
gyro buffering across stalled consumption and session changes.

Final median callback gaps were 140.91 ms entering and 118.90 ms exiting with
photos, and 64.40 ms during the scroll stress run. The initial photo run measured
139.40/96.46 ms; the initial scroll run measured 66.19 ms. Results are mixed and
do not establish a transition improvement or 60 FPS. A device comparison is
required. Experiments that cropped blur samples or removed list rasterization
were discarded because they performed worse.

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

## Build 60 exit and settings investigation

The device recording covers 37.7 seconds with Low Power Mode off and normal
thermal state. The three enter transitions have median callback gaps of
17.04, 20.83, and 18.71 ms. The three exits have medians of 21.87, 29.58, and
27.60 ms, with p95 gaps of 35.21, 35.22, and 32.97 ms. Settled list and
fullscreen intervals are generally near 16.7 ms. No camera frames are stale;
the largest gyro delivery and render ages are 16.36 and 24.41 ms. These data
point to transition rendering work rather than delayed sensor delivery.

The exit resumed list rendering through a separate 16 ms task while the zoom
also ran. The hidden selected row still contained a complete card, including
its backdrop samples. Its closing overlay also used the fullscreen reference
until removal, although list cards use their own frame centers. Both identity
layouts and their blur samples render during the layout morph; this remains
part of the transition cost.

The correction uses SwiftUI's animation scheduler for pose resumption, replaces
the hidden selected row with an equal-size placeholder, and blends the overlay
reference back to the list reference during the zoom. Motion resumes at the
start of dismissal. The zoom curve and approved fullscreen layout are unchanged.

Settings now suspend both the scene tracker and the root gyro stream. The list
holds its last pose and eases back when settings close. The pause remains in
effect through the Settings-to-3D-scene sheet handoff. Diagnostic context markers
record suspension and resumption. The explicit Motion debug screen starts its
sensor while visible; the cards behind it remain held.

The optimized simulator photo run has five enter/exit cycles with active mock
motion and 60 mm depth. Median exit gaps fell from 148.20 to 85.34 ms; p95 gaps
were 221.95 and 221.34 ms. Entry medians were 133.58 and 130.15 ms. A repeated
candidate run produced an 84.32 ms exit median. The no-photo candidate exit
median is 69.91 ms. These are callback measurements, not presented FPS. The
slow tail remains and the device comparison is still required.

The settings UI test opens each sheet, scrolls, closes it, returns to the list,
and exports diagnostics. Settled settings buckets contain no gyro or scene
updates; the list resumes updates after dismissal. Unit tests check the
projection endpoints, intermediate reference weights, pose easing, and the
settings handoff's pause state.

## Build 61 follow-up

The device recording has Low Power Mode enabled throughout, normal thermal
state, fresh camera frames, and healthy gyro delivery. Enter medians are
37.89/42.18 ms; exits are 49.77/48.61 ms. Settled fullscreen callbacks return
to about 16.7 ms. Build 60's recording had Low Power Mode off, so this is not
a controlled before/after comparison. Settings suspension remains effective.

The retained correction makes visibility bookkeeping actually stop rendering
offscreen cards. Equal-height placeholders preserve scroll geometry; a 160 pt
margin restores effects before a card reaches the viewport. Decoded gradient
sources are bounded to 768 pixels on the longer axis and cached separately
from aspect-specific mirrored tiles. This avoids repeated full-asset
decoding/resampling during zoom while retaining the mirrored composition
and all visible card motion.

Under the optimized simulator photo/motion harness, five cycles passed for
each interaction. Baseline median/p95 callback gaps in milliseconds were
72.59/85.62 entering, 87.74/148.59 exiting, and 66.83/368.26 scrolling. The
retained candidate measured 58.89/76.57, 71.12/108.50, and 64.75/298.60.
Transitions improved in this stress test; scrolling remains expensive and
these results do not establish 60 FPS or physical-device improvement.

Disabling duplicate full-scene blur samples reduced scroll median gaps to
36.17 ms, but changes the material appearance. System materials, cropped blur
samples, a combined Canvas, and an atlas shader did not improve all
interactions and were discarded. The blur and guilloche renderer remain
unchanged. A new device recording is required to assess the retained changes,
with the same Low Power Mode setting as the comparison when possible.
