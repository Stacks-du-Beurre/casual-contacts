import CoreModels
import SwiftUI

/// Keep the visible card live while its hidden blur samples use a cached
/// bitmap during interactions. Capture after settling, never in the gesture.
struct CardMaterialSample<Content: View>: View {
    let recordKey: Int
    let attitude: DeviceAttitude
    let paused: Bool
    let size: CGSize
    let frame: CGRect
    let content: (DeviceAttitude, Bool) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cardRenderingSuspended) private var renderingSuspended
    @Environment(\.cardMaterialBlurRadius) private var blurRadius
    @Environment(\.windowSceneProjection) private var projection
    @Environment(\.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mailbox = MaterialCaptureMailbox()
    @State private var capturedImage: CGImage?

    private var input: MaterialCaptureInput {
        MaterialCaptureInput(attitude: attitude, projection: projection, size: size, frame: frame)
    }

    private var key: NSString {
        "\(recordKey):\(Int(size.width.rounded())):\(Int(size.height.rounded())):\(blurRadius)" as NSString
    }

    private var fallbackKey: NSString { "\(recordKey):\(blurRadius):latest" as NSString }

    private var preparedImage: CGImage? {
        capturedImage ?? MaterialCaptureCache.images.object(forKey: key)?.image
            ?? MaterialCaptureCache.images.object(forKey: fallbackKey)?.image
    }

    var body: some View {
        #if os(iOS)
        let _ = PerformanceDiagnostics.shared.receivedViewBody(.materialSample)
        #endif
        let image = preparedImage
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .opacity(paused ? 1 : 0)
            }
            if !paused || image == nil {
                content(attitude, false)
                    .blur(radius: blurRadius)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        // Hold immediately, so interaction startup does not draw both scenes.
        // Only returning to the live material needs a crossfade.
        .animation(paused || reduceMotion ? nil : .easeInOut(duration: 0.18), value: paused)
        .onChange(of: input, initial: true) { _, value in mailbox.latest = value }
        .onChange(of: paused, initial: true) { _, value in
            if value && capturedImage == nil {
                capturedImage = preparedImage
            }
            #if os(iOS)
            PerformanceDiagnostics.shared.event(value ? "material_sample_held" : "material_sample_live",
                                                values: ["cached": capturedImage == nil ? 0 : 1])
            #endif
        }
        .onChange(of: recordKey) { _, _ in capturedImage = nil }
        .task(id: "\(recordKey):\(paused):\(renderingSuspended):\(scenePhase)") {
            guard scenePhase == .active, !paused, !renderingSuspended else { return }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard !Task.isCancelled, let sample = mailbox.latest,
                  sample.size.width > 0, sample.size.height > 0 else { return }
            let cacheKey = "\(recordKey):\(Int(sample.size.width.rounded())):\(Int(sample.size.height.rounded())):\(blurRadius)" as NSString
            if let cached = MaterialCaptureCache.images.object(forKey: cacheKey),
               ProcessInfo.processInfo.systemUptime - cached.createdAt < 0.25 {
                capturedImage = cached.image
                return
            }
            #if os(iOS)
            let started = ProcessInfo.processInfo.systemUptime
            #endif
            let renderer = ImageRenderer(content: content(sample.attitude, true)
                .frame(width: sample.size.width, height: sample.size.height)
                .environment(\.windowSceneProjection, sample.projection)
                .environment(\.windowCardSize, sample.size)
                .environment(\.windowCardFrame, sample.frame)
                .environment(\.liveWindowGeometry, false)
                .coordinateSpace(.named("CardScene"))
                .blur(radius: blurRadius)
                .clipped()
                .environment(\.self, environment))
            renderer.scale = 1.5
            guard let image = renderer.cgImage, !Task.isCancelled else { return }
            capturedImage = image
            #if os(iOS)
            PerformanceDiagnostics.shared.event("material_sample_capture", values: [
                "durationMS": (ProcessInfo.processInfo.systemUptime - started) * 1000
            ])
            #endif
            let prepared = MaterialCaptureImage(image)
            let cost = image.bytesPerRow * image.height
            MaterialCaptureCache.images.setObject(prepared, forKey: cacheKey, cost: cost)
            // Newly mounted compact chrome during dismissal can reuse the most
            // recent sample while its size changes. Both entries count against
            // the cache budget, so this fallback cannot retain images unbounded.
            MaterialCaptureCache.images.setObject(prepared, forKey: fallbackKey, cost: cost)
        }
    }
}

private struct MaterialCaptureInput: Equatable {
    let attitude: DeviceAttitude
    let projection: WindowSceneProjection?
    let size: CGSize
    let frame: CGRect
}

@MainActor private final class MaterialCaptureMailbox {
    var latest: MaterialCaptureInput?
}

private final class MaterialCaptureImage {
    let image: CGImage
    let createdAt = ProcessInfo.processInfo.systemUptime
    init(_ image: CGImage) { self.image = image }
}

@MainActor private enum MaterialCaptureCache {
    static let images: NSCache<NSString, MaterialCaptureImage> = {
        let cache = NSCache<NSString, MaterialCaptureImage>()
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()
}

private struct CachedCardMaterialsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct CardRenderingSuspendedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct CardMaterialBlurRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var cardRenderingSuspended: Bool {
        get { self[CardRenderingSuspendedKey.self] }
        set { self[CardRenderingSuspendedKey.self] = newValue }
    }
    var usesCachedCardMaterials: Bool {
        get { self[CachedCardMaterialsKey.self] }
        set { self[CachedCardMaterialsKey.self] = newValue }
    }
    var cardMaterialBlurRadius: CGFloat {
        get { self[CardMaterialBlurRadiusKey.self] }
        set { self[CardMaterialBlurRadiusKey.self] = newValue }
    }
}

private struct CardMaterialInteractionActiveKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Hold only the hidden material samples while an overlaid card zooms.
    /// Visible card motion remains independent of this preparation policy.
    var cardMaterialInteractionActive: Bool {
        get { self[CardMaterialInteractionActiveKey.self] }
        set { self[CardMaterialInteractionActiveKey.self] = newValue }
    }
}
