import CoreModels

public enum LocationPermissionFlow {
    public enum CreateAction: Sendable, Equatable {
        case openCreate
        case openCreateWithoutLocationRequest
        case requestAuthorizationThenOpenCreate
        case showPrimer
    }

    public enum SettingsAcceptAction: Sendable, Equatable {
        case requestAuthorization
        case openSystemSettings
        case noAction
    }

    public enum DistanceSortAction: Sendable, Equatable {
        case sortWithCurrentLocation
        case requestAuthorizationThenSort
        case showPrimer
        case openSystemSettings
        case noAction
    }

    public static func createAction(
        authorization: LocationAuthorization,
        decision: LocationPermissionPrimerDecision
    ) -> CreateAction {
        switch authorization {
        case .authorized:
            return .openCreate
        case .denied:
            return .openCreateWithoutLocationRequest
        case .notDetermined:
            switch decision {
            case .notAnswered:
                return .showPrimer
            case .accepted:
                return .requestAuthorizationThenOpenCreate
            case .declined:
                return .openCreateWithoutLocationRequest
            }
        }
    }

    public static func settingsAcceptAction(
        authorization: LocationAuthorization
    ) -> SettingsAcceptAction {
        switch authorization {
        case .authorized:
            return .noAction
        case .notDetermined:
            return .requestAuthorization
        case .denied:
            return .openSystemSettings
        }
    }

    public static func distanceSortAction(
        authorization: LocationAuthorization,
        decision: LocationPermissionPrimerDecision
    ) -> DistanceSortAction {
        switch authorization {
        case .authorized:
            return .sortWithCurrentLocation
        case .notDetermined:
            switch decision {
            case .notAnswered:
                return .showPrimer
            case .accepted:
                return .requestAuthorizationThenSort
            case .declined:
                return .noAction
            }
        case .denied:
            switch decision {
            case .accepted:
                return .openSystemSettings
            case .notAnswered:
                return .showPrimer
            case .declined:
                return .noAction
            }
        }
    }
}
