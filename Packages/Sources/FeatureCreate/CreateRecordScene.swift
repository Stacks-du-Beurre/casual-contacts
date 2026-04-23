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
    public let faceDetectionService: any FaceDetectionService
    public let onCancel: () -> Void
    public let onSave: (RecordDraft) -> Void

    @State private var model: CreateRecordModel
    @FocusState private var formFocus: CreateFormField?
    @State private var suspendedFocus: CreateFormField?

    @State private var showingPhotoChooser = false
    @State private var showingZodiacPicker = false
    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPhotosPicker = false
    @State private var showingCamera = false
    #endif

    private static let coordSpace = "createScene"

    public init(
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        faceDetectionService: any FaceDetectionService,
        createdAt: Date,
        metadata: RecordMetadata,
        location: LocationInfo?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (RecordDraft) -> Void
    ) {
        self.attitude = attitude
        self.paths = paths
        self.faceDetectionService = faceDetectionService
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
            .onAppear { formFocus = .name }
            #if os(iOS)
            .photosPicker(isPresented: $showingPhotosPicker, selection: $photoItem, matching: .images, photoLibrary: .shared())
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(
                    onCapture: { data in
                        model.setPhoto(data, using: faceDetectionService)
                        showingCamera = false
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
            }
            .onChange(of: showingPhotosPicker) { _, shown in
                if !shown { restoreSuspendedFocus() }
            }
            .onChange(of: showingCamera) { _, shown in
                if !shown { restoreSuspendedFocus() }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        model.setPhoto(data, using: faceDetectionService)
                    }
                }
            }
            #endif
    }

    /// Capture whichever form field currently owns focus, then release it so
    /// the keyboard retracts cleanly before a picker presents.
    private func suspendFocus() {
        suspendedFocus = formFocus
        formFocus = nil
    }

    /// Restore focus to the field that was active before the last picker was
    /// presented. Called once the picker has dismissed.
    private func restoreSuspendedFocus() {
        guard let suspended = suspendedFocus else { return }
        suspendedFocus = nil
        DispatchQueue.main.async {
            formFocus = suspended
        }
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
                        formFocus: $formFocus,
                        attitude: attitude,
                        backdropSize: geo.size,
                        coordinateSpaceName: Self.coordSpace,
                        isPhotoChooserPresented: $showingPhotoChooser,
                        onPickCamera: {
                            #if os(iOS)
                            suspendFocus()
                            showingPhotoChooser = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                showingCamera = true
                            }
                            #endif
                        },
                        onPickPhotos: {
                            #if os(iOS)
                            suspendFocus()
                            showingPhotoChooser = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                showingPhotosPicker = true
                            }
                            #endif
                        },
                        isZodiacPickerPresented: $showingZodiacPicker,
                        onSelectZodiac: { sign in
                            model.zodiacSign = sign
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
            photo: photoImageAndSize?.image,
            photoSize: photoImageAndSize?.size
        )
        .frame(width: size.width, height: size.height)
    }

    private var zodiacBundle: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let sign = model.zodiacSign {
                CreateConstellationBadge(sign: sign, attitude: attitude)
                    .frame(width: 100, height: 90)
            } else {
                // Reserve the constellation's slot so the moon-phase row stays
                // pinned to its anchor when no zodiac sign is selected.
                Color.clear.frame(width: 100, height: 90)
            }

            HStack(spacing: 5) {
                if let sign = model.zodiacSign {
                    CreateZodiacSymbolBadge(sign: sign, attitude: attitude)
                        .frame(width: 35, height: 32)
                }

                CreateMoonPhaseBadge(phase: model.metadata.moonPhase)
                    .frame(width: 35, height: 32)
            }
            .padding(.trailing, 8)
        }
        .allowsHitTesting(false)
    }

    private var photoImageAndSize: (image: Image, size: CGSize)? {
        #if canImport(UIKit)
            // Omit the photo during detection so the spinner carries the wait
            // state instead of flashing a momentarily miscropped image.
            guard case .ready(let data, _) = model.photoState,
                  let uiImage = UIImage(data: data)
            else { return nil }
            return (Image(uiImage: uiImage), uiImage.size)
        #else
            return nil
        #endif
    }
}
