import CoreGraphics

struct TappedCardModalInteraction {
    struct Metrics: Equatable {
        let containerHeight: CGFloat
        let cardHeight: CGFloat
    }

    static let hiddenBottomPadding: CGFloat = 100
    static let dismissalDistanceFraction: CGFloat = 0.25
    static let dismissalVelocityProjection: CGFloat = 150

    static func hiddenOffset(for metrics: Metrics) -> CGFloat {
        metrics.containerHeight + hiddenBottomPadding
    }

    static func visibleOffset(dragTranslation: CGFloat) -> CGFloat {
        max(0, dragTranslation)
    }

    static func shouldDismiss(
        dragTranslation: CGFloat,
        predictedEndTranslation: CGFloat,
        metrics: Metrics
    ) -> Bool {
        let distanceThreshold = metrics.cardHeight * dismissalDistanceFraction
        let downwardDrag = visibleOffset(dragTranslation: dragTranslation)
        let projectedExtraDistance = predictedEndTranslation - dragTranslation
        return downwardDrag >= distanceThreshold
            || projectedExtraDistance >= dismissalVelocityProjection
    }

    static func backdropOpacity(isDismissalCommitting: Bool) -> CGFloat {
        isDismissalCommitting ? 0 : 1
    }
}
