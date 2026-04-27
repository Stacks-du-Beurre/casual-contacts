#if DEBUG
import SwiftUI
import CoreModels
import DesignSystem
import Visuals

/// Diagnostic gallery showing every (letter, shape) blended-letter card —
/// 26 letters × 3 `GuillocheShape` variants = 78 cards. Used to verify each
/// SVG renders, layers in the right order, and animates the right direction.
/// Reachable from Settings → Developer → "Letter gallery" in DEBUG builds.
@MainActor
struct DebugLetterGalleryScene: View {

    let paths: any CardPathProvider
    let attitude: DeviceAttitude
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    private let records: [Record] = DebugRecordSeeder.letterGalleryRecords

    private var background: Color {
        scheme == .dark ? CCDesign.Colors.D3 : CCDesign.Colors.L2
    }

    private var chromePrimary: Color {
        scheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }

    private var chromeAccent: Color {
        scheme == .dark ? CCDesign.Colors.D4 : CCDesign.Colors.L2
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(records) { record in
                        CardView(
                            record: record,
                            size: .small,
                            attitude: attitude,
                            paths: paths
                        )
                        .frame(height: 211)
                        .drawingGroup(opaque: false)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }

            // Floating close button — outside the inset so it overlays the
            // header content instead of being inset by it.
        }
    }

    private var header: some View {
        ZStack {
            Text("LETTER GALLERY")
                .font(.custom("CormorantSC-Bold", size: 17, relativeTo: .headline))
                .tracking(CCDesign.Typography.Tracking.headline)
                .foregroundStyle(chromePrimary)

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(chromeAccent)
                        .frame(width: 32, height: 32)
                        .background(chromePrimary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .padding(.trailing, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(background.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(scheme == .dark ? CCDesign.Colors.D0 : CCDesign.Colors.L3)
                .frame(height: 0.5)
        }
    }
}
#endif
