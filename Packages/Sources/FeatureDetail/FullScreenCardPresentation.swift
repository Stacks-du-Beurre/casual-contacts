import CoreModels
import DesignSystem
import SwiftUI
import Visuals

/// Expands the tapped card in place, without a separate modal presentation.
public struct FullScreenCardPresentation: View {
    public let record: Record
    public let sourceFrame: CGRect
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?
    public let photoSize: CGSize?
    public let sourceUsesWindowScene: Bool
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    public let onDismissStarted: () -> Void
    public let onDismiss: () -> Void
    public let onDismissCancelled: () -> Void

    @State private var progress: CGFloat = 0
    @State private var ready = false
    @State private var dragging = false
    @State private var returning = false
    @GestureState private var dragActive = false
    @State private var dismissing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    public init(record: Record, sourceFrame: CGRect, attitude: DeviceAttitude,
                paths: any CardPathProvider, photo: Image?, photoSize: CGSize?,
                onEdit: @escaping () -> Void, onDelete: @escaping () -> Void,
                onDismissStarted: @escaping () -> Void, onDismiss: @escaping () -> Void,
                sourceUsesWindowScene: Bool = true,
                onDismissCancelled: @escaping () -> Void = {}) {
        self.record = record
        self.sourceFrame = sourceFrame
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.sourceUsesWindowScene = sourceUsesWindowScene
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDismissStarted = onDismissStarted
        self.onDismiss = onDismiss
        self.onDismissCancelled = onDismissCancelled
    }

    public var body: some View {
        GeometryReader { safeGeometry in
            GeometryReader { geometry in
                let fullFrame = geometry.frame(in: .global)
                let start = sourceFrame.isEmpty ? fullFrame : sourceFrame
                ZStack(alignment: .top) {
                    ExpandingCardSurface(record: record, attitude: attitude, paths: paths,
                                         photo: photo, photoSize: photoSize,
                                         source: reduceMotion ? fullFrame : start, destination: fullFrame,
                                         safeArea: safeGeometry.safeAreaInsets,
                                         sourceUsesWindowScene: sourceUsesWindowScene,
                                         progress: progress)
                        .contentShape(Rectangle())
                        .gesture(dismissDrag(height: fullFrame.height))

                    HStack {
                        Button(ModuleLocalization.string("Done", locale: locale)) { dismiss() }
                            .accessibilityIdentifier("fullScreenCardDone")
                        Spacer()
                        Menu {
                            Button(ModuleLocalization.string("Edit", locale: locale)) { dismiss(then: onEdit) }
                            Button(role: .destructive) { dismiss(then: onDelete) } label: {
                                ModuleLocalization.text("Delete", locale: locale)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(minWidth: 24)
                        }
                        .accessibilityIdentifier("fullScreenCardActions")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(.white.opacity(0.8))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.top, safeGeometry.safeAreaInsets.top + 8)
                    .opacity(progress)
                    .allowsHitTesting(ready && !dragging && !returning && !dismissing)
                }
                .onChange(of: dragActive) { _, active in
                    if !active && dragging && !dismissing { cancelDrag() }
                }
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { dismiss() }
                .task {
                    #if DEBUG && os(iOS)
                    guard TransitionMotionMetrics.isEnabled else { return }
                    do { try await Task.sleep(for: .seconds(2)) }
                    catch { return }
                    dismiss()
                    #endif
                }
                .onAppear {
                    #if os(iOS)
                    PerformanceDiagnostics.shared.setContext("fullscreen_enter")
                    PerformanceDiagnostics.shared.beginTransition("enter", hasPhoto: photo != nil)
                    #endif
                    #if DEBUG && os(iOS)
                    TransitionMotionMetrics.shared.begin("enter")
                    #endif
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.45),
                                  completionCriteria: .removed) {
                        progress = 1
                    } completion: {
                        ready = true
                        #if os(iOS)
                        PerformanceDiagnostics.shared.endTransition("enter")
                        PerformanceDiagnostics.shared.setContext("fullscreen")
                        #endif
                        #if DEBUG && os(iOS)
                        TransitionMotionMetrics.shared.end()
                        #endif
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func beginDismissal() {
        onDismissStarted()
        #if os(iOS)
        PerformanceDiagnostics.shared.setContext("fullscreen_exit")
        PerformanceDiagnostics.shared.beginTransition("exit", hasPhoto: photo != nil)
        #endif
        #if DEBUG && os(iOS)
        TransitionMotionMetrics.shared.begin("exit")
        #endif
    }

    private func dismissDrag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragActive) { _, active, _ in active = true }
            .onChanged { value in
                guard ready, !dismissing, !returning else { return }
                if !dragging {
                    guard value.translation.height > abs(value.translation.width) else { return }
                    dragging = true
                    beginDismissal()
                }
                // Finger updates own progress directly, without queued animations.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    progress = CardDismissDrag.progress(translation: value.translation.height, height: height)
                }
            }
            .onEnded { value in
                guard dragging, !dismissing else { return }
                if CardDismissDrag.shouldFinish(translation: value.translation.height,
                                                predicted: value.predictedEndTranslation.height, height: height) {
                    dismiss()
                } else {
                    cancelDrag()
                }
            }
    }

    private func cancelDrag() {
        guard dragging, !returning, !dismissing else { return }
        dragging = false
        returning = true
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.3),
                      completionCriteria: .removed) {
            progress = 1
        } completion: {
            returning = false
            onDismissCancelled()
            #if os(iOS)
            PerformanceDiagnostics.shared.endTransition("exit")
            PerformanceDiagnostics.shared.event("interactive_exit_cancelled")
            PerformanceDiagnostics.shared.setContext("fullscreen")
            #endif
        }
    }

    private func dismiss(then action: (() -> Void)? = nil) {
        guard !dismissing else { return }
        dismissing = true
        if !dragging { beginDismissal() }
        dragging = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.45),
                      completionCriteria: .removed) {
            progress = 0
        } completion: {
            #if os(iOS)
            PerformanceDiagnostics.shared.endTransition("exit")
            PerformanceDiagnostics.shared.setContext("list")
            #endif
            #if DEBUG && os(iOS)
            TransitionMotionMetrics.shared.end()
            #endif
            onDismiss()
            action?()
        }
    }
}

/// Interpolates the card's layout itself, rather than stretching a snapshot
/// of the destination. Its background stays mounted for both directions.
private struct ExpandingCardSurface: View {
    let record: Record
    let attitude: DeviceAttitude
    let paths: any CardPathProvider
    let photo: Image?
    let photoSize: CGSize?
    let source: CGRect
    let destination: CGRect
    let safeArea: EdgeInsets
    let sourceUsesWindowScene: Bool
    var progress: CGFloat

    var body: some View {
        CardView(record: record, size: .large, attitude: attitude, paths: paths,
                 photo: photo, photoSize: photoSize)
            .modifier(CardExpansionGeometry(source: source, destination: destination,
                                            safeArea: safeArea, sourceUsesWindowScene: sourceUsesWindowScene,
                                            progress: progress))
    }
}

/// Only geometry belongs to the animation. Camera/gyro inputs remain in the
/// ordinary CardView above, outside the interpolator's stored values.
private struct CardExpansionGeometry: AnimatableModifier {
    let source: CGRect
    let destination: CGRect
    let safeArea: EdgeInsets
    let sourceUsesWindowScene: Bool
    @Environment(\.windowSceneProjection) private var scene
    var progress: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let frame = CGRect(
            x: source.minX + (destination.minX - source.minX) * progress,
            y: source.minY + (destination.minY - source.minY) * progress,
            width: source.width + (destination.width - source.width) * progress,
            height: source.height + (destination.height - source.height) * progress
        )
        content
            .cardExpansionLayout(
                progress: progress,
                insets: EdgeInsets(top: (safeArea.top + 68) * progress,
                                   leading: 24 * progress,
                                   bottom: (safeArea.bottom + 24) * progress,
                                   trailing: 24 * progress)
            )
            .frame(width: frame.width, height: frame.height)
            .environment(\.photoFramingSize, source.size)
            .environment(\.windowCardFrame, frame)
            .environment(\.windowSceneProjection, scene?.expanding(progress: Double(progress),
                                                                  sourceUsesWindowScene: sourceUsesWindowScene))
            .clipShape(RoundedRectangle(cornerRadius: 4 * (1 - progress)))
            .position(x: frame.midX - destination.minX, y: frame.midY - destination.minY)
    }
}

/// Shared gesture thresholds, expressed relative to the screen height.
enum CardDismissDrag {
    static func travel(height: CGFloat) -> CGFloat { max(260, height * 0.65) }
    static func progress(translation: CGFloat, height: CGFloat) -> CGFloat {
        1 - min(1, max(0, translation / travel(height: height)))
    }
    static func shouldFinish(translation: CGFloat, predicted: CGFloat, height: CGFloat) -> Bool {
        translation >= travel(height: height) * 0.25 ||
            (translation > 24 && predicted >= travel(height: height) * 0.45)
    }
}
