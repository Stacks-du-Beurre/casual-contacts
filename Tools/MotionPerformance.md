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

## Cached interaction materials

Low Power Mode remains a supported optimization condition. The card artwork,
face/gyro inputs, and foreground hologram textures remain live. Only the hidden
scene copies used by text blur materials reuse a prepared bitmap during scroll
and zoom. The bitmap includes the guilloche at its settled reveal state. Blur
is rendered into that bitmap once. Live materials return through a 180 ms
crossfade. List materials remain held through fullscreen dismissal, although
the visible list artwork resumes immediately.

Preparation starts after 500 ms of settled activity. It is cancelled during
interactions, covered settings, and inactive scene phases. The cache has a
16 MiB cost limit; exact-size and fallback entries both count against that
budget. It contains generated card imagery in memory and does not write files.
Cold or evicted entries use the live material until a sample is available.
Diagnostic events record cache availability and preparation duration, without
images or viewpoint coordinates. Simulator preparation durations were roughly
1–2 ms per image. Settings diagnostics contain no preparations between the
suspension and resumption markers, and settled buckets have no sensor updates.

The scripted scroll harness now explicitly activates the scrolling geometry
policy. ScrollViewReader animations did not reliably report the same phases as
finger scrolling. `-MotionLiveMaterials` is a DEBUG-only comparison switch. The
optimized build with that switch measured median/p95 gaps of 89.86/113.47 ms
entering, 82.64/167.39 ms exiting, and 63.42/432.92 ms scrolling. The retained
cache-enabled run measured 35.09/57.37, 55.60/83.15, and 47.47/331.85 ms, with
five cycles per phase and nonzero mock motion/depth throughout. These compare
the two material policies within the same renderer, not GPU-presented FPS or a
controlled physical-device build 62 comparison. The slower scroll tail remains.

Focused rendering tests check live blur pixel parity and verify that static
samples include guilloche without waiting for an appearance/reveal callback.
The on-device Low Power Mode comparison is still required.

## Retained Core Animation blend paths — 2026-10-15

Build 72 is the camera-cadence baseline. It prefers a native 30 fps ARKit
format and limits pose extraction to 30 Hz. Display smoothing and gyro
prediction still run at the display cadence. The simulator cannot measure
real camera capture cost.

A local DEBUG-only experiment replaced the blend stack with retained
CAShapeLayer paths and updated layer transforms. Static material samples
kept the original renderer. Two scopes were tested: all card presentations,
then list cards only. No host build ran during measurement. The final control
repeat used the same simulator test binaries as the list-only experiment.

| Renderer | Entry median / p95 ms | Exit median / p95 ms | Scroll median / p95 ms |
| --- | --- | --- | --- |
| Original control | 36.0 / 58.1 | 45.4 / 64.3 | 48.1 / 183.5 |
| Retained paths, all cards | 39.5 / 56.4 | 49.4 / 81.6 | 44.5 / 151.1 |
| Retained paths, list only | 35.8 / 59.0 | 53.5 / 79.4 | 45.9 / 154.8 |
| Original control repeat | 35.7 / 56.7 | 48.4 / 76.2 | 47.8 / 217.2 |

The small scroll improvement did not justify the exit regression and new
renderer. The prototype and its temporary test switches were removed.
Raw metrics are under ignored build/motion-performance/retained-*.json.
These are display-callback intervals, not GPU-presented frame rates.
Next: profile the original scroll renderer to identify CPU hot paths before
selecting another cache boundary. Preserve the approved visual effects.

## Build 72 device follow-up (October 15)

The 25.3-second device recording uses iPhone18,1 / iOS 27.2, Low Power Mode
throughout, and normal thermal state. `camera_cadence` confirms native capture
at 30 FPS, pose sampling at 30 FPS, and a 60 Hz display target. During repeated
scrolling (sample windows ending at 3.03–19.19 seconds), 948 callbacks over
17.17 seconds give 55.2 callbacks/s. Twelve callback intervals exceed 33 ms;
the largest is 43.44 ms. The previous build 68 recording's slower scroll
windows were approximately 40–46 callbacks/s, but gestures and face visibility
differ, so this is encouraging device evidence rather than a controlled causal
comparison. There are no fullscreen transitions in either recording.

ARKit face input is intermittently unavailable; gyro prediction continues.
No camera deliveries are classified stale. Material captures occur before
scrolling and after the list settles, not during the active scroll interval.
Memory settles near 296 MB. Settings stops scene/camera updates but contains
an isolated 109.5 ms callback gap, so that hitch cannot be attributed to active
face processing. These counters do not measure GPU-presented frames.

## Cached bitmap format experiment (rejected)

A five-second `sample` capture of the moving simulator list shows substantial
RenderBox image texture preparation, vImage channel conversion, and simulator
texture upload work. This is CPU sampling, including waits, not GPU timing or
a physical-device profile. A separate Time Profiler recording again failed to
finish and is not used as evidence.

Changing the mirrored gradient and rotation stroke caches from RGBA to native
little-endian premultiplied BGRA preserved color and artwork orientation in
five focused tests. Two optimized simulator runs with photo cards, continuous
motion, and five cycles per scenario gave mixed timing results:

| Renderer | Enter median/p95 ms | Exit median/p95 ms | Scroll median/p95 ms |
| --- | --- | --- | --- |
| Original control | 37.31 / 56.75 | 43.32 / 78.15 | 47.13 / 150.79 |
| BGRA caches | 34.87 / 54.84 | 43.61 / 64.69 | 47.56 / 167.20 |
| BGRA repeat | 37.89 / 56.51 | 39.56 / 68.82 | 46.80 / 204.07 |

All UI scenarios passed. The change did not consistently improve all relevant
paths and was removed. Raw ignored artifacts use `bgra-control-`,
`bgra-experiment-`, and `bgra-repeat-` prefixes under
`build/motion-performance/`. No builds or other profiling ran during measured
cycles. The next image-preparation target is the cached text-material output,
rather than assuming the small gradient and stroke caches dominate the profile.

## Broad text-material resolution experiment (rejected)

Reducing only the cached broad-blur material (radius >=20 pt) from 1.5× to
0.5× resolution left sharper materials and the visible live card unchanged.
An optimized continuous-motion/photo simulator comparison gave:

| Renderer | Enter median/p95 ms | Exit median/p95 ms | Scroll median/p95 ms |
| --- | --- | --- | --- |
| Original control | 35.36 / 57.36 | 41.90 / 74.38 | 47.02 / 216.31 |
| Lower-resolution broad blur | 36.68 / 58.40 | 55.16 / 82.27 | 47.85 / 183.69 |

Five cycles per phase passed in both UI runs. There was no useful transition
improvement, and the experiment was removed. No visual parity claim is made
for this rejected prototype. Ignored metrics use `material-scale-control-`
and `material-scale-experiment-` prefixes. Inspection also found that the
shipped Neon_3 texture is only 338×338; oversized hologram source artwork is
not supported as the explanation for texture upload cost.

## Opaque list surface experiment (rejected)

Using an opaque list drawing group when the gradient backdrop is visible
preserved the transparent path for the developer hide-backdrop option.
The original control above was compared with two experiment runs and a fresh
original control. Each used five photo/motion cycles per scenario:

| Renderer | Enter median/p95 ms | Exit median/p95 ms | Scroll median/p95 ms |
| --- | --- | --- | --- |
| Original control | 35.36 / 57.36 | 41.90 / 74.38 | 47.02 / 216.31 |
| Opaque row | 35.04 / 54.25 | 38.83 / 65.08 | 46.10 / 214.89 |
| Opaque row repeat | 34.39 / 56.74 | 50.63 / 73.18 | 48.33 / 184.34 |
| Original control repeat | 34.22 / 57.06 | 50.14 / 80.84 | 47.09 / 151.28 |

All scenarios passed, but exit timing varied more between runs than between
implementations. The change was removed. Raw ignored artifacts use
`opaque-row-experiment-`, `opaque-row-repeat-`, and
`opaque-row-control-repeat-` prefixes. No production changes remain from
these experiments.

The next acceptance gate is build 72 device transition evidence. Its supplied
recording contains only scrolling and settings, so it cannot establish whether
entry or exit remain slow after the camera cadence change. CoreDevice currently
reports the user's paired iPhone as unavailable. Obtain a recording with five
open/close cycles for a photo card and a non-photo card, while moving the phone,
in Low Power Mode; then repeat with Low Power Mode off. Keep the existing
visuals and use those traces to decide the next implementation change rather
than retaining changes supported only by simulator texture-upload costs.

## Build 72 transition trace and frame-pacing request

The 40-second October 15 device trace includes six enter/exit pairs, Low Power
Mode off throughout, and thermal state normal then fair. Ten of twelve
transitions have no callback interval above 33 ms. One photo-card entry has
20.42 ms median / 35.63 ms p95; its exit has 29.85 / 42.14 ms, maximum
61.69 ms. A later non-photo exit has a single 49.52 ms gap. Other transitions
are mostly near 16.7 ms. Two scrolling windows contain delayed camera delivery,
up to 204.6 ms, while gyro delivery remains fresh.

Many scrolling windows report a scheduled callback interval of 25 ms, matching
approximately 40 callbacks/s. The existing 30–60 Hz request permits that cadence;
these windows must not all be described as missed 60 Hz rendering deadlines.

The candidate policy requests 60–120 Hz on ProMotion displays in normal mode,
60–60 Hz on standard displays, and retains the previous 30–60 Hz range in Low
Power Mode. The app now includes the required ProMotion Info.plist opt-in. Both the scene and diagnostic display links
use the same policy and update via the power-state notification on the main
actor. Camera capture/pose sampling stays at 30 FPS. iOS can still override
frame-rate requests. Transition completion diagnostics now include camera count,
maximum camera age, and minimum/maximum scheduled callback interval for that
transition. These distinguish input stalls, adaptive pacing, and actual callback
gaps without adding image or contact data. Device improvement remains unverified
until a new device build is tested; simulator tests cannot establish ProMotion
or Low Power Mode behavior.

Validation: nine focused cadence/timing/transition-export tests passed, the
production Release generic-iOS build passed, and the optimized simulator
moving-photo diagnostic scenario passed five enter/exit cycles. All ten exported
completion rows contain the new camera and scheduled-interval fields with
nonempty callback summaries. Unit coverage verifies camera counts/ages reset
between transitions and an export before any display tick contains finite zero
scheduled intervals. These are implementation checks, not a measured device
pacing improvement or a fix claim for the isolated photo-exit stall.

## ProMotion candidate verification (October 17)

30 Hz pose cadence plus elapsed-time display smoothing passes at both 60 and
120 display updates/s in parameterized tests. The sampling gate accepts exactly
30 targets in either case and the intervening smoothed attitudes keep moving.
Frame-rate policy tests cover 120 Hz hardware, 60 Hz hardware, and Low Power
Mode. All ten focused tests (eleven parameter cases) pass. The production
Release build passes and its built Info.plist contains the ProMotion opt-in.
The existing optimized simulator moving-photo entry/exit and scrolling scenarios
also pass five cycles each. This simulator reports a 60 Hz maximum, so neither
its callback timings nor the unit simulation prove actual 120 FPS or reduced
rendering cost on a phone. The candidate requests up to 120 Hz while card scene
motion is active; face pose processing remains 30 Hz. This is a device-test
candidate, not a claim that the prior 40 Hz scroll symptom has been fixed.

## Separate display and pose cadence candidate (October 17)

Build 73's device trace schedules 8.33 ms display callbacks, but active list
windows average 85.6 callbacks/s (68–110 across windows). Camera input stays at
29.9/s with no stale deliveries and normal thermal state, Low Power Mode off.
No fullscreen transitions were recorded. This removes the earlier missing
ProMotion opt-in as the explanation for the remaining callback gaps.

The next candidate keeps the ProMotion display-link request, but gates pose
prediction/smoothing/publication to 60 Hz before observable scene values change.
Elapsed-time smoothing still uses time since the previous accepted update.
At 30 Hz display cadence every callback is accepted. Late callbacks consume the
latest pose without replaying a backlog. Camera processing remains 30 Hz.
`sceneDisplayCallbacks` now counts display-link invocations, while `sceneTicks`
counts accepted pose updates; `scenePoseTargetHz` reports 60 in the cadence event.
This avoids interpreting lower pose counts as dropped display callbacks.

Description wrapping and holographic name glyphs are equality-isolated from
motion inputs. Text, width and font changes still invalidate them normally.
No image, blur, depth, or layer-order changes are part of this candidate.
The static name/description screenshot region (x<1000, excluding system chrome,
on a 1206×2622 fixture screenshot) is pixel identical to the original. Small
unrelated differences remain at the right edge; no full-image parity claim is made.

The debug waveform targets 120 source ticks/s and uses the same pose gate.
`-MotionHarnessUnthrottled` bypasses it for a control comparison. The simulator
has a 60 Hz maximum, so this is a load/regression test, not physical 120 Hz proof.
Five photo-card cycles per scenario, without concurrent host builds, measured:

| Variant | Enter median/p95 ms | Exit median/p95 ms | Scroll median/p95 ms |
| --- | --- | --- | --- |
| Unthrottled source, original text | 36.01 / 54.46 | 39.83 / 75.99 | 46.17 / 198.07 |
| 60 Hz publication, static text isolation | 34.37 / 55.12 | 53.63 / 83.87 | 47.45 / 167.49 |

The result is mixed, not a confirmed speedup; previous runs also show large exit
variance. Keep this explicitly experimental pending the phone comparison.
Ignored raw metrics use `pose-publication-control-` and
`pose-publication-candidate-` prefixes. The UI scenarios, focused cadence/card
checks, and production Release build passed. On-device acceptance should compare
build 73 with the new candidate using the same cards and Low Power Mode state.

## Build 74 follow-up: isolate scroll rendering cost

The October 17 build 74 device recording averages 88.1 display callbacks/s,
58.5 accepted scene poses/s and 30.0 camera frames/s over complete active-list
windows. Build 73 averaged 85.6 callbacks/s. Pose publication has decreased,
but the recordings do not establish a meaningful scroll speedup. Low Power Mode
is off, thermal state is normal, and no fullscreen transitions are present.

The paired phone is unavailable to CoreDevice. An eight-second simulator CPU
sample during the optimized moving-photo scroll harness finds 2,071 of 4,852
main-thread samples inside RenderBox display/compositing. This includes waits;
it is neither exclusive CPU time nor a device GPU measurement. Texture
preparation/upload and channel conversion are substantial. Projection and
location-label work account for far fewer samples. Time Profiler again failed
to finish; only the completed `sample` capture is used as evidence.

The same simulator binary, fixture and five down/up cycles give the following
layer-isolation results. Values are callback median/p95 in milliseconds.

| Visible layers | Median | p95 |
| --- | ---: | ---: |
| All | 47.81 | 147.59 |
| All, repeat | 48.42 | 148.84 |
| Without compact text/materials | 19.44 | 49.57 |
| Without gradient | 45.81 | 134.99 |
| Without guilloche | 22.12 | 46.79 |
| Without frosted backdrop samples | 33.83 | 65.16 |
| Without name hologram textures | 45.57 | 137.73 |
| Split-test control, all | 48.13 | 149.65 |

These ablations identify costly components; removing artwork is not a proposed
product change. Raw artifacts use `render-probe-` under ignored
`build/motion-performance/`. Simulator-only DEBUG flags are
`-MotionOmitText`, `-MotionOmitGradient`, `-MotionOmitGuilloche`,
`-MotionOmitMaterial` and `-MotionOmitHologram`. They require
`-MotionPerformanceHarness` and never hide production content.

An equality-wrapper experiment around blend strokes and location labels was
removed: scroll median 47.28 → 46.65 ms is within observed run variance.
It did not address the dominant material/compositing work.

Three crop variants were tested against full-image controls. Each crops an
already-blurred sample to the visible pill, retains its original placement, and
keeps live backgrounds, blur strength, hologram motion, depth and photo framing.

| Variant | Scroll median / p95 ms |
| --- | --- |
| Shared-provider crop control | 47.06 / 183.40 |
| Shared-provider crop | 47.81 / 166.58 |
| Shared-provider crop repeat | 47.99 / 200.04 |
| Independent-buffer/full-surface control | 44.59 / 132.92 |
| Independent-buffer/full-surface crop | 45.34 / 134.30 |
| Independent-buffer/full-surface repeat | 47.28 / 133.96 |
| Compact drawing-surface control | 48.36 / 198.05 |
| Compact drawing-surface crop | 47.58 / 166.17 |
| Compact drawing-surface repeat | 47.40 / 215.81 |
| Compact drawing-surface control repeat | 48.01 / 231.44 |

All runs use five cycles, active synthetic motion, positive perspective depth,
and no concurrent host build or profiler. Reduce Motion is not enabled for the
performance comparisons. The independent copies reduce sample textures from
555×317 to regions such as 236×39 and 99×7; startup logging confirms that the
crop path runs. Five focused rendering/cache test methods (six parameter cases)
pass for the compact prototype, including exact bitmap-grid parity and composed
chrome tolerance of at most two 8-bit channel levels. These checks verify the
prototype, not a speedup. Initial resizable-image variants introduced subpixel
sampling differences and were corrected before the final comparison.

The improvement is too small and inconsistent to retain. All crop helpers,
caches, prototype tests and full-image control switches were removed. Only the
simulator-only layer-isolation switches and this report remain. Raw artifacts
use `crop-`, `crop-copy-` and `compact-` prefixes under the ignored metrics folder.

The result identifies material composition and guilloche rendering as useful
profiling targets, but does not establish the phone's CPU/GPU bottleneck or a
safe rendering optimization. Obtain a physical-device SwiftUI/Time Profiler and
rendering-hitch trace before selecting another rendering replacement. Further
camera sampling reductions are not supported by these measurements.

Final validation after removing the prototypes: production Release generic-iOS
build passed; the optimized simulator moving-photo scroll and fullscreen UI
scenarios passed five cycles each. The latter covers five entries and five
exits. No crop code or prototype tests remain. The default renderer and camera
cadence stay approved; these checks do not establish a phone speedup.

## TestFlight work diagnostics (schema 2)

Hardware testing uses TestFlight and the existing opt-in JSON export; a cable
or local-network connection to the Mac is not required. Samples now include
`processCPUMS`, `mainThreadCPUMS` and their `*CPUCorePercent` rates. One fully
occupied CPU core is 100%; process use can exceed 100% across multiple threads.
CPU readings are omitted if the platform clocks fail, and the CPU baseline is
reset on foreground changes. Background elapsed time is not charged to the
next foreground bucket.

`viewBody_*` fields count scene host, list, card, card text, backdrop, material
sample, hologram and blend-stack body evaluations. They count SwiftUI updates,
not rendered frames. `sceneWorkCount`, `sceneWorkTotalMS` and
`sceneWorkMaximumMS` time accepted scene-pose updates. They do not include
deferred SwiftUI layout or GPU work. Transition completion rows carry their own
CPU and work counters so a one-second sample cannot hide a short transition.
`maximumCallbackOverrunMS` measures callbacks that arrive past the display
link's next target time; it is not GPU presentation timing.

All new counters are aggregated in memory. No per-frame log rows or disk writes,
live settings readouts, contact content, camera frames or pose coordinates are
added. The renderer and 30 Hz camera/60 Hz scene policy are unchanged. These
metrics distinguish expensive input work, excessive view invalidation, and
main-thread CPU pressure; low CPU with delayed callbacks does not alone prove
a GPU bottleneck.

On the diagnostic TestFlight build, record roughly 20 seconds of scrolling,
then open/close both a photo card and a non-photo card several times while
moving the phone. Export with the existing Prepare/Share performance log flow.
Keep Low Power Mode off for the first recording; a separate recording with it
on is useful. Normal motion stays enabled in both recordings.
