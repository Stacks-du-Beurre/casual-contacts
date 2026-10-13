#if os(iOS)
import SwiftUI
import UIKit

/// UIKit animates the entire compact dialog and backdrop as one presentation.
struct CameraModalPresenter<Content: View>: UIViewControllerRepresentable {
    let isPresented: Bool
    let setDismissAction: (@escaping () -> Void) -> Void
    let onDismissed: () -> Void
    @ViewBuilder let content: () -> Content

    func makeUIViewController(context: Context) -> Presenter { Presenter() }

    func updateUIViewController(_ controller: Presenter, context: Context) {
        controller.requested = isPresented
        controller.content = content()
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
                modal.modalTransitionStyle = .crossDissolve
                modal.isModalInPresentation = true
                modal.view.backgroundColor = .clear
                host = modal
                transitioning = true
                present(modal, animated: true) { [weak self] in
                    guard let self else { return }
                    transitioning = false
                    setDismissAction { [weak self] in self?.close() }
                    synchronize()
                }
            } else if let host {
                transitioning = true
                host.dismiss(animated: true) { [weak self] in
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
