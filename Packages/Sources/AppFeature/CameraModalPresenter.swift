#if os(iOS)
import SwiftUI
import UIKit

/// Own entrance state inside the presented host, including when its parent is a sheet.
struct CameraModalEntrance<Content: View>: View {
    @State private var visible = false
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        content(visible)
            .task {
                // Commit the hidden first layout before starting the independent animations.
                await Task.yield()
                visible = true
            }
    }
}

/// A fixed full-screen host. Only the SwiftUI backdrop and panel animate.
struct CameraModalPresenter<Content: View>: UIViewControllerRepresentable {
    let isPresented: Bool
    let onPresented: () -> Void
    let setDismissAction: (@escaping () -> Void) -> Void
    let onDismissed: () -> Void
    @ViewBuilder let content: () -> Content

    func makeUIViewController(context: Context) -> Presenter {
        Presenter()
    }

    func updateUIViewController(_ controller: Presenter, context: Context) {
        controller.requested = isPresented
        controller.content = content()
        controller.onPresented = onPresented
        controller.setDismissAction = setDismissAction
        controller.onDismissed = onDismissed
        controller.synchronize()
    }

    static func dismantleUIViewController(_ controller: Presenter, coordinator: ()) {
        controller.requested = false
        controller.synchronize()
    }

    final class Presenter: UIViewController {
        var requested = false
        var content: Content?
        var onPresented: () -> Void = {}
        var setDismissAction: (@escaping () -> Void) -> Void = { _ in }
        var onDismissed: () -> Void = {}
        private var host: UIHostingController<Content>?
        private var transitioning = false

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            synchronize()
        }

        func close() {
            requested = false
            synchronize()
        }

        func synchronize() {
            guard !transitioning else { return }
            if requested, let content {
                guard viewIfLoaded?.window != nil else { return }
                if let host {
                    host.rootView = content
                    return
                }
                let modal = UIHostingController(rootView: content)
                modal.modalPresentationStyle = .overFullScreen
                modal.isModalInPresentation = true
                modal.view.backgroundColor = .clear
                host = modal
                transitioning = true
                present(modal, animated: false) { [weak self] in
                    guard let self else { return }
                    transitioning = false
                    setDismissAction { [weak self] in self?.close() }
                    onPresented()
                    synchronize()
                }
            } else if let host {
                transitioning = true
                host.dismiss(animated: false) { [weak self] in
                    guard let self else { return }
                    self.host = nil
                    requested = false
                    transitioning = false
                    onDismissed()
                    synchronize()
                }
            }
        }
    }
}
#endif
