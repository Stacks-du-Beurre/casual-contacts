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
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Backdrop fills the entire sheet, including behind the top nav.
                backdropLayer(size: geo.size)
                    .ignoresSafeArea()

                // Foreground: top nav + form stack.
                VStack(spacing: 0) {
                    PersonTopNav(onCancel: onCancel)
                        .padding(.top, 18)

                    // Form content + zodiac bundle, anchored top.
                    ZStack(alignment: .topLeading) {
                        CreateFormOverlay(
                            model: model,
                            nameFocused: $nameFocused,
                            attitude: attitude,
                            backdropSize: geo.size,
                            coordinateSpaceName: Self.coordSpace,
                            backdrop: { backdropLayer(size: geo.size) }
                        )

                        zodiacBundle
                            .padding(.top, 259)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 0)
                    }

                    Spacer(minLength: 0)
                }
            }
            .coordinateSpace(.named(Self.coordSpace))
            .onAppear { nameFocused = true }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
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
        }
    }

    @ViewBuilder
    private func backdropLayer(size: CGSize) -> some View {
        CardBackdrop(
            record: model.previewRecord,
            attitude: attitude,
            paths: paths,
            photo: photoImage
        )
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var zodiacBundle: some View {
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
