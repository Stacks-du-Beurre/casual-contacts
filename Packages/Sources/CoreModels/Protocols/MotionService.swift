import Foundation

public protocol MotionService: AnyObject, Sendable {
    var attitude: AsyncStream<DeviceAttitude> { get }
    func start()
    func stop()
}
