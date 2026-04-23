import SwiftUI
import CoreModels
import DesignSystem
import Visuals
#if os(iOS)
import PhotosUI
#endif

/// Identifies the two text-editable fields on the Create form. Used for a
/// single `@FocusState` binding so the scene can save/restore which field was
/// in focus across picker presentations.
enum CreateFormField: Hashable {
    case name
    case description
}

/// Editable form layer painted over the card backdrop: `+ Add Photo` button,
/// name pill (editable HologramText), description pill.
struct CreateFormOverlay<Backdrop: View>: View {

    @Bindable var model: CreateRecordModel
    var formFocus: FocusState<CreateFormField?>.Binding
    let attitude: DeviceAttitude
    let backdropSize: CGSize
    let coordinateSpaceName: String
    @Binding var isPhotoChooserPresented: Bool
    let onPickCamera: () -> Void
    let onPickPhotos: () -> Void
    @Binding var isZodiacPickerPresented: Bool
    let onSelectZodiac: (ZodiacSign) -> Void
    @ViewBuilder let backdrop: () -> Backdrop

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            addPhotoButton
                .padding(.bottom, -14)

            NamePill(
                model: model,
                focus: formFocus,
                attitude: attitude,
                backdropSize: backdropSize,
                coordinateSpaceName: coordinateSpaceName,
                backdrop: backdrop
            )

            DescriptionPill(model: model, focus: formFocus)

            addZodiacButton
                .padding(.top, -2)
                .padding(.bottom, -6)
        }
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var addPhotoButton: some View {
        #if os(iOS)
        if model.isDetectingPhoto {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(CCDesign.Colors.L0)
                    .scaleEffect(0.7)
                Text("Analyzing photo…")
                    .font(CCDesign.Typography.caption2)
                    .foregroundStyle(CCDesign.Colors.L0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Analyzing photo")
            .accessibilityIdentifier("photoDetectingSpinner")
        } else {
            Button(action: { isPhotoChooserPresented = true }) {
                Text(model.photoData == nil ? "+ Add Photo" : "Change photo")
                    .font(CCDesign.Typography.caption2)
                    .foregroundStyle(CCDesign.Colors.L0)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 44, minHeight: 44, alignment: .topLeading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addPhotoButton")
            .popover(
                isPresented: $isPhotoChooserPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .leading
            ) {
                PhotoSourceSheet(
                    onCamera: onPickCamera,
                    onPhotos: onPickPhotos,
                    onCancel: { isPhotoChooserPresented = false }
                )
            }
        }
        #else
        Text("+ Add Photo")
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(CCDesign.Colors.L0)
        #endif
    }

    @ViewBuilder
    private var addZodiacButton: some View {
        #if os(iOS)
        Button(action: { isZodiacPickerPresented = true }) {
            Text("+ Add Zodiac")
                .font(CCDesign.Typography.caption2)
                .foregroundStyle(CCDesign.Colors.L0)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .frame(minWidth: 44, minHeight: 44, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addZodiacButton")
        .popover(
            isPresented: $isZodiacPickerPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .leading
        ) {
            ZodiacSheet(
                attitude: attitude,
                onSelect: onSelectZodiac,
                onClose: { isZodiacPickerPresented = false }
            )
        }
        #else
        Text("+ Add Zodiac")
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
    var focus: FocusState<CreateFormField?>.Binding
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
                .focused(focus, equals: .name)
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
    var focus: FocusState<CreateFormField?>.Binding

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
            .focused(focus, equals: .description)
            .accessibilityIdentifier("descriptionField")
            .fixedSize(horizontal: true, vertical: false)
    }
}
