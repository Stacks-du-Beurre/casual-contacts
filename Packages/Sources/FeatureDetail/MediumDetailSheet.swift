import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct MediumDetailSheet: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?
    public let photoSize: CGSize?
    public let onExpand: () -> Void
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    public let onDismiss: () -> Void
    @Environment(\.locale) private var locale

    public init(
        record: Record,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil,
        photoSize: CGSize? = nil,
        onExpand: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.onExpand = onExpand
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            CardView(
                record: record,
                size: .medium,
                attitude: attitude,
                paths: paths,
                photo: photo,
                photoSize: photoSize
            )
                .aspectRatio(16.0/10.0, contentMode: .fit)
                .accessibilityHidden(true)

            Text(Self.accessibilityLabel(for: record))
                .font(.body)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 16) {
                Button(ModuleLocalization.string("Expand", locale: locale), action: onExpand)
                Button(ModuleLocalization.string("Edit", locale: locale), action: onEdit)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    ModuleLocalization.text("Delete", locale: locale)
                }
            }
            .padding()
        }
        #if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        #endif
    }

    public static func accessibilityLabel(for record: Record) -> String {
        var parts: [String] = [record.name]
        if !record.description.isEmpty { parts.append(record.description) }
        if let label = record.location?.label { parts.append(label) }
        return parts.joined(separator: ". ")
    }
}
