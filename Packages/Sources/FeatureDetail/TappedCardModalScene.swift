import SwiftUI
import CoreModels
import DesignSystem
import Visuals

/// Custom overlay that immediately places the list under blur, then slides the
/// tapped card up from below the viewport. The presented card dismisses through
/// a downward drag gesture or by tapping the blurred backdrop.
public struct TappedCardModalScene: View {

    public let record: Record
    /// Retained for the existing list-to-root API. The new presentation no
    /// longer uses the source frame for card geometry; the original row stays
    /// visible beneath the immediate blur while the sheet card enters from below.
    public let sourceFrame: CGRect
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?
    public let photoSize: CGSize?
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    public let onDismiss: () -> Void

    public init(
        record: Record,
        sourceFrame: CGRect,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil,
        photoSize: CGSize? = nil,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.record = record
        self.sourceFrame = sourceFrame
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDismiss = onDismiss
    }

    @State private var cardVisible = false
    @State private var chromeVisible = false
    @State private var dragTranslation: CGFloat = 0
    @State private var dismissalCommitting = false
    @Bindable private var sizeTuning = MediumCardSizeTuning.shared
    @Environment(\.locale) private var locale

    private static let slideDuration: Double = 0.42
    private static let chromeDuration: Double = 0.28
    private static let chromeStagger: Double = 0.1

    public var body: some View {
        #if os(iOS)
        // GeometryReader intentionally does NOT ignore safe area here — we
        // need `proxy.size` and the VStack/toolbar placement to respect the
        // home indicator. The backdrop Rectangle alone extends beyond via its
        // own `.ignoresSafeArea()`.
        GeometryReader { proxy in
            let centeredLocal = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            // Presented card matches the list row's horizontal footprint
            // (parent list uses 16pt side padding, so width = proxy.width - 32)
            // and grows vertically into the available scene height minus room
            // for the bottom toolbar. Height is driven by the user-tunable
            // `aspectRatio` (height ÷ width), then capped to available space.
            let centeredWidth = max(0, proxy.size.width - 32)
            let availableHeight = max(0, proxy.size.height - 200)
            let centeredHeight = min(centeredWidth * sizeTuning.aspectRatio, availableHeight)
            let cardSize = CGSize(width: centeredWidth, height: centeredHeight)
            let interactionMetrics = TappedCardModalInteraction.Metrics(
                containerHeight: proxy.size.height,
                cardHeight: cardSize.height
            )
            let cardOffset = cardVisible
                ? TappedCardModalInteraction.visibleOffset(dragTranslation: dragTranslation)
                : TappedCardModalInteraction.hiddenOffset(for: interactionMetrics)

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .opacity(TappedCardModalInteraction.backdropOpacity(
                        isDismissalCommitting: dismissalCommitting
                    ))
                    .contentShape(Rectangle())
                    .onTapGesture { beginDismiss() }
                    .accessibilityIdentifier("tappedCardModalBackdrop")
                    .accessibilityLabel(ModuleLocalization.text("Dismiss", locale: locale))
                    .accessibilityAddTraits(.isButton)

                CardView(
                    record: record,
                    size: .medium,
                    attitude: attitude,
                    paths: paths,
                    photo: photo,
                    photoSize: photoSize
                )
                .frame(width: cardSize.width, height: cardSize.height)
                .drawingGroup(opaque: false)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .position(centeredLocal)
                .offset(y: cardOffset)
                .contentShape(Rectangle())
                .gesture(dismissDragGesture(metrics: interactionMetrics))
                .accessibilityAction(.escape) { beginDismiss() }
                .accessibilityIdentifier("tappedCardModalCard")

                VStack {
                    Spacer()
                    toolbar
                        .opacity(chromeVisible ? 1 : 0)
                }
            }
            .onAppear(perform: beginPresent)
        }
        #else
        EmptyView()
        #endif
    }

    #if os(iOS)
    private var toolbar: some View {
        HStack {
            Button { beginDismiss(then: onEdit) } label: {
                ModuleLocalization.text("EDIT", locale: locale)
                    .font(CCDesign.Typography.headline)
                    .tracking(CCDesign.Typography.Tracking.headline)
                    .foregroundStyle(Color.primary)
            }
            .accessibilityIdentifier("tappedCardModalEdit")

            Spacer()

            Button(role: .destructive) { beginDismiss(then: onDelete) } label: {
                ModuleLocalization.text("DELETE", locale: locale)
                    .font(CCDesign.Typography.headline)
                    .tracking(CCDesign.Typography.Tracking.headline)
            }
            .accessibilityIdentifier("tappedCardModalDelete")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func beginPresent() {
        dismissalCommitting = false
        dragTranslation = 0
        withAnimation(.interactiveSpring(response: Self.slideDuration, dampingFraction: 0.88)) {
            cardVisible = true
        }
        withAnimation(.easeOut(duration: Self.chromeDuration).delay(Self.chromeStagger)) {
            chromeVisible = true
        }
    }

    private func beginDismiss(then completion: (() -> Void)? = nil) {
        guard !dismissalCommitting else { return }
        dismissalCommitting = true
        withAnimation(.easeIn(duration: Self.chromeDuration)) {
            chromeVisible = false
        }
        withAnimation(.interactiveSpring(response: Self.slideDuration, dampingFraction: 0.9)) {
            dragTranslation = 0
            cardVisible = false
        }
        let total = Self.slideDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            onDismiss()
            completion?()
        }
    }

    private func dismissDragGesture(
        metrics: TappedCardModalInteraction.Metrics
    ) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                dragTranslation = TappedCardModalInteraction.visibleOffset(
                    dragTranslation: value.translation.height
                )
            }
            .onEnded { value in
                let shouldDismiss = TappedCardModalInteraction.shouldDismiss(
                    dragTranslation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height,
                    metrics: metrics
                )
                if shouldDismiss {
                    beginDismiss()
                } else {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82)) {
                        dragTranslation = 0
                    }
                }
            }
    }
    #endif
}
