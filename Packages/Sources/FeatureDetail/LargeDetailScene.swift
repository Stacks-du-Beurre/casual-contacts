import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct LargeDetailScene: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    public let onDismiss: () -> Void

    public init(
        record: Record,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            CardView(record: record, size: .large, attitude: attitude, paths: paths)
                .ignoresSafeArea()
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done", action: onDismiss)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit", action: onEdit)
                            Button(role: .destructive, action: onDelete) {
                                Text("Delete")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: onDismiss)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Edit", action: onEdit)
                            Button(role: .destructive, action: onDelete) {
                                Text("Delete")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                    #endif
                }
        }
    }
}
