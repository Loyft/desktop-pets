import AppKit

/// Tiny floating speech bubble that follows above the pet for a few seconds.
final class SpeechBubblePanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private var hideWorkItem: DispatchWorkItem?
    private var isShowing = false

    /// Fired once when the bubble fully hides (timeout or forced).
    var onDidHide: (() -> Void)?

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 96, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        hidesOnDeactivate = false

        let container = BubbleView(frame: contentRect)
        container.wantsLayer = true
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = NSColor(calibratedRed: 0.18, green: 0.14, blue: 0.12, alpha: 1)
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        contentView = container
        orderOut(nil)
    }

    /// Shared with PetPanel follow-up so the bubble stays clear of the fox head.
    static func originY(above petFrame: NSRect) -> CGFloat {
        petFrame.minY + petFrame.height * 0.78
    }

    func show(text: String, above petFrame: NSRect) {
        label.stringValue = text
        label.sizeToFit()
        let width = max(56, min(140, label.intrinsicContentSize.width + 24))
        let height: CGFloat = 34
        let x = petFrame.midX - width / 2
        let y = Self.originY(above: petFrame)
        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        isShowing = true
        orderFrontRegardless()

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.finishHide()
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    func hideBubble() {
        hideWorkItem?.cancel()
        finishHide()
    }

    private func finishHide() {
        guard isShowing else { return }
        isShowing = false
        orderOut(nil)
        onDidHide?()
    }
}

private final class BubbleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds.insetBy(dx: 1, dy: 1)
        let bubble = NSRect(x: bounds.minX, y: bounds.minY + 6, width: bounds.width, height: bounds.height - 6)
        let path = NSBezierPath(roundedRect: bubble, xRadius: 8, yRadius: 8)

        // Tail
        let midX = bounds.midX
        path.move(to: NSPoint(x: midX - 5, y: bubble.minY))
        path.line(to: NSPoint(x: midX, y: bounds.minY))
        path.line(to: NSPoint(x: midX + 5, y: bubble.minY))
        path.close()

        NSColor(calibratedRed: 1, green: 0.98, blue: 0.94, alpha: 0.95).setFill()
        NSColor(calibratedRed: 0.2, green: 0.15, blue: 0.12, alpha: 0.85).setStroke()
        path.lineWidth = 1.5
        path.fill()
        path.stroke()

        ctx.flush()
    }
}
