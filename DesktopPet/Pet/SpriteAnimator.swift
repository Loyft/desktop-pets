import SpriteKit

enum AnimationSet: String {
    case walk
    case run
    case climb
    case hang
    case idle
    case react
}

final class SpriteAnimator {
    private let sprite: SKSpriteNode
    private var currentSet: AnimationSet?
    /// Directional series: [facingRight][frame]
    private var textures: [AnimationSet: [Bool: [SKTexture]]] = [:]
    /// Climb-down (vertically flipped) series keyed by right-wall.
    private var climbDownTextures: [Bool: [SKTexture]] = [:]
    private var frameIndex = 0
    private var frameAccum: TimeInterval = 0
    private var timePerFrame: TimeInterval = 1.0 / 8.0
    private var loops = true
    private var facingRight = false
    private var travelDown = false

    /// No xScale flip — left/right art is authored separately.
    static let displayScale: CGFloat = 2
    static let nativeSize: CGFloat = 64
    static var displaySize: CGSize {
        let s = nativeSize * displayScale
        return CGSize(width: s, height: s)
    }

    init(sprite: SKSpriteNode) {
        self.sprite = sprite
        loadTextures()
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        sprite.xScale = 1
        sprite.yScale = 1
        sprite.size = Self.displaySize
        if let first = frames(for: .walk, facingRight: false).first {
            first.filteringMode = .nearest
            sprite.texture = first
        }
    }

    private func loadTextures() {
        textures[.walk] = [
            false: loadSeries(prefix: "walk_l", count: 6),
            true: loadSeries(prefix: "walk_r", count: 6),
        ]
        textures[.run] = [
            false: loadSeries(prefix: "run_l", count: 6),
            true: loadSeries(prefix: "run_r", count: 6),
        ]
        textures[.idle] = [
            false: loadSeries(prefix: "idle_l", count: 4),
            true: loadSeries(prefix: "idle_r", count: 4),
        ]
        textures[.react] = [
            false: loadSeries(prefix: "react_l", count: 8),
            true: loadSeries(prefix: "react_r", count: 8),
        ]
        textures[.climb] = [
            false: loadSeries(prefix: "climb_l", count: 10),
            true: loadSeries(prefix: "climb_r", count: 10),
        ]
        climbDownTextures = [
            false: loadSeries(prefix: "climb_ld", count: 10),
            true: loadSeries(prefix: "climb_rd", count: 10),
        ]
        textures[.hang] = [
            false: loadSeries(prefix: "hang_l", count: 8),
            true: loadSeries(prefix: "hang_r", count: 8),
        ]
    }

    private func loadSeries(prefix: String, count: Int) -> [SKTexture] {
        (0..<count).compactMap { index in
            let name = String(format: "%@_%02d", prefix, index)
            let texture = SKTexture(imageNamed: name)
            guard texture.size().width > 0 else { return nil }
            texture.filteringMode = .nearest
            texture.usesMipmaps = false
            return texture
        }
    }

    private func frames(for set: AnimationSet, facingRight: Bool) -> [SKTexture] {
        if set == .climb, travelDown {
            return climbDownTextures[facingRight] ?? []
        }
        return textures[set]?[facingRight] ?? []
    }

    func play(_ set: AnimationSet, facingRight: Bool, travelDown: Bool = false) {
        let facingChanged = self.facingRight != facingRight
        let setChanged = currentSet != set
        let travelChanged = self.travelDown != travelDown
        self.facingRight = facingRight
        self.travelDown = travelDown

        if !setChanged && !facingChanged && !travelChanged, sprite.texture != nil {
            return
        }

        currentSet = set
        if setChanged || travelChanged {
            frameIndex = 0
            frameAccum = 0
        }
        loops = set != .react

        switch set {
        case .walk:
            timePerFrame = 1.0 / 9.0
        case .run:
            timePerFrame = 1.0 / 12.0
        case .climb, .hang:
            timePerFrame = 1.0 / 10.0
        case .idle:
            timePerFrame = 1.0 / 4.0
        case .react:
            timePerFrame = 1.0 / 12.0
        }

        applyCurrentFrame()
    }

    func tick(deltaTime: TimeInterval) {
        guard let set = currentSet else { return }
        let frames = frames(for: set, facingRight: facingRight)
        guard frames.count > 1 else { return }

        frameAccum += deltaTime
        var advanced = false
        while frameAccum >= timePerFrame {
            frameAccum -= timePerFrame
            frameIndex += 1
            if frameIndex >= frames.count {
                if loops {
                    frameIndex = 0
                } else {
                    frameIndex = frames.count - 1
                    currentSet = nil
                    break
                }
            }
            advanced = true
        }
        if advanced {
            applyCurrentFrame()
        }
    }

    private func applyCurrentFrame() {
        guard let set = currentSet else { return }
        let frames = frames(for: set, facingRight: facingRight)
        guard !frames.isEmpty else { return }
        let index = min(frameIndex, frames.count - 1)
        let texture = frames[index]
        texture.filteringMode = .nearest
        sprite.texture = texture
        sprite.xScale = 1
        sprite.yScale = 1
        sprite.size = Self.displaySize
    }

    func stop() {
        currentSet = nil
        frameAccum = 0
    }

    static func animationSet(for posture: PetPosture) -> AnimationSet {
        switch posture {
        case .walkFloor: return .walk
        case .runFloor: return .run
        case .climbLeft, .climbRight: return .climb
        case .hangTop: return .hang
        case .idle: return .idle
        case .react: return .react
        }
    }

    /// Map motion to art facing + climb-down flag so the fox always looks along its path.
    static func artSelection(for motion: PetMotionState) -> (facingRight: Bool, travelDown: Bool) {
        switch motion.posture {
        case .climbLeft:
            // Left-wall art; use down series when descending.
            return (false, motion.speed < 0)
        case .climbRight:
            return (true, motion.speed < 0)
        case .hangTop:
            // 180° hang art swaps authored L/R vs screen direction.
            return (motion.speed < 0, false)
        default:
            return (motion.facingRight, false)
        }
    }
}
