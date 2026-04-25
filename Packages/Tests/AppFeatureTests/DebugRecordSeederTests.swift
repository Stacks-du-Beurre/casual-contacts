import Testing
import Foundation
import CoreModels
@testable import AppFeature

@Suite struct DebugRecordSeederTests {

    @Test func nearbyRecordsCount() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let records = DebugRecordSeeder.nearbyRecords(around: origin)
        #expect(records.count == 4)
    }

    @Test func nearbyRecordsAreAllWithinOneMile() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let records = DebugRecordSeeder.nearbyRecords(around: origin)
        for record in records {
            let location = try! #require(record.location)
            #expect(location.distanceMeters(to: origin) <= LocationInfo.metersInMile)
        }
    }

    @Test func nearbyRecordsHaveDistinctIDs() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let records = DebugRecordSeeder.nearbyRecords(around: origin)
        let ids = Set(records.map(\.id))
        #expect(ids.count == 4)
    }

    /// Nearby IDs must not collide with the existing seven city seeds so
    /// "Remove debug records" can clean both sets without duplicates being
    /// missed.
    @Test func nearbyIDsDontCollideWithCitySeedIDs() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let nearbyIDs = Set(DebugRecordSeeder.nearbyRecords(around: origin).map(\.id))
        let cityIDs = Set(DebugRecordSeeder.records.map(\.id))
        #expect(nearbyIDs.isDisjoint(with: cityIDs))
    }
}
