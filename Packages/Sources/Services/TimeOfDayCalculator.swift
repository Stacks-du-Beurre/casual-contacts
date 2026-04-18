import Foundation
import CoreModels

public enum TimeOfDayCalculator {

    /// Bucket the date's wall-clock hour (in `timeZone`) into a TimeOfDay category.
    /// Plan 1 uses a coarse hour-of-day mapping independent of geographic location;
    /// refinement to true solar angles using CoreLocation is future work.
    public static func category(at date: Date, timeZone: String) -> TimeOfDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? TimeZone(secondsFromGMT: 0)!
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 0...3:   return .midnight
        case 4...5:   return .dawn
        case 6...8:   return .sunrise
        case 9...16:  return .midday
        case 17...18: return .sunset
        case 19...20: return .dusk
        case 21...23: return .night
        default:      return .midday
        }
    }
}
