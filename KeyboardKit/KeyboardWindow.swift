// Douglas Hill, December 2019

import UIKit

/// A window that supports using escape on a hardware keyboard to dismiss any topmost modal sheet or popover.
/// Calls the presentation controller delegate like for any other user-driven dismissal.
///
/// Unlike most other KeyboardKit subclasses, `KeyboardWindow` does not override
/// `canBecomeFirstResponder` to return `true` because this results in shorter responder
/// chain at scene connection, which is not desirable. It’s best if the first responder
/// is a specific view or view controller instead. It there is a `UIFocusSystem` then
/// that system will take care of the first responder automatically.
open class KeyboardWindow: UIWindow {

    /*
     This class deliberately does not override canBecomeFirstResponder to return true.

     If the window can become first responder, then UIKit will make it first responder
     as part of makeKeyAndVisible. This means that at scene connection, the window is
     the first responder, not a child, so a limited number of key commands are available.

     However if the window can’t become first responder, then at scene connection there
     is no explicit first responder. In this case, key events are delivered using:

     -[UIApplication _responderForKeyEvents]
     -[UIWindow _responderForKeyEvents]
     -[UIWindow _deepestActionResponder]

     That last call goes through the view controller hierarchy from rootViewController
     to children and presented view controllers to find a sensible default responder.
     This is almost certainly going to make more key commands possible than if the
     window is first responder.
     */

    private lazy var dismissKeyCommands = [
        UIKeyCommand(.escape, action: #selector(kbd_dismissTopmostModalViewIfPossible)),
        UIKeyCommand((.command, "W"), action: #selector(kbd_dismissTopmostModalViewIfPossible)),
    ]

    open override var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []

        commands += dismissKeyCommands

        return commands
    }

    @objc func kbd_dismissTopmostModalViewIfPossible(_ sender: Any?) {
        guard
            let topmost = topmostPresentedViewController,
            topmost.isBeingPresented == false && topmost.isBeingDismissed == false,
            topmost.modalPresentationStyle.isDismissibleWithoutConfirmation
        else {
            return
        }

        let presentationController = topmost.presentationController!

        guard
            topmost.isModalInPresentation == false,
            delegateSaysPresentationControllerShouldDismiss(presentationController)
        else {
            tellDelegatePresentationControllerDidAttemptToDismiss(presentationController)
            return
        }

        tellDelegatePresentationControllerWillDismiss(presentationController)
        topmost.presentingViewController!.dismiss(animated: true) {
            tellDelegatePresentationControllerDidDismiss(presentationController)
        }
    }
}

private extension UIWindow {
    /// Follows presentedViewController to the end. Returns nil if the root view controller is not presenting anything.
    var topmostPresentedViewController: UIViewController? {
        guard var viewController = rootViewController?.presentedViewController else {
            return nil
        }
        while let presentedViewController = viewController.presentedViewController {
            viewController = presentedViewController
        }
        return viewController
    }
}

private func delegateSaysPresentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
    // TODO: Verify this matches what UIKit does. Not yet documented so should find by experimentation.

    if #available(iOS 13, *), let should = presentationController.delegate?.presentationControllerShouldDismiss?(presentationController) {
        return should
    }

    // Since Catalyst did not start until iOS 13 this warns even though the deployment target is iOS 12.
    #if !targetEnvironment(macCatalyst) && !os(visionOS)
    if
        let popoverPresentationController = presentationController as? UIPopoverPresentationController,
        let should = popoverPresentationController.delegate?.popoverPresentationControllerShouldDismissPopover?(popoverPresentationController)
    {
        return should
    }
    #endif

    return true
}

private func tellDelegatePresentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
    if #available(iOS 13, *) {
        presentationController.delegate?.presentationControllerDidAttemptToDismiss?(presentationController)
    }
}

private func tellDelegatePresentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    if #available(iOS 13, *) {
        presentationController.delegate?.presentationControllerWillDismiss?(presentationController)
    }
}

private func tellDelegatePresentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    // TODO: Verify whether UIKit calls both if both are implemented or whether it stops after the first one is implemented.

    if #available(iOS 13, *) {
        presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
    }

    // Since Catalyst did not start until iOS 13 this warns even though the deployment target is iOS 12.
    #if !targetEnvironment(macCatalyst) && !os(visionOS)
    if let popoverPresentationController = presentationController as? UIPopoverPresentationController {
        popoverPresentationController.delegate?.popoverPresentationControllerDidDismissPopover?(popoverPresentationController)
    }
    #endif
}

private extension UIModalPresentationStyle {
    /// Whether the style itself allows the user to dismiss the presented view controller.
    var isDismissibleWithoutConfirmation: Bool {
        switch self {
        case .automatic:
            preconditionFailure("UIKit should have resolved automatic to a concrete style.")
        case .popover:
            return true
        case .pageSheet, .formSheet:
            if #available(iOS 13, *) {
                return true
            } else {
                return false
            }
        case .fullScreen, .currentContext, .custom, .overFullScreen, .overCurrentContext, .none: fallthrough @unknown default:
            return false
        }
    }
}
