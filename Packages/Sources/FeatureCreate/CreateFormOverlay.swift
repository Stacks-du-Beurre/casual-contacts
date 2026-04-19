import SwiftUI
import DesignSystem
import Visuals
#if os(iOS)
import PhotosUI
#endif

/// Editable form layer painted over the card backdrop: `+ Add Photo` button,
/// name `TextField` pill, description `TextField` pill. All three left-aligned
/// at 8pt from the card edge, stacked vertically.
struct CreateFormOverlay: View {

    @Bindable var model: CreateRecordModel

    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            addPhotoButton
            NamePill(model: model)
            DescriptionPill(model: model)
        }
        .padding(.leading, 8)
        .padding(.top, 130)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

/// White/luminosity-blend pill carrying the name `TextField`. Cormorant SC
/// SemiBold 48. Placeholder uses SwiftUI's default secondary color — the
/// luminosity blend behind the pill produces the muted look Figma shows.
private struct NamePill: View {
    @Bindable var model: CreateRecordModel

    var body: some View {
        TextField("Name", text: $model.name)
            .font(.custom("CormorantSC-SemiBold", size: 48))
            .foregroundStyle(.black)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(Color.white.opacity(0.56))
            .accessibilityIdentifier("nameField")
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Glass-blur pill carrying the description `TextField`. Cormorant Infant
/// SemiBold 18.
private struct DescriptionPill: View {
    @Bindable var model: CreateRecordModel

    var body: some View {
        TextField("Description", text: $model.description, axis: .horizontal)
            .font(CCDesign.Typography.description)
            .tracking(CCDesign.Typography.Tracking.description)
            .foregroundStyle(CCDesign.Colors.L0)
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
