#if os(iOS)
import SwiftUI
import UIKit
import DesignSystem
import Foundation

/// Liquid-glass chooser presented when the user taps "+ Add Photo" in the
/// create flow. Two tiles: Camera (opens `UIImagePickerController`) and Photos
/// (hands control back to `PhotosPicker` at the call site). Styled after the
/// Messages app tray — a small-detent sheet with glass-surfaced tiles.
struct PhotoSourceSheet: View {

    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onCancel: () -> Void
    @Environment(\.locale) private var locale

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        HStack(spacing: 12) {
            tile(
                title: ModuleLocalization.string("Camera", locale: locale),
                systemImage: "camera.fill",
                isEnabled: cameraAvailable,
                action: onCamera
            )
            tile(
                title: ModuleLocalization.string("Photo Library", locale: locale),
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

    /// Popover chrome (Liquid Glass on iOS 26, translucent material on iOS 18)
    /// is light in light mode and dark in dark mode. Using the UIKit dynamic
    /// `label` / `secondaryLabel` colors ensures the foreground tracks the
    /// system appearance even when SwiftUI's environment `colorScheme` inside
    /// the popover is not updated by the presenting chrome.
    private func tileForeground(isEnabled: Bool) -> AnyShapeStyle {
        isEnabled
            ? AnyShapeStyle(Color(uiColor: .label))
            : AnyShapeStyle(Color(uiColor: .secondaryLabel))
    }

}
#endif
