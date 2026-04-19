import SwiftUI
import CoreModels
import DesignSystem
import Visuals
#if os(iOS)
import PhotosUI
#endif

/// Editable form layer painted over the card backdrop: `+ Add Photo` button,
/// name pill (editable HologramText), description pill.
struct CreateFormOverlay<Backdrop: View>: View {

    @Bindable var model: CreateRecordModel
    var nameFocused: FocusState<Bool>.Binding
    let attitude: DeviceAttitude
    let backdropSize: CGSize
    let coordinateSpaceName: String
    @ViewBuilder let backdrop: () -> Backdrop

    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            addPhotoButton
                .padding(.bottom, 4)

            NamePill(
                model: model,
                focused: nameFocused,
                attitude: attitude,
                backdropSize: backdropSize,
                coordinateSpaceName: coordinateSpaceName,
                backdrop: backdrop
            )

            DescriptionPill(model: model)
        }
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var addPhotoButton: some View {
        #if os(iOS)
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            Text("+ Add Photo")
                .font(CCDesign.Typography.caption2)
                .foregroundStyle(CCDesign.Colors.L0)
        }
        .accessibilityIdentifier("addPhotoButton")
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    model.photoData = data
                }
            }
        }
        #else
        Text("+ Add Photo")
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(CCDesign.Colors.L0)
        #endif
    }
}

/// Holographic editable name pill. Stacks an invisible TextField over a
/// HologramText view — TextField owns input/focus/cursor, HologramText
/// owns the visual. Both bound to `model.name`; HologramText shows "Name"
/// when the model is empty, acting as a visible placeholder.
private struct NamePill<Backdrop: View>: View {
    @Bindable var model: CreateRecordModel
    var focused: FocusState<Bool>.Binding
    let attitude: DeviceAttitude
    let backdropSize: CGSize
    let coordinateSpaceName: String
    @ViewBuilder let backdrop: () -> Backdrop

    private static var nameFont: Font { .custom("CormorantSC-SemiBold", size: 48) }

    var body: some View {
        ZStack(alignment: .leading) {
            // Visual layer — the holographic rendering.
            HologramText(
                displayName,
                font: Self.nameFont,
                attitude: attitude,
                backdropSize: backdropSize,
                coordinateSpaceName: coordinateSpaceName,
                backdrop: backdrop
            )

            // Input layer — invisible TextField overlaid exactly on top.
            TextField("Name", text: $model.name)
                .font(Self.nameFont)
                .foregroundStyle(.clear)
                .tint(.black)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .focused(focused)
                .accessibilityIdentifier("nameField")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var displayName: String {
        model.name.isEmpty ? "Name" : model.name
    }
}

/// Glass-blur pill carrying the description `TextField`. Cormorant Infant
/// SemiBold 18. Plain TextField (no hologram treatment on description).
private struct DescriptionPill: View {
    @Bindable var model: CreateRecordModel

    var body: some View {
        TextField("Description", text: $model.description, axis: .horizontal)
            .font(CCDesign.Typography.description)
            .tracking(CCDesign.Typography.Tracking.description)
            .foregroundStyle(CCDesign.Colors.L0)
            .tint(CCDesign.Colors.L0)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.15))
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .accessibilityIdentifier("descriptionField")
            .fixedSize(horizontal: true, vertical: false)
    }
}
