import Foundation
import Testing
import CoreModels
import FeatureList
@testable import AppFeature

@Suite struct LocationPermissionPrimerTests {
    @Test func inMemoryStoreDefaultsToNotAnswered() {
        let store = InMemoryLocationPermissionPrimerStore()
        #expect(store.decision == .notAnswered)
    }

    @Test func inMemoryStorePersistsAcceptedAndDeclined() {
        let store = InMemoryLocationPermissionPrimerStore()
        store.decision = .accepted
        #expect(store.decision == .accepted)
        store.decision = .declined
        #expect(store.decision == .declined)
    }

    @Test func listSortStoreDefaultsToNoSavedChoice() {
        let store = InMemoryListSortPreferenceStore()
        #expect(store.sortOption == nil)
    }

    @Test func listSortStorePersistsSelectedChoice() {
        let store = InMemoryListSortPreferenceStore()
        store.sortOption = .timeCreated
        #expect(store.sortOption == .timeCreated)
        store.sortOption = .distance
        #expect(store.sortOption == .distance)
    }

    @Test func userDefaultsListSortStoreRoundTripsAcrossInstances() throws {
        let suiteName = "UserDefaultsListSortPreferenceStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsListSortPreferenceStore(defaults: defaults, key: "sort")
        #expect(store.sortOption == nil)

        store.sortOption = .timeCreated
        let reloaded = UserDefaultsListSortPreferenceStore(defaults: defaults, key: "sort")
        #expect(reloaded.sortOption == .timeCreated)

        reloaded.sortOption = nil
        #expect(store.sortOption == nil)
    }

    @Test func userDefaultsListSortStoreIgnoresUnknownSavedValues() throws {
        let suiteName = "UserDefaultsListSortPreferenceStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("nearestFirst", forKey: "sort")

        let store = UserDefaultsListSortPreferenceStore(defaults: defaults, key: "sort")
        #expect(store.sortOption == nil)
    }

    @Test func userDefaultsLastLocationStoreRoundTripsAcrossInstances() throws {
        let suiteName = "UserDefaultsLastLocationStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let location = LocationInfo(latitude: 41.8781, longitude: -87.6298, label: "Chicago")
        let store = UserDefaultsLastLocationStore(defaults: defaults, key: "lastLocation")
        #expect(store.location == nil)

        store.location = location
        let reloaded = UserDefaultsLastLocationStore(defaults: defaults, key: "lastLocation")
        #expect(reloaded.location == location)

        reloaded.location = nil
        #expect(store.location == nil)
    }

    @Test func userDefaultsLastLocationStoreIgnoresInvalidData() throws {
        let suiteName = "UserDefaultsLastLocationStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "lastLocation")

        let store = UserDefaultsLastLocationStore(defaults: defaults, key: "lastLocation")
        #expect(store.location == nil)
    }

    @Test func listCurrentLocationDefaultsToCachedLocationOnLaunch() {
        let cached = LocationInfo(latitude: 34.0522, longitude: -118.2437, label: "Downtown LA")

        #expect(ListCurrentLocationResolver.initialLocation(cached: cached) == cached)
        #expect(ListCurrentLocationResolver.initialLocation(cached: nil) == nil)
    }

    @Test func listSortDefaultsToDistanceWhenLocationIsAuthorizedAndNoChoiceIsSaved() {
        #expect(ListSortPreferenceResolver.initialSortOption(
            stored: nil,
            authorization: .authorized
        ) == .distance)
    }

    @Test func listSortDefaultsToAlphabeticalWhenLocationIsUnavailableAndNoChoiceIsSaved() {
        #expect(ListSortPreferenceResolver.initialSortOption(
            stored: nil,
            authorization: .notDetermined
        ) == .alphabetical)
        #expect(ListSortPreferenceResolver.initialSortOption(
            stored: nil,
            authorization: .denied
        ) == .alphabetical)
    }

    @Test func listSortSavedChoiceOverridesLocationDefault() {
        #expect(ListSortPreferenceResolver.initialSortOption(
            stored: .dateCreated,
            authorization: .authorized
        ) == .dateCreated)
    }

    @Test func savedDistanceChoiceRequiresAuthorizedLocationOnLaunch() {
        #expect(ListSortPreferenceResolver.initialSortOption(
            stored: .distance,
            authorization: .denied
        ) == .alphabetical)
    }

    @Test func createGateShowsPrimerWhenAuthorizationIsUndecidedAndPrimerWasNotAccepted() {
        #expect(LocationPermissionFlow.createAction(
            authorization: .notDetermined,
            decision: .notAnswered
        ) == .showPrimer)
        #expect(LocationPermissionFlow.createAction(
            authorization: .notDetermined,
            decision: .declined
        ) == .showPrimer)
        #expect(LocationPermissionFlow.createAction(
            authorization: .notDetermined,
            decision: .accepted
        ) == .requestAuthorizationThenOpenCreate)
        #expect(LocationPermissionFlow.createAction(
            authorization: .authorized,
            decision: .notAnswered
        ) == .openCreate)
    }

    @Test func settingsDeniedAcceptRedirectsInsteadOfRequestingAgain() {
        #expect(LocationPermissionFlow.settingsAcceptAction(authorization: .denied) == .openSystemSettings)
        #expect(LocationPermissionFlow.settingsAcceptAction(authorization: .notDetermined) == .requestAuthorization)
    }

    @Test func distanceSortShowsPrimerBeforePermissionRequest() {
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .notDetermined,
            decision: .notAnswered
        ) == .showPrimer)
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .notDetermined,
            decision: .accepted
        ) == .requestAuthorizationThenSort)
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .notDetermined,
            decision: .declined
        ) == .showPrimer)
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .authorized,
            decision: .notAnswered
        ) == .sortWithCurrentLocation)
    }

    @Test func distanceSortDeniedStateDoesNotRequestAgain() {
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .denied,
            decision: .accepted
        ) == .showPrimer)
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .denied,
            decision: .declined
        ) == .showPrimer)
    }

    @Test func distanceSortPrimerAcceptRedirectsAfterDeniedAuthorization() {
        #expect(LocationPermissionFlow.distanceSortPrimerAcceptAction(
            authorization: .denied
        ) == .openSystemSettings)
        #expect(LocationPermissionFlow.distanceSortPrimerAcceptAction(
            authorization: .notDetermined
        ) == .requestAuthorizationThenSort)
        #expect(LocationPermissionFlow.distanceSortPrimerAcceptAction(
            authorization: .authorized
        ) == .sortWithCurrentLocation)
    }
}
