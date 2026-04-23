import CoreModels
import Foundation

/// What `CreateRecordScene` emits via its `onSave` callback. The host
/// (AppFeature) dispatches on the case to call `RecordStore.create(...)` or
/// `RecordStore.update(...)`. The `.update` case carries the new photo bytes
/// (if any) so the host can detect a swap and clean up the old photo.
public enum CreateRecordOutcome: Sendable {
    case create(RecordDraft)
    case update(Record, photoData: Data?, photoFocus: NormalizedPoint?)
}
