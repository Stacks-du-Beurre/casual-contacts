import Testing
import CoreGraphics
@testable import FeatureDetail

@Suite struct CardDismissDragTests {
    @Test func dragProgressIsClamped() {
        #expect(CardDismissDrag.progress(translation: -100, height: 800) == 1)
        #expect(CardDismissDrag.progress(translation: 260, height: 800) == 0.5)
        #expect(CardDismissDrag.progress(translation: 1000, height: 800) == 0)
    }
    @Test func shortDragsCancelAndDownwardFlicksFinish() {
        #expect(!CardDismissDrag.shouldFinish(translation: 20, predicted: 300, height: 800))
        #expect(!CardDismissDrag.shouldFinish(translation: 60, predicted: 80, height: 800))
        #expect(CardDismissDrag.shouldFinish(translation: 140, predicted: 140, height: 800))
        #expect(CardDismissDrag.shouldFinish(translation: 60, predicted: 300, height: 800))
    }
}
