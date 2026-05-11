import Testing
import CoreGraphics
@testable import FeatureDetail

@Suite struct TappedCardModalInteractionTests {

    @Test func hiddenCardStartsBelowViewport() {
        let metrics = TappedCardModalInteraction.Metrics(
            containerHeight: 720,
            cardHeight: 328
        )

        #expect(TappedCardModalInteraction.hiddenOffset(for: metrics) == 820)
    }

    @Test func visibleCardTracksOnlyDownwardDrag() {
        #expect(TappedCardModalInteraction.visibleOffset(dragTranslation: 84) == 84)
        #expect(TappedCardModalInteraction.visibleOffset(dragTranslation: -40) == 0)
    }

    @Test func dragBelowDistanceAndVelocityThresholdCancels() {
        let metrics = TappedCardModalInteraction.Metrics(
            containerHeight: 720,
            cardHeight: 328
        )

        #expect(
            TappedCardModalInteraction.shouldDismiss(
                dragTranslation: 70,
                predictedEndTranslation: 120,
                metrics: metrics
            ) == false
        )
    }

    @Test func dragBeyondDistanceThresholdDismisses() {
        let metrics = TappedCardModalInteraction.Metrics(
            containerHeight: 720,
            cardHeight: 328
        )

        #expect(
            TappedCardModalInteraction.shouldDismiss(
                dragTranslation: 98,
                predictedEndTranslation: 120,
                metrics: metrics
            )
        )
    }

    @Test func fastDownwardFlickDismissesEvenBelowDistanceThreshold() {
        let metrics = TappedCardModalInteraction.Metrics(
            containerHeight: 720,
            cardHeight: 328
        )

        #expect(
            TappedCardModalInteraction.shouldDismiss(
                dragTranslation: 58,
                predictedEndTranslation: 230,
                metrics: metrics
            )
        )
    }

    @Test func backdropStaysFullyAppliedWhileDragging() {
        #expect(TappedCardModalInteraction.backdropOpacity(isDismissalCommitting: false) == 1)
        #expect(TappedCardModalInteraction.backdropOpacity(isDismissalCommitting: true) == 0)
    }
}
