import Foundation
import CoreModels

public final class StaticMotionService: MotionService, @unchecked Sendable {

    private let fixedAttitude: DeviceAttitude
    private var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation?
    public let attitude: AsyncStream<DeviceAttitude>

    /// Never-yielding by design — fakes don't run a sensor callback and
    /// nothing in test code needs the debug pipeline. Wiring it as a real
    /// AsyncStream (vs. nil) keeps the protocol simple: consumers always
    /// `for await` the same way.
    public let debugSamples: AsyncStream<MotionDebugSample>
    private var debugContinuation: AsyncStream<MotionDebugSample>.Continuation?

    public init(attitude: DeviceAttitude = .zero) {
        self.fixedAttitude = attitude

        var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { attitudeContinuation = $0 }
        self.attitudeContinuation = attitudeContinuation

        var debugContinuation: AsyncStream<MotionDebugSample>.Continuation!
        self.debugSamples = AsyncStream { debugContinuation = $0 }
        self.debugContinuation = debugContinuation
    }

    public func start() {
        attitudeContinuation?.yield(fixedAttitude)
    }

    public func resetZeroPoint() {
        attitudeContinuation?.yield(.zero)
    }

    public func stop() {
        attitudeContinuation?.finish()
        attitudeContinuation = nil
        debugContinuation?.finish()
        debugContinuation = nil
    }
}
