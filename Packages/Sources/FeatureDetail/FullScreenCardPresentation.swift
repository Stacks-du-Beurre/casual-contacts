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
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    public let onDismissStarted: () -> Void
    public let onDismiss: () -> Void

    @State private var expanded = false
    @State private var dismissing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    public init(record: Record, sourceFrame: CGRect, attitude: DeviceAttitude,
                paths: any CardPathProvider, photo: Image?, photoSize: CGSize?,
                onEdit: @escaping () -> Void, onDelete: @escaping () -> Void,
                onDismissStarted: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.record = record
        self.sourceFrame = sourceFrame
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDismissStarted = onDismissStarted
        self.onDismiss = onDismiss
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
                                         progress: expanded ? 1 : 0)

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
                    .opacity(expanded ? 1 : 0)
                    .allowsHitTesting(expanded && !dismissing)
                }
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { dismiss() }
                .onAppear {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.45)) {
                        expanded = true
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func dismiss(then action: (() -> Void)? = nil) {
        guard !dismissing else { return }
        dismissing = true
        onDismissStarted()
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.45),
                      completionCriteria: .removed) {
            expanded = false
        } completion: {
            onDismiss()
            action?()
        }
    }
}

/// Interpolates the card's layout itself, rather than stretching a snapshot
/// of the destination. Its background stays mounted for both directions.
private struct ExpandingCardSurface: View, Animatable {
    let record: Record
    let attitude: DeviceAttitude
    let paths: any CardPathProvider
    let photo: Image?
    let photoSize: CGSize?
    let source: CGRect
    let destination: CGRect
    let safeArea: EdgeInsets
    var progress: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let frame = CGRect(
            x: source.minX + (destination.minX - source.minX) * progress,
            y: source.minY + (destination.minY - source.minY) * progress,
            width: source.width + (destination.width - source.width) * progress,
            height: source.height + (destination.height - source.height) * progress
        )
        CardView(record: record, size: .large, attitude: attitude, paths: paths,
                 photo: photo, photoSize: photoSize,
                 contentInsets: EdgeInsets(top: (safeArea.top + 68) * progress,
                                           leading: 24 * progress,
                                           bottom: (safeArea.bottom + 24) * progress,
                                           trailing: 24 * progress),
                 expansionProgress: progress)
            .frame(width: frame.width, height: frame.height)
            .environment(\.windowCardFrame, frame)
            .drawingGroup(opaque: false)
            .clipShape(RoundedRectangle(cornerRadius: 4 * (1 - progress)))
            .position(x: frame.midX - destination.minX, y: frame.midY - destination.minY)
    }
}
