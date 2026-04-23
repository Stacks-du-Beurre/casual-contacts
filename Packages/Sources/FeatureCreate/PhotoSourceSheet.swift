#if os(iOS)
import SwiftUI
import UIKit
import DesignSystem

/// Liquid-glass chooser presented when the user taps "+ Add Photo" in the
/// create flow. Two tiles: Camera (opens `UIImagePickerController`) and Photos
/// (hands control back to `PhotosPicker` at the call site). Styled after the
/// Messages app tray — a small-detent sheet with glass-surfaced tiles.
struct PhotoSourceSheet: View {

    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onCancel: () -> Void

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        HStack(spacing: 12) {
            tile(
                title: "Camera",
                systemImage: "camera.fill",
                isEnabled: cameraAvailable,
                action: onCamera
            )
            tile(
                title: "Photos",
                systemImage: "photo.on.rectangle.angled",
                isEnabled: true,
                action: onPhotos
            )
        }
        .padding(16)
        .presentationCompactAdaptation(.popover)
    }

    @ViewBuilder
    private func tile(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .regular))
                Text(title)
                    .font(CCDesign.Typography.caption2)
                    .tracking(CCDesign.Typography.Tracking.caption2)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(tileForeground(isEnabled: isEnabled))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    /// On iOS 26 the popover chrome is dark Liquid Glass, so pure white reads
    /// cleanly. On iOS 18 the system popover chrome is light-adaptive
    /// (translucent material that takes the system appearance), so `.primary`
    /// / `.secondary` will pick a legible color for both dark and light mode.
    private func tileForeground(isEnabled: Bool) -> AnyShapeStyle {
        if #available(iOS 26.0, *) {
            return isEnabled
                ? AnyShapeStyle(Color.white)
                : AnyShapeStyle(Color.white.opacity(0.5))
        } else {
            return isEnabled
                ? AnyShapeStyle(HierarchicalShapeStyle.primary)
                : AnyShapeStyle(HierarchicalShapeStyle.secondary)
        }
    }

}
#endif
