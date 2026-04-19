import SwiftUI
import CoreModels
import DesignSystem

/// Atmospheric card backdrop — shared between `CardView` (list rows, detail)
/// and the create flow. Contains only the gradient + guilloche + photo-or-blend
/// layers. Does not render zodiac, moon, or text overlays.
public struct CardBackdrop: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?

    @Bindable private var blendTuning = CardBlendTuning.shared

    public init(
        record: Record,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
    }

    public var body: some View {
        let accoutrements = record.accoutrements
        let density: CCVisuals.Guilloche.LineDensity = .cards

        ZStack {
            GradientLayer(timeOfDay: record.metadata.timeOfDay, attitude: attitude)

            GuillocheRotationLayer(paths: paths.rotationPaths(for: accoutrements.letter))

            BBackgroundSilhouetteLayer(
                paths: GuillocheRotationLayer.swirlPaths(
                    from: paths.rotationPaths(for: accoutrements.letter).first
                )
            )

            if let photo {
                PhotoLayer(image: photo, style: .card)
            } else {
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
