import Foundation
import CoreModels

public final class StaticFaceDetectionService: FaceDetectionService, @unchecked Sendable {

    private let lock = NSLock()
    private var _result: NormalizedPoint?
    private var _delay: Duration
    private var _callCount = 0

    public init(result: NormalizedPoint? = .center, delay: Duration = .zero) {
        self._result = result
        self._delay = delay
    }

    public var result: NormalizedPoint? {
        get { lock.withLock { _result } }
        set { lock.withLock { _result = newValue } }
    }

    public var delay: Duration {
        get { lock.withLock { _delay } }
        set { lock.withLock { _delay = newValue } }
    }

    public var callCount: Int {
        lock.withLock { _callCount }
    }

    public func focusPoint(in imageData: Data) async -> NormalizedPoint? {
        let (resultCopy, delayCopy): (NormalizedPoint?, Duration) = lock.withLock {
            _callCount += 1
            return (_result, _delay)
        }
        if delayCopy > .zero {
            try? await Task.sleep(for: delayCopy)
        }
        return resultCopy
    }
}
