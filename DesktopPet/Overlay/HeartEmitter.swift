import AppKit

/// Spawns tiny heart panels that drift upward and fade out.
final class HeartEmitter {
    private final class Particle {
        let panel: NSPanel
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var age: TimeInterval = 0
        let life: TimeInterval

        init(panel: NSPanel, x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, life: TimeInterval) {
            self.panel = panel
            self.x = x
            self.y = y
            self.vx = vx
            self.vy = vy
            self.life = life
        }
    }

    private var particles: [Particle] = []
    private let size: CGFloat = 18
    private var wasActive = false

    /// Fired when the last heart finishes fading out.
    var onDidBecomeIdle: (() -> Void)?

    var isActive: Bool { !particles.isEmpty }

    func spawn(near petFrame: NSRect, count: Int? = nil) {
        let n = count ?? Int.random(in: 1...3)
        for _ in 0..<n {
            let panel = makeHeartPanel()
            let startX = petFrame.midX - size / 2 + CGFloat.random(in: -18...18)
            let startY = petFrame.minY + petFrame.height * 0.55 + CGFloat.random(in: -4...10)
            panel.setFrame(
                NSRect(x: startX, y: startY, width: size, height: size),
                display: true
            )
            panel.alphaValue = 0.95
            panel.orderFrontRegardless()
            particles.append(
                Particle(
                    panel: panel,
                    x: startX,
                    y: startY,
                    vx: CGFloat.random(in: -12...12),
                    vy: CGFloat.random(in: 22...38),
                    life: TimeInterval.random(in: 1.6...2.4)
                )
            )
        }
        wasActive = true
    }

    func tick(deltaTime: TimeInterval) {
        guard !particles.isEmpty else { return }
        var kept: [Particle] = []
        kept.reserveCapacity(particles.count)
        for p in particles {
            p.age += deltaTime
            if p.age >= p.life {
                p.panel.orderOut(nil)
                continue
            }
            let t = p.age / p.life
            p.x += p.vx * deltaTime
            p.y += p.vy * deltaTime
            p.vy *= 1.0 - 0.15 * deltaTime
            p.panel.setFrameOrigin(NSPoint(x: p.x, y: p.y))
            p.panel.alphaValue = CGFloat(1.0 - t * t)
            kept.append(p)
        }
        particles = kept
        if wasActive, particles.isEmpty {
            wasActive = false
            onDidBecomeIdle?()
        }
    }

    func clear() {
        for p in particles {
            p.panel.orderOut(nil)
        }
        let shouldNotify = wasActive || !particles.isEmpty
        particles.removeAll()
        wasActive = false
        if shouldNotify {
            onDidBecomeIdle?()
        }
    }

    /// Drop hearts without releasing the overlay slot (used when preempted).
    func clearSilently() {
        for p in particles {
            p.panel.orderOut(nil)
        }
        particles.removeAll()
        wasActive = false
    }

    private func makeHeartPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false

        let label = NSTextField(labelWithString: "♥")
        label.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = NSColor(calibratedRed: 0.92, green: 0.32, blue: 0.45, alpha: 1)
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.drawsBackground = false
        label.frame = NSRect(x: 0, y: 0, width: size, height: size)
        panel.contentView = label
        return panel
    }
}
