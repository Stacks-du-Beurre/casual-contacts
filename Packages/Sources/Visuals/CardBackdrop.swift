import CoreModels
import DesignSystem
import SwiftUI

/// Atmospheric card backdrop — shared between `CardView` (list rows, detail)
/// and the create flow. Contains only the gradient + guilloche + photo-or-blend
/// layers. Does not render zodiac, moon, or text overlays.
public struct CardBackdrop: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?
    public let photoSize: CGSize?
    public let showsGuilloche: Bool

    @Bindable private var blendTuning = CardBlendTuning.shared

    public init(
        record: Record,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil,
        photoSize: CGSize? = nil,
        showsGuilloche: Bool = true
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.showsGuilloche = showsGuilloche
    }

    public var body: some View {
        let accoutrements = record.accoutrements
        let density: CCVisuals.Guilloche.LineDensity = .cards

        ZStack {
            GradientLayer(timeOfDay: record.metadata.timeOfDay, attitude: attitude)

            if showsGuilloche {
                GuillocheRotationLayer(
                    paths: GuillocheRotationLayer.swirlPaths(
                        from: paths.rotationPaths(for: "A").first
                    ),
                    attitude: attitude
                )
            }

            if let photo {
                PhotoLayer(
                    image: photo,
                    imageSize: photoSize,
                    focus: record.photoFocus,
                    style: .card
                )
            }

            if showsGuilloche {
                GuillocheBlendLayer(
                    paths: paths.blendPaths(
                        for: accoutrements.letter,
                        shape: accoutrements.guillocheShape,
                        density: density
                    ),
                    density: density,
                    attitude: attitude,
                    tint: .white,
                    depthScale: blendTuning.depthScale,
                    reversed: true
                )
                .frame(width: 184, height: 160)
                .opacity(0.55)
            }
        }
    }
}
