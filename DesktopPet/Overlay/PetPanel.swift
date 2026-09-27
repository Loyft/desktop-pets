import AppKit
import CoreVideo
import QuartzCore
import SpriteKit

final class PetPanel: NSPanel {
    private let skView: SKView
    private let scene: PetScene
    private let speechBubble = SpeechBubblePanel()
    private var pathController: EdgePathController!
    private var displayLink: CVDisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var lastStepTime: CFTimeInterval = 0
    private var isHiddenPet = false
    private let stepInterval: CFTimeInterval = 1.0 / 20.0

    private(set) var needs = PetNeeds.fresh

    var isPetVisible: Bool { !isHiddenPet && isVisible }

    convenience init() {
        let size = SpriteAnimator.displaySize
        self.init(
            contentRect: NSRect(origin: .zero, size: size),
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
        let size = SpriteAnimator.displaySize
        skView = SKView(frame: NSRect(origin: .zero, size: size))
        scene = PetScene(size: size)
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
        configureWindow()
        configureScene()
        configureMotion()
        startDisplayLink()
    }

    deinit {
        stopDisplayLink()
    }

    private func configureWindow() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = false

        skView.allowsTransparency = true
        skView.wantsLayer = true
        skView.layer?.isOpaque = false
        skView.isPaused = false
        skView.preferredFramesPerSecond = 30
        skView.showsFPS = false
        skView.showsNodeCount = false
        contentView = skView
    }

    override var canBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        pathController.triggerReact()
    }

    private func configureScene() {
        scene.onPetClicked = { [weak self] in
            self?.pathController.triggerReact()
        }
        skView.presentScene(scene)
    }

    private func configureMotion() {
        let geometry = ScreenEdgeGeometry(petSize: SpriteAnimator.displaySize)
        pathController = EdgePathController(geometry: geometry)
        setFrameOrigin(pathController.origin)

        pathController.onFrame = { [weak self] origin, motion in
            guard let self else { return }
            self.setFrameOrigin(origin)
            self.scene.apply(motion: motion, deltaTime: 0)
        }

        pathController.onSpeech = { [weak self] phrase in
            guard let self, !self.isHiddenPet else { return }
            self.speechBubble.show(text: phrase, above: self.frame)
        }
    }

    func setPetHidden(_ hidden: Bool) {
        isHiddenPet = hidden
        if hidden {
            speechBubble.hideBubble()
            orderOut(nil)
            pathController.setPaused(true)
        } else {
            pathController.setPaused(false)
            orderFrontRegardless()
        }
    }

    func setPaused(_ paused: Bool) {
        pathController.setPaused(paused)
    }

    func refreshScreenGeometry() {
        let geometry = ScreenEdgeGeometry(petSize: SpriteAnimator.displaySize)
        pathController.updateGeometry(geometry)
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        displayLink = link

        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo -> CVReturn in
            let panel = Unmanaged<PetPanel>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                panel.stepIfNeeded()
            }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())

        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        if let displayLink {
            CVDisplayLinkStop(displayLink)
        }
        displayLink = nil
    }

    private func stepIfNeeded() {
        guard !isHiddenPet else { return }
        let now = CACurrentMediaTime()
        if lastStepTime != 0, now - lastStepTime < stepInterval {
            return
        }
        let dt: TimeInterval
        if lastTimestamp == 0 {
            dt = stepInterval
        } else {
            dt = now - lastTimestamp
        }
        lastTimestamp = now
        lastStepTime = now

        // Accessory apps auto-pause SKView; keep it alive so texture swaps paint.
        skView.isPaused = false
        scene.isPaused = false

        let clamped = min(dt, 0.1)
        pathController.tick(deltaTime: clamped)
        // Drive sprite frames from the same cadence as motion (SKAction pauses in accessory apps).
        scene.apply(motion: pathController.motion, deltaTime: clamped)

        // Keep bubble glued above the pet while visible.
        if speechBubble.isVisible {
            speechBubble.setFrameOrigin(NSPoint(
                x: frame.midX - speechBubble.frame.width / 2,
                y: frame.minY + frame.height * 0.56
            ))
        }
    }
}
