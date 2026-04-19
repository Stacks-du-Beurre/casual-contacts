import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Visuals

public struct CreateRecordScene: View {
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let onCancel: () -> Void
    public let onSave: (RecordDraft) -> Void

    @State private var model: CreateRecordModel
    @FocusState private var nameFocused: Bool

    private static let coordSpace = "createScene"

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
            // Everything from top-nav through location-strip shares the backdrop.
            // SaveButton is a sibling at the bottom with its own gradient, so the
            // backdrop's bottom edge pins exactly to the save button's top.
            atmosphericSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { nameFocused = true }
    }

    private var atmosphericSection: some View {
        GeometryReader { geo in
            ZStack {
                // Centered atmospheric backdrop fills this section.
                backdropLayer(size: geo.size)
                    .allowsHitTesting(false)

                // Top nav pinned to top; zodiac/location/save pinned to bottom.
                VStack(spacing: 0) {
                    PersonTopNav(onCancel: onCancel)
                        .padding(.top, 18)

                    Spacer(minLength: 0)

                    zodiacBundle
                        .frame(maxWidth: .infinity, alignment: .trailing)

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
                }

                // Form overlay centered vertically in the container.
                CreateFormOverlay(
                    model: model,
                    nameFocused: $nameFocused,
                    attitude: attitude,
                    backdropSize: geo.size,
                    coordinateSpaceName: Self.coordSpace,
                    backdrop: { backdropLayer(size: geo.size) }
                )
            }
            .coordinateSpace(.named(Self.coordSpace))
        }
    }

    private func backdropLayer(size: CGSize) -> some View {
        CardBackdrop(
            record: model.previewRecord,
            attitude: attitude,
            paths: paths,
            photo: photoImage
        )
        .frame(width: size.width, height: size.height)
    }

    private var zodiacBundle: some View {
        VStack(alignment: .trailing, spacing: 0) {
            CreateConstellationBadge(sign: model.randomZodiacSign, attitude: attitude)
                .frame(width: 100, height: 90)

            HStack(spacing: 5) {
                CreateZodiacSymbolBadge(sign: model.randomZodiacSign, attitude: attitude)
                    .frame(width: 35, height: 32)

                CreateMoonPhaseBadge(phase: model.metadata.moonPhase)
                    .frame(width: 35, height: 32)
            }
            .padding(.trailing, 8)
        }
        .allowsHitTesting(false)
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
