import SwiftUI
import UIKit

final class ViewController: UIHostingController<LockURootView> {
    init() {
        super.init(rootView: LockURootView())
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: LockURootView())
    }
}
