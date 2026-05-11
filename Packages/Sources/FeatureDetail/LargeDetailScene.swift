import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct LargeDetailScene: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?
    public let photoSize: CGSize?
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
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            CardView(
                record: record,
                size: .large,
                attitude: attitude,
                paths: paths,
                photo: photo,
                photoSize: photoSize
            )
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.accessibilityLabel(for: record))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(ModuleLocalization.string("Done", locale: locale), action: onDismiss)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(ModuleLocalization.string("Edit", locale: locale), action: onEdit)
                            Button(role: .destructive, action: onDelete) {
                                ModuleLocalization.text("Delete", locale: locale)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button(ModuleLocalization.string("Done", locale: locale), action: onDismiss)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(ModuleLocalization.string("Edit", locale: locale), action: onEdit)
                            Button(role: .destructive, action: onDelete) {
                                ModuleLocalization.text("Delete", locale: locale)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                    #endif
                }
        }
    }

    public static func accessibilityLabel(for record: Record) -> String {
        var parts: [String] = [record.name]
        if !record.description.isEmpty { parts.append(record.description) }
        if let label = record.location?.label { parts.append(label) }
        return parts.joined(separator: ". ")
    }
}
