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

    /// Captured at the presenter so the zodiac popover can pick the right
    /// Moon_Background asset — SwiftUI's `colorScheme` environment is forced
    /// dark inside popover content and can't be relied on there.
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

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

            DescriptionPill(
                model: model,
                focus: formFocus,
                maxWidth: backdropSize.width * 0.75
            )

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
                ModuleLocalization.text("Analyzing photo…", locale: locale)
                    .font(CCDesign.Typography.caption2)
                    .foregroundStyle(CCDesign.Colors.L0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(ModuleLocalization.text("Analyzing photo", locale: locale))
            .accessibilityIdentifier("photoDetectingSpinner")
        } else {
            Button(action: { isPhotoChooserPresented = true }) {
                Text(
                    Self.photoButtonLabel(hasPhoto: model.photoData != nil, locale: locale)
                )
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
        ModuleLocalization.text("+ Add Photo", locale: locale)
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(CCDesign.Colors.L0)
        #endif
    }

    @ViewBuilder
    private var addZodiacButton: some View {
        #if os(iOS)
        Button(action: { isZodiacPickerPresented = true }) {
            Text(zodiacButtonLabel)
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
                isLightAppearance: colorScheme == .light,
                onSelect: onSelectZodiac,
                onClose: { isZodiacPickerPresented = false }
            )
        }
        #else
        Text(zodiacButtonLabel)
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(CCDesign.Colors.L0)
        #endif
    }

    private var zodiacButtonLabel: String {
        Self.zodiacButtonLabel(for: model.zodiacSign, locale: locale)
    }

    static func photoButtonLabel(hasPhoto: Bool, locale: Locale) -> String {
        hasPhoto
            ? ModuleLocalization.string("Change photo", locale: locale)
            : ModuleLocalization.string("+ Add Photo", locale: locale)
    }

    static func zodiacButtonLabel(for sign: ZodiacSign?, locale: Locale) -> String {
        guard let sign else {
            return ModuleLocalization.string("+ Add Zodiac", locale: locale)
        }
        return ModuleLocalization.string(
            "Change zodiac - %@",
            locale: locale,
            ModuleLocalization.zodiacDisplayName(sign, locale: locale)
        )
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
    @Environment(\.locale) private var locale

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
            TextField(ModuleLocalization.string("Name", locale: locale), text: $model.name, axis: .vertical)
                .font(Self.nameFont)
                .foregroundStyle(.clear)
                .tint(.black)
                .textFieldStyle(.plain)
                .lineLimit(2, reservesSpace: false)
                .padding(.horizontal, 6)
                .focused(focus, equals: .name)
                .accessibilityIdentifier("nameField")
        }
        .frame(maxWidth: max(0, backdropSize.width - 32 - 60), alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var displayName: String {
        model.name.isEmpty ? ModuleLocalization.string("Name", locale: locale) : model.name
    }
}

/// Preference key carrying the description text's natural single-line width.
/// Used by `DescriptionPill` to size the TextField to fit its content,
/// capped at the cap derived from the form overlay's width.
private struct DescriptionNaturalWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Glass-blur pill carrying the description `TextField`. Cormorant Infant
/// SemiBold 18. Plain TextField (no hologram treatment on description).
///
/// Width behavior: the pill hugs its content up to `maxWidth` (75% of the
/// form overlay's width), then the TextField wraps to additional lines.
/// `TextField(axis: .vertical)` always fills the available width, so we
/// measure the text's natural single-line width with a hidden `Text` sizer
/// (published via preference) and apply that width — clamped to the cap —
/// as an explicit frame on the field.
private struct DescriptionPill: View {
    @Bindable var model: CreateRecordModel
    var focus: FocusState<CreateFormField?>.Binding
    let maxWidth: CGFloat

    @State private var naturalWidth: CGFloat = 0
    @Environment(\.locale) private var locale

    private static let horizontalPadding: CGFloat = 16
    /// Cushion added to the measured `Text` width before sizing the
    /// `TextField`. UITextField uses an internal NSTextContainer with line
    /// fragment padding (~5pt each side) plus space for the caret; without
    /// the cushion, content that fits the bare `Text` sizer would prematurely
    /// wrap inside the live field.
    private static let editingCushion: CGFloat = 18

    var body: some View {
        let displayText = model.description.isEmpty
            ? ModuleLocalization.string("Description", locale: locale)
            : model.description
        let cap = max(0, maxWidth - Self.horizontalPadding * 2)
        let fieldWidth = min(max(naturalWidth + Self.editingCushion, 0), cap)

        TextField(
            ModuleLocalization.string("Description", locale: locale),
            text: $model.description,
            prompt: ModuleLocalization.text("Description", locale: locale).foregroundStyle(CCDesign.Colors.L0),
            axis: .vertical
        )
        .lineLimit(1...)
        .font(CCDesign.Typography.description)
        .tracking(CCDesign.Typography.Tracking.description)
        .foregroundStyle(CCDesign.Colors.L0)
        .tint(CCDesign.Colors.L0)
        .textFieldStyle(.plain)
        .frame(width: fieldWidth, alignment: .leading)
        .background(alignment: .leading) {
            // Sizer: a hidden, single-line Text rendered in the background so
            // it doesn't take layout space, but reports its natural width via
            // preference. `fixedSize` lets the Text exceed the host's clipped
            // bounds horizontally so we always learn its true ideal width.
            Text(displayText)
                .font(CCDesign.Typography.description)
                .tracking(CCDesign.Typography.Tracking.description)
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .accessibilityHidden(true)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: DescriptionNaturalWidthKey.self,
                            value: geo.size.width
                        )
                    }
                )
        }
        .onPreferenceChange(DescriptionNaturalWidthKey.self) { naturalWidth = $0 }
        .focused(focus, equals: .description)
        .accessibilityIdentifier("descriptionField")
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.15))
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }
}
