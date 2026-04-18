import Foundation
import CoreModels

public final class StaticMotionService: MotionService, @unchecked Sendable {

    private let fixedAttitude: DeviceAttitude
    private var continuation: AsyncStream<DeviceAttitude>.Continuation?
    public let attitude: AsyncStream<DeviceAttitude>

    public init(attitude: DeviceAttitude = .zero) {
        self.fixedAttitude = attitude
        var continuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func start() {
        continuation?.yield(fixedAttitude)
    }

    public func stop() {
        continuation?.finish()
        continuation = nil
    }
}
