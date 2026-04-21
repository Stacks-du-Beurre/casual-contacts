import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Visuals
#if os(iOS)
import PhotosUI
import UIKit
#endif

public struct CreateRecordScene: View {
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let onCancel: () -> Void
    public let onSave: (RecordDraft) -> Void

    @State private var model: CreateRecordModel
    @FocusState private var nameFocused: Bool

    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPhotoChooser = false
    @State private var showingPhotosPicker = false
    @State private var showingCamera = false
    #endif

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
        // Sheet-wide gradient that bleeds only past the BOTTOM safe area so
        // color extends behind the keyboard / home indicator. Using .background
        // (instead of a ZStack) pins the gradient's size to the host view so
        // its flexible Image content can't inflate the parent container.
        atmosphericSection
            .background(
                GradientLayer(timeOfDay: model.metadata.timeOfDay, attitude: attitude)
                    .ignoresSafeArea(edges: .bottom)
            )
            .onAppear { nameFocused = true }
            #if os(iOS)
            .sheet(isPresented: $showingPhotoChooser) {
                PhotoSourceSheet(
                    onCamera: {
                        showingPhotoChooser = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showingCamera = true
                        }
                    },
                    onPhotos: {
                        showingPhotoChooser = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showingPhotosPicker = true
                        }
                    },
                    onCancel: { showingPhotoChooser = false }
                )
            }
            .photosPicker(isPresented: $showingPhotosPicker, selection: $photoItem, matching: .images, photoLibrary: .shared())
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(
                    onCapture: { data in
                        model.photoData = data
                        showingCamera = false
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        model.photoData = data
                    }
                }
            }
            #endif
    }

    private var atmosphericSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                // Backdrop pinned to the TOP of the available area so it stays
                // anchored during interactive dismiss (where the sheet's usable
                // height changes faster than the geo.size we sized the backdrop
                // with, which would otherwise let it drift down from center).
                backdropLayer(size: geo.size)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                // Top nav pinned to top; form centered; location/save at the
                // bottom. Zodiac is absolutely positioned in the ZStack so it
                // doesn't consume VStack space.
                VStack(spacing: 0) {
                    PersonTopNav(onCancel: onCancel)
                        .padding(.top, 18)

                    Spacer(minLength: 0)

                    CreateFormOverlay(
                        model: model,
                        nameFocused: $nameFocused,
                        attitude: attitude,
                        backdropSize: geo.size,
                        coordinateSpaceName: Self.coordSpace,
                        onAddPhoto: {
                            #if os(iOS)
                            nameFocused = false
                            showingPhotoChooser = true
                            #endif
                        },
                        backdrop: { backdropLayer(size: geo.size) }
                    )

                    Spacer(minLength: 0)

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

                // Sits above the LocationTimeStrip (48) + SaveButton (50) + 8pt gap.
                zodiacBundle
                    .padding(.bottom, 106)
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
