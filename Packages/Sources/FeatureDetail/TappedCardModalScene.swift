import SwiftUI
import CoreModels
import DesignSystem
import Visuals

/// Custom overlay that animates a tapped card from its row position in the list
/// to screen center, then fades in a backdrop + bottom toolbar. Dismissal
/// reverses the sequence: backdrop fades out first, then the card slides back
/// to its origin row.
public struct TappedCardModalScene: View {

    public let record: Record
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

    @State private var cardAtCenter = false
    @State private var chromeVisible = false

    private static let slideDuration: Double = 0.38
    private static let chromeDuration: Double = 0.28
    private static let chromeStagger: Double = 0.18

    public var body: some View {
        #if os(iOS)
        // GeometryReader intentionally does NOT ignore safe area here — we
        // need `proxy.size` and the VStack/toolbar placement to respect the
        // home indicator. The backdrop Rectangle alone extends beyond via its
        // own `.ignoresSafeArea()`.
        GeometryReader { proxy in
            // `sourceFrame` was captured by the list in global (window) coords.
            // `.position` inside this GeometryReader uses proxy-local coords, so
            // translate global → local by subtracting the GeometryReader's
            // global origin (which equals the top safe-area inset).
            let origin = proxy.frame(in: .global).origin
            let sourceCenterLocal = CGPoint(
                x: sourceFrame.midX - origin.x,
                y: sourceFrame.midY - origin.y
            )
            let centeredLocal = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let cardCenter: CGPoint = cardAtCenter ? centeredLocal : sourceCenterLocal

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .opacity(chromeVisible ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { beginDismiss() }
                    .accessibilityIdentifier("tappedCardModalBackdrop")
                    .accessibilityLabel("Dismiss")
                    .accessibilityAddTraits(.isButton)

                CardView(
                    record: record,
                    size: .small,
                    attitude: attitude,
                    paths: paths,
                    photo: photo,
                    photoSize: photoSize
                )
                .frame(width: sourceFrame.width, height: sourceFrame.height)
                .drawingGroup(opaque: false)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .position(cardCenter)
                .contentShape(Rectangle())
                .onTapGesture { beginDismiss() }
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
                Text("EDIT")
                    .font(CCDesign.Typography.headline)
                    .tracking(CCDesign.Typography.Tracking.headline)
                    .foregroundStyle(Color.primary)
            }
            .accessibilityIdentifier("tappedCardModalEdit")

            Spacer()

            Button(role: .destructive) { beginDismiss(then: onDelete) } label: {
                Text("DELETE")
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
        withAnimation(.easeInOut(duration: Self.slideDuration)) {
            cardAtCenter = true
        }
        withAnimation(.easeOut(duration: Self.chromeDuration).delay(Self.chromeStagger)) {
            chromeVisible = true
        }
    }

    private func beginDismiss(then completion: (() -> Void)? = nil) {
        withAnimation(.easeIn(duration: Self.chromeDuration)) {
            chromeVisible = false
        }
        withAnimation(.easeInOut(duration: Self.slideDuration).delay(Self.chromeStagger)) {
            cardAtCenter = false
        }
        let total = Self.slideDuration + Self.chromeStagger
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            onDismiss()
            completion?()
        }
    }
    #endif
}
