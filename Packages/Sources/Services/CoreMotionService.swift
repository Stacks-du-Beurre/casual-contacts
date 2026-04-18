import Foundation
import CoreModels
#if canImport(CoreMotion) && !os(macOS)
import CoreMotion
#endif

// MARK: - Pure smoothing (unit-tested)

public final class AttitudeLowPass: @unchecked Sendable {

    private let alpha: Double
    private var state: DeviceAttitude?

    public init(alpha: Double) {
        self.alpha = alpha
    }

    @discardableResult
    public func smooth(_ raw: DeviceAttitude) -> DeviceAttitude {
        let clamped = raw.clamped()
        guard let previous = state else {
            state = clamped
            return clamped
        }
        let mixed = DeviceAttitude(
            pitch: previous.pitch + alpha * (clamped.pitch - previous.pitch),
            roll: previous.roll + alpha * (clamped.roll - previous.roll)
        )
        state = mixed
        return mixed
    }
}

// MARK: - Production service

#if canImport(CoreMotion) && !os(macOS)

public final class CoreMotionService: MotionService, @unchecked Sendable {

    private let manager = CMMotionManager()
    private let smoother = AttitudeLowPass(alpha: 0.1)
    private var continuation: AsyncStream<DeviceAttitude>.Continuation?
    public let attitude: AsyncStream<DeviceAttitude>

    public init() {
        var continuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { continuation = $0 }
        self.continuation = continuation
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
    }

    public func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let raw = DeviceAttitude(
                pitch: motion.attitude.pitch / (.pi / 2),
                roll: motion.attitude.roll / (.pi / 2)
            )
            let smoothed = self.smoother.smooth(raw)
            self.continuation?.yield(smoothed)
        }
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
        continuation?.finish()
        continuation = nil
    }
}

#endif
