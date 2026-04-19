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
        .background(CCDesign.Colors.L2)
    }

    @ViewBuilder
    private var cardArea: some View {
        ZStack(alignment: .topTrailing) {
            CardBackdrop(
                record: model.previewRecord,
                attitude: attitude,
                paths: paths,
                photo: photoImage
            )

            // Right-edge zodiac bundle — 100×127 frame positioned per Figma
            // (frame origin relative to card: right-aligned, 259pt top inset in
            // a 375×467 card area).
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
            .offset(y: 259)

            // Editable form layer — anchored top-leading.
            CreateFormOverlay(model: model)
        }
        .clipped()
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
