import SwiftUI
import Foundation
import CoreModels
import DesignSystem
import Visuals

public struct CreateRecordScene: View {

    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let onCancel: () -> Void
    public let onSave: (RecordDraft) -> Void

    @State private var model: CreateRecordModel

    public init(
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        createdAt: Date,
        metadata: RecordMetadata,
        location: LocationInfo?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (RecordDraft) -> Void
    ) {
        self.attitude = attitude
        self.paths = paths
        self.onCancel = onCancel
        self.onSave = onSave
        _model = State(initialValue: CreateRecordModel(
            createdAt: createdAt,
            metadata: metadata,
            location: location
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            PersonTopNav(onCancel: onCancel)

            cardArea
                .frame(height: 467)

            LocationTimeStrip(
                location: model.location,
                createdAt: model.createdAt,
                timeOfDay: model.metadata.timeOfDay
            )

            SaveButton(
                isEnabled: model.isSaveable,
                timeOfDay: model.metadata.timeOfDay,
                attitude: attitude,
                action: { onSave(model.draft) }
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(CCDesign.Colors.L2)
    }

    @ViewBuilder
    private var cardArea: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CardBackdrop(
                    record: model.previewRecord,
                    attitude: attitude,
                    paths: paths,
                    photo: photoImage
                )

                // Right-edge zodiac bundle — anchored top-trailing within the
                // card, with Figma's 259pt top inset.
                ZStack(alignment: .topLeading) {
                    CreateConstellationBadge(sign: model.randomZodiacSign, attitude: attitude)
                        .frame(width: 100, height: 90)

                    CreateZodiacSymbolBadge(sign: model.randomZodiacSign, attitude: attitude)
                        .frame(width: 35, height: 32)
                        .offset(x: 52, y: 70)

                    CreateMoonPhaseBadge(phase: model.metadata.moonPhase)
                        .frame(width: 35, height: 56)
                        .offset(x: 57, y: 71)
                }
                .frame(width: 100, height: 127)
                .padding(.top, 259)
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Editable form layer — anchored top-leading via an explicit
                // origin so it can't inherit the ZStack's cross-sibling
                // alignment negotiation.
                CreateFormOverlay(model: model)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
    }

    private var photoImage: Image? {
        #if canImport(UIKit)
        guard let data = model.photoData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}
