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
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

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
            .padding(.horizontal, 16)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(glassBackground)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }

    @ViewBuilder
    private func tile(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .regular))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(glassBackground)
        }
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}
#endif
