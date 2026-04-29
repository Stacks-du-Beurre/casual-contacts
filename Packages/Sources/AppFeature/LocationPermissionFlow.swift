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
}
