import SwiftUI
import CoreModels
#if canImport(UIKit)
import UIKit
#endif

/// Top-level debug screen. Subscribes to `service.debugSamples` only while
/// the view is on screen (SwiftUI cancels the `.task` on disappear). Drives
/// repaints from `TimelineView(.animation)` so the Canvas redraws at display
/// refresh, not per sample arrival.
@MainActor
public struct MotionDebugScene: View {

    public let service: any MotionService

    @State private var viewModel = MotionDebugViewModel()
    @State private var reduceMotionActive = false
    @State private var dotSource: MotionDebugDotSource = .relative
    @State private var gravityRebaser = GravityRebaser()
    @State private var relativeRebaser = RelativeRotationRebaser()
    /// Live binding to the singleton tuning shared with `CoreMotionService`,
    /// so dragging the slider here also tunes the production card animations.
    @Bindable private var motionTuning = MotionTuning.shared

    public init(service: any MotionService) {
        self.service = service
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Picker hoisted OUTSIDE TimelineView so its identity is stable
            // (TimelineView re-evaluates 60Hz, which was fighting the segmented
            // control's tap-state somehow). dotSource updates flow into the
            // TimelineView block below by closure capture.
            VStack(alignment: .leading, spacing: 8) {
                Text("Source: \(dotSource.label)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
                Picker("Source", selection: $dotSource) {
                    ForEach(MotionDebugDotSource.allCases, id: \.self) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                if dotSource == .relative {
                    HStack(spacing: 12) {
                        Text("Full-scale: \(Int(motionTuning.relativeFullScaleDegrees))°")
                            .font(.caption.monospacedDigit())
                            .frame(width: 130, alignment: .leading)
                        Slider(value: $motionTuning.relativeFullScaleDegrees, in: 10...180, step: 5)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            TimelineView(.animation) { timeline in
                let snapshot = viewModel.snapshot()
                let now = timeline.date
                let rate = viewModel.emissionRate(referenceTime: now)

                ScrollView {
                    VStack(spacing: 0) {
                        if reduceMotionActive {
                            Text("Reduce Motion is on — debug stream is suppressed.")
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(.orange.opacity(0.2))
                        }
                        MotionDebugPinnedRegion(
                            snapshot: snapshot,
                            emissionRate: rate,
                            referenceTime: now,
                            dotSource: dotSource,
                            gravityRebaser: gravityRebaser,
                            relativeRebaser: relativeRebaser,
                            relativeFullScaleRadians: motionTuning.relativeFullScaleRadians
                        )
                        Divider()
                        LazyVStack(spacing: 0) {
                            signalRows(snapshot: snapshot, now: now)
                        }
                    }
                }
            }
        }
        .navigationTitle("Motion Debug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            #if os(iOS)
            reduceMotionActive = UIAccessibility.isReduceMotionEnabled
            #endif
            for await sample in service.debugSamples {
                viewModel.append(sample)
                let now = Date()
                gravityRebaser.process(sample: sample, now: now)
                relativeRebaser.process(quaternion: sample.rawQuaternion, now: now)
            }
        }
    }

    @ViewBuilder
    private func signalRows(
        snapshot: MotionDebugViewModel.Snapshot,
        now: Date
    ) -> some View {
        let window: TimeInterval = 10

        Group {
            // 1. Raw Euler
            row(
                "Raw Euler (rad)",
                snapshot: snapshot,
                now: now,
                window: window,
                yRange: -Double.pi ... Double.pi,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.rawEulerPitch }),
                    .init(label: "r", color: .green, value: { $0.rawEulerRoll }),
                    .init(label: "y", color: .blue,  value: { $0.rawEulerYaw })
                ]
            )

            // 2. Quaternion
            row(
                "Quaternion",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "x", color: .red,    value: { $0.rawQuaternion.x }),
                    .init(label: "y", color: .green,  value: { $0.rawQuaternion.y }),
                    .init(label: "z", color: .blue,   value: { $0.rawQuaternion.z }),
                    .init(label: "w", color: .orange, value: { $0.rawQuaternion.w })
                ]
            )

            // 3. Gravity
            row(
                "Gravity",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "x", color: .red,   value: { $0.gravity.x }),
                    .init(label: "y", color: .green, value: { $0.gravity.y }),
                    .init(label: "z", color: .blue,  value: { $0.gravity.z })
                ]
            )

            // 4. Normalized
            row(
                "Normalized",
                snapshot: snapshot, now: now, window: window,
                yRange: -2...2,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.normalizedPitch }),
                    .init(label: "r", color: .green, value: { $0.normalizedRoll })
                ]
            )

            // 5. Baseline-relative
            row(
                "Baseline-relative",
                snapshot: snapshot, now: now, window: window,
                yRange: -2...2,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.baselineRelative.pitch }),
                    .init(label: "r", color: .green, value: { $0.baselineRelative.roll })
                ]
            )

            // 6. Smoothed
            row(
                "Smoothed",
                snapshot: snapshot, now: now, window: window,
                yRange: -2...2,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.smoothed.pitch }),
                    .init(label: "r", color: .green, value: { $0.smoothed.roll })
                ]
            )

            // 7. Shaped (post-tanh)
            row(
                "Shaped (consumers)",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.shaped.pitch }),
                    .init(label: "r", color: .green, value: { $0.shaped.roll })
                ]
            )

            // 8. Throttled output (NaN-padded — falls back to shaped on dropped frames)
            row(
                "Throttled output",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.throttledOutput?.pitch ?? .nan }),
                    .init(label: "r", color: .green, value: { $0.throttledOutput?.roll ?? .nan })
                ]
            )
        }
    }

    @ViewBuilder
    private func row(
        _ title: String,
        snapshot: MotionDebugViewModel.Snapshot,
        now: Date,
        window: TimeInterval,
        yRange: ClosedRange<Double>,
        channels: [MotionDebugSparkline.Channel]
    ) -> some View {
        MotionDebugSignalRow(
            title: title,
            latest: snapshot.latest,
            samples: snapshot.samples,
            referenceTime: now,
            windowDuration: window,
            yRange: yRange,
            channels: channels
        )
        Divider()
    }
}
