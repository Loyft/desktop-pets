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
        let origin = CGPoint(
            x: petFrame.midX - size / 2,
            y: petFrame.minY + petFrame.height * 0.55
        )
        for _ in 0..<n {
            addHeart(
                at: origin,
                spread: 18,
                vx: CGFloat.random(in: -12...12),
                vy: CGFloat.random(in: 22...38),
                life: TimeInterval.random(in: 1.6...2.4)
            )
        }
        wasActive = true
    }

    /// Click burst: hearts launch from the fox toward the cursor, then drift and fade.
    func spawnBurst(near petFrame: NSRect) {
        let n = Int.random(in: 3...5)
        let origin = CGPoint(
            x: petFrame.midX,
            y: petFrame.minY + petFrame.height * 0.58
        )
        let cursor = NSEvent.mouseLocation
        var dx = cursor.x - origin.x
        var dy = cursor.y - origin.y
        let len = max(40, hypot(dx, dy))
        dx /= len
        dy /= len
        let baseAngle = atan2(dy, dx)

        for _ in 0..<n {
            let angle = baseAngle + CGFloat.random(in: -0.55...0.55)
            let speed = CGFloat.random(in: 90...150)
            addHeart(
                at: CGPoint(x: origin.x - size / 2, y: origin.y - size / 2),
                spread: 10,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                life: TimeInterval.random(in: 1.8...2.8)
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
            p.x += p.vx * deltaTime
            p.y += p.vy * deltaTime
            // Soften speed so they float rather than rocket forever.
            p.vx *= 1.0 - 0.55 * deltaTime
            p.vy *= 1.0 - 0.35 * deltaTime
            // Gentle upward bias as they slow.
            p.vy += 18 * deltaTime

            let t = p.age / p.life
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

    private func addHeart(
        at origin: CGPoint,
        spread: CGFloat,
        vx: CGFloat,
        vy: CGFloat,
        life: TimeInterval
    ) {
        let panel = makeHeartPanel()
        let startX = origin.x + CGFloat.random(in: -spread...spread)
        let startY = origin.y + CGFloat.random(in: -spread * 0.4...spread * 0.4)
        panel.setFrame(
            NSRect(x: startX, y: startY, width: size, height: size),
            display: true
        )
        panel.alphaValue = 0.95
        panel.orderFrontRegardless()
        particles.append(
            Particle(panel: panel, x: startX, y: startY, vx: vx, vy: vy, life: life)
        )
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
