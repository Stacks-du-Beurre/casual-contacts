import SwiftUI
import CoreModels
import Visuals

public struct SmallCardListItem: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider

    public init(record: Record, attitude: DeviceAttitude, paths: any CardPathProvider) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
    }

    public var body: some View {
        CardView(record: record, size: .small, attitude: attitude, paths: paths)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .accessibilityLabel(Self.accessibilityLabel(for: record))
    }

    static func accessibilityLabel(for record: Record) -> String {
        var parts: [String] = [record.name]
        if !record.description.isEmpty { parts.append(record.description) }
        if let label = record.location?.label { parts.append(label) }
        return parts.joined(separator: ". ")
    }
}
