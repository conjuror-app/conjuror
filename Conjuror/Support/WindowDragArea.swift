import AppKit
import SwiftUI

struct WindowDragArea: NSViewRepresentable {
    let onWindowAvailable: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        DraggableView(onWindowAvailable: onWindowAvailable)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DraggableView)?.configureWindow()
    }
}

private final class DraggableView: NSView {
    private let onWindowAvailable: (NSWindow) -> Void

    init(onWindowAvailable: @escaping (NSWindow) -> Void) {
        self.onWindowAvailable = onWindowAvailable
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    func configureWindow() {
        guard let window else {
            return
        }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        onWindowAvailable(window)
    }
}
