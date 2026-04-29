import Testing
import CoreModels
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

    @Test func createGateShowsPrimerOnlyForUndecidedAuthAndUnansweredPrimer() {
        #expect(LocationPermissionFlow.createAction(
            authorization: .notDetermined,
            decision: .notAnswered
        ) == .showPrimer)
        #expect(LocationPermissionFlow.createAction(
            authorization: .notDetermined,
            decision: .declined
        ) == .openCreateWithoutLocationRequest)
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
            authorization: .authorized,
            decision: .notAnswered
        ) == .sortWithCurrentLocation)
    }

    @Test func distanceSortDeniedStateDoesNotRequestAgain() {
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .denied,
            decision: .accepted
        ) == .openSystemSettings)
        #expect(LocationPermissionFlow.distanceSortAction(
            authorization: .denied,
            decision: .declined
        ) == .noAction)
    }
}
