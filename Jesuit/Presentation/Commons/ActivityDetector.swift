//
//  ActivityDetector.swift
//  Jesuit
//
//  Invisible bridge that resets AppLock's inactivity timer on every touch. It adds a
//  passive gesture recognizer to the key window that observes touches without ever
//  consuming them (cancelsTouchesInView = false, never recognizes), so buttons/scroll
//  behave normally. This is the standard SwiftUI idiom for an app-wide idle timeout.
//

import SwiftUI
import UIKit

struct ActivityDetector: UIViewRepresentable {
    let onActivity: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ActivityTrackingView()
        view.onActivity = onActivity
        view.isUserInteractionEnabled = false   // reach the window, don't intercept
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? ActivityTrackingView)?.onActivity = onActivity
    }
}

private final class ActivityTrackingView: UIView {
    var onActivity: (() -> Void)?
    private var recognizer: ActivityGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        let recognizer = recognizer ?? {
            let r = ActivityGestureRecognizer()
            r.onActivity = { [weak self] in self?.onActivity?() }
            r.cancelsTouchesInView = false
            r.delaysTouchesBegan = false
            r.delaysTouchesEnded = false
            self.recognizer = r
            return r
        }()
        if recognizer.view !== window {
            recognizer.view?.removeGestureRecognizer(recognizer)
            window.addGestureRecognizer(recognizer)
        }
    }
}

/// Fires `onActivity` on the first touch of every sequence, then fails so it never
/// affects how the touch is delivered to the actual UI.
private final class ActivityGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onActivity: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
    }
    convenience init() { self.init(target: nil, action: nil) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        onActivity?()
        state = .failed
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { true }
}
