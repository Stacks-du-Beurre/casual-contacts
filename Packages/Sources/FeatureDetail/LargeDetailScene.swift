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
    public let faceTrackingEnabled: Bool
    public let faceTrackingStatus: String
    public let onToggleFaceTracking: (() -> Void)?
    public let onRecenterFaceTracking: (() -> Void)?
    @Environment(\.locale) private var locale

    public init(
        record: Record,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil,
        photoSize: CGSize? = nil,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        faceTrackingEnabled: Bool = false,
        faceTrackingStatus: String = "Face parallax off",
        onToggleFaceTracking: (() -> Void)? = nil,
        onRecenterFaceTracking: (() -> Void)? = nil
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        self.faceTrackingEnabled = faceTrackingEnabled
        self.faceTrackingStatus = faceTrackingStatus
        self.onToggleFaceTracking = onToggleFaceTracking
        self.onRecenterFaceTracking = onRecenterFaceTracking
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
                            if let onToggleFaceTracking {
                                Button(faceTrackingEnabled ? "Turn off face parallax" : "Turn on face parallax",
                                       systemImage: "faceid", action: onToggleFaceTracking)
                                if faceTrackingEnabled {
                                    Text(faceTrackingStatus)
                                    if let onRecenterFaceTracking {
                                        Button("Recenter face parallax", systemImage: "scope",
                                               action: onRecenterFaceTracking)
                                    }
                                }
                                Divider()
                            }
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
