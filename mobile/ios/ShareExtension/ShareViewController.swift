import SwiftUI
import UIKit

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let intake = SharedIntake()

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        modalPresentationStyle = .overFullScreen
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        ShareFolder.dropOldStaging()
        let context = ShareFolder.readContext()
        let sheet = ShareSheetView(
            intake: intake, context: context,
            endEditing: { [weak self] in self?.view.endEditing(true) },
            onClose: { [weak self] isSaved in self?.finish(isSaved: isSaved) }
        )
        let host = UIHostingController(rootView: sheet)
        host.view.backgroundColor = .clear
        switch context.theme {
        case "light": host.overrideUserInterfaceStyle = .light
        case "dark": host.overrideUserInterfaceStyle = .dark
        default: break
        }
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task { await intake.read(items) }
    }

    private func finish(isSaved: Bool) {
        if !isSaved { intake.discard() }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
