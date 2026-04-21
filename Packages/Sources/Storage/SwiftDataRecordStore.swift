import Foundation
import SwiftData
import CoreModels
import Observation

@MainActor
@Observable
public final class SwiftDataRecordStore: RecordStore {

    private let container: ModelContainer
    private let context: ModelContext
    public private(set) var records: [Record] = []

    public init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        reload()
    }

    // MARK: - RecordStore

    public func create(_ draft: RecordDraft, metadata: RecordMetadata, photoID: PhotoID?) async throws -> Record {
        let now = Date()
        let newID = UUID()
        let shape = draft.guillocheShape ?? .deterministic(for: newID)
        let persisted = PersistedRecord(
            id: newID,
            name: draft.name,
            recordDescription: draft.description,
            photoFilename: photoID?.filename,
            latitude: draft.location?.latitude,
            longitude: draft.location?.longitude,
            locationLabel: draft.location?.label,
            zodiacSignRaw: draft.zodiacSign?.rawValue,
            createdAt: now,
            updatedAt: now,
            timeOfDayRaw: metadata.timeOfDay.rawValue,
            moonPhaseRaw: metadata.moonPhase.rawValue,
            guillocheShapeRaw: shape.rawValue
        )
        context.insert(persisted)
        do {
            try context.save()
        } catch {
            throw RecordStoreError.saveFailed(reason: String(describing: error))
        }
        reload()
        guard let created = records.first(where: { $0.id == persisted.id }) else {
            throw RecordStoreError.saveFailed(reason: "record missing after insert")
        }
        return created
    }

    public func update(_ record: Record) async throws {
        let id = record.id
        var descriptor = FetchDescriptor<PersistedRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1

        guard let persisted = try context.fetch(descriptor).first else {
            throw RecordStoreError.notFound(id)
        }
        persisted.name = record.name
        persisted.recordDescription = record.description
        persisted.photoFilename = record.photoID?.filename
        persisted.latitude = record.location?.latitude
        persisted.longitude = record.location?.longitude
        persisted.locationLabel = record.location?.label
        persisted.zodiacSignRaw = record.zodiacSign?.rawValue
        persisted.guillocheShapeRaw = record.guillocheShape.rawValue
        persisted.updatedAt = Date()
        do {
            try context.save()
        } catch {
            throw RecordStoreError.saveFailed(reason: String(describing: error))
        }
        reload()
    }

    public func delete(id: Record.ID) async throws {
        var descriptor = FetchDescriptor<PersistedRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let persisted = try context.fetch(descriptor).first else {
            throw RecordStoreError.notFound(id)
        }
        context.delete(persisted)
        try context.save()
        reload()
    }

    public func search(_ query: String) -> [Record] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return records }
        let lowered = trimmed.lowercased()
        return records.filter { $0.name.lowercased().contains(lowered) }
    }

    // MARK: - Private

    private func reload() {
        let descriptor = FetchDescriptor<PersistedRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let persistedList = (try? context.fetch(descriptor)) ?? []
        records = persistedList.map(Record.init(persisted:))
    }
}

// MARK: - Mapping

extension Record {
    init(persisted: PersistedRecord) {
        let location: LocationInfo? = {
            guard let lat = persisted.latitude, let lon = persisted.longitude else { return nil }
            return LocationInfo(latitude: lat, longitude: lon, label: persisted.locationLabel)
        }()
        let shape = persisted.guillocheShapeRaw.flatMap(GuillocheShape.init(rawValue:))
            ?? .deterministic(for: persisted.id)
        self.init(
            id: persisted.id,
            name: persisted.name,
            description: persisted.recordDescription,
            photoID: persisted.photoFilename.map(PhotoID.init(filename:)),
            location: location,
            zodiacSign: persisted.zodiacSignRaw.flatMap(ZodiacSign.init(rawValue:)),
            createdAt: persisted.createdAt,
            updatedAt: persisted.updatedAt,
            metadata: RecordMetadata(
                timeOfDay: TimeOfDay(rawValue: persisted.timeOfDayRaw) ?? .midday,
                moonPhase: MoonPhase(rawValue: persisted.moonPhaseRaw) ?? .fullMoon
            ),
            guillocheShape: shape
        )
    }
}
