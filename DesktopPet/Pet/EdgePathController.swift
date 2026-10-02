import AppKit
import Foundation

/// Moves the pet along screen edges with walk / run / idle variety.
final class EdgePathController {
    private(set) var motion = PetMotionState()
    private var geometry: ScreenEdgeGeometry
    private(set) var origin: CGPoint

    private var gaitCooldown: TimeInterval = TimeInterval.random(in: 4...9)
    private var idleRemaining: TimeInterval = 0
    private var reactRemaining: TimeInterval = 0
    private var speechCooldown: TimeInterval = TimeInterval.random(in: 8...16)
    private var heartCooldown: TimeInterval = TimeInterval.random(in: 10...22)
    private var currentGait: PetGait = .walk

    var onFrame: ((CGPoint, PetMotionState) -> Void)?
    var onSpeech: ((String) -> Void)?
    var onHearts: (() -> Void)?

    private static let phrases = [
        "yip", "yap", "arf", "...", "huff", "mrrp", "sniff", "wow",
    ]

    init(geometry: ScreenEdgeGeometry) {
        self.geometry = geometry
        self.origin = geometry.startingOrigin(for: .bottom)
        motion.facingRight = Bool.random()
        applyGait(.walk, keepDirection: true)
    }

    func updateGeometry(_ geometry: ScreenEdgeGeometry) {
        self.geometry = geometry
        origin = geometry.clamp(origin, to: motion.side)
    }

    func setPaused(_ paused: Bool) {
        motion.isPaused = paused
    }

    func triggerReact(speak: Bool = true) {
        guard motion.posture != .react else { return }
        motion.posture = .react
        reactRemaining = 1.1
        if speak {
            onSpeech?(Self.phrases.randomElement() ?? "yip")
            speechCooldown = TimeInterval.random(in: 6...14)
        }
        onFrame?(origin, motion)
    }

    func tick(deltaTime: TimeInterval) {
        guard !motion.isPaused, deltaTime > 0, deltaTime < 1 else {
            onFrame?(origin, motion)
            return
        }

        maybeSpeak(deltaTime: deltaTime)
        maybeHearts(deltaTime: deltaTime)

        if motion.posture == .react {
            reactRemaining -= deltaTime
            if reactRemaining <= 0 {
                resumeAfterReact()
            }
            onFrame?(origin, motion)
            return
        }

        if motion.posture == .idle {
            idleRemaining -= deltaTime
            if idleRemaining <= 0 {
                // Leave idle into walk or run.
                let next: PetGait = Double.random(in: 0...1) < 0.45 ? .run : .walk
                applyGait(next, keepDirection: true)
                resumeLocomotionPosture()
                gaitCooldown = TimeInterval.random(in: 3.5...8)
            }
            onFrame?(origin, motion)
            return
        }

        // On the floor: mix idle / walk / run.
        if motion.side == .bottom {
            gaitCooldown -= deltaTime
            if gaitCooldown <= 0 {
                pickNextFloorGait()
                gaitCooldown = TimeInterval.random(in: 3.5...9)
                // Idle must not fall through into the locomotion branch below,
                // which would overwrite posture with walkFloor on the same tick.
                if motion.posture == .idle {
                    onFrame?(origin, motion)
                    return
                }
            }
        }

        let distance = CGFloat(deltaTime) * abs(motion.speed)
        let sign: CGFloat = motion.speed >= 0 ? 1 : -1

        switch motion.side {
        case .bottom:
            origin.x += distance * sign
            origin.y = geometry.minY
            if motion.speed != 0 {
                motion.facingRight = motion.speed > 0
            }
            if currentGait == .idle {
                motion.posture = .idle
            } else if currentGait == .run {
                motion.posture = .runFloor
            } else {
                motion.posture = .walkFloor
            }
            if origin.x <= geometry.minX {
                origin.x = geometry.minX
                handleBottomEdge(hitLeft: true)
            } else if origin.x >= geometry.maxX {
                origin.x = geometry.maxX
                handleBottomEdge(hitLeft: false)
            }

        case .left:
            origin.x = geometry.minX
            origin.y += distance * sign
            motion.posture = .climbLeft
            // facingRight tracks travel "up" for consistency; art uses posture + speed.
            motion.facingRight = motion.speed > 0
            if origin.y >= geometry.maxY {
                origin.y = geometry.maxY
                handleVerticalPeak(fromLeft: true)
            } else if origin.y <= geometry.minY {
                origin.y = geometry.minY
                beginFloorTravel(headingRight: true)
            }

        case .right:
            origin.x = geometry.maxX
            origin.y += distance * sign
            motion.posture = .climbRight
            motion.facingRight = motion.speed > 0
            if origin.y >= geometry.maxY {
                origin.y = geometry.maxY
                handleVerticalPeak(fromLeft: false)
            } else if origin.y <= geometry.minY {
                origin.y = geometry.minY
                beginFloorTravel(headingRight: false)
            }

        case .top:
            origin.y = geometry.maxY
            origin.x += distance * sign
            motion.posture = .hangTop
            // Screen direction of travel (hang art L/R is corrected in SpriteAnimator).
            motion.facingRight = motion.speed > 0
            if origin.x <= geometry.minX {
                origin.x = geometry.minX
                handleTopCorner(left: true)
            } else if origin.x >= geometry.maxX {
                origin.x = geometry.maxX
                handleTopCorner(left: false)
            }
        }

        origin = geometry.clamp(origin, to: motion.side)
        onFrame?(origin, motion)
    }

    // MARK: - Gait

    private func pickNextFloorGait() {
        let roll = Double.random(in: 0...1)
        if roll < 0.38 {
            currentGait = .idle
            motion.posture = .idle
            motion.speed = 0
            idleRemaining = TimeInterval.random(in: 2.2...4.5)
        } else if roll < 0.72 {
            applyGait(.walk, keepDirection: true)
            motion.posture = .walkFloor
        } else {
            applyGait(.run, keepDirection: true)
            motion.posture = .runFloor
        }
    }

    private func applyGait(_ gait: PetGait, keepDirection: Bool) {
        currentGait = gait
        let goingRight = keepDirection ? motion.facingRight : Bool.random()
        let magnitude = gait.speed
        if magnitude == 0 {
            motion.speed = 0
        } else {
            motion.speed = goingRight ? magnitude : -magnitude
            motion.facingRight = goingRight
        }
    }

    private func resumeLocomotionPosture() {
        switch motion.side {
        case .bottom:
            motion.posture = currentGait == .run ? .runFloor : .walkFloor
        case .left:
            motion.posture = .climbLeft
        case .right:
            motion.posture = .climbRight
        case .top:
            motion.posture = .hangTop
        }
    }

    // MARK: - Edges

    private func handleBottomEdge(hitLeft: Bool) {
        if Double.random(in: 0...1) < 0.7 {
            beginFloorTravel(headingRight: hitLeft)
        } else {
            beginClimb(left: hitLeft)
        }
    }

    private func handleVerticalPeak(fromLeft: Bool) {
        if Double.random(in: 0...1) < 0.55 {
            beginHang(fromLeft: fromLeft)
        } else {
            motion.speed = -abs(max(motion.speed, PetGait.walk.speed))
        }
    }

    private func handleTopCorner(left: Bool) {
        beginDescend(left: left)
    }

    private func beginClimb(left: Bool) {
        motion.side = left ? .left : .right
        motion.posture = left ? .climbLeft : .climbRight
        let magnitude = max(PetGait.walk.speed, abs(motion.speed))
        motion.speed = magnitude // climb up
        motion.facingRight = true
        currentGait = .walk
    }

    private func beginHang(fromLeft: Bool) {
        motion.side = .top
        motion.posture = .hangTop
        let magnitude = max(PetGait.walk.speed, abs(motion.speed))
        // Arrive from left wall → travel right along the top; from right → travel left.
        motion.speed = fromLeft ? magnitude : -magnitude
        motion.facingRight = fromLeft
    }

    private func beginDescend(left: Bool) {
        motion.side = left ? .left : .right
        motion.posture = left ? .climbLeft : .climbRight
        let magnitude = max(PetGait.walk.speed, abs(motion.speed))
        motion.speed = -magnitude // climb down
        motion.facingRight = false
    }

    private func beginFloorTravel(headingRight: Bool) {
        motion.side = .bottom
        motion.facingRight = headingRight
        let gait: PetGait = Double.random(in: 0...1) < 0.4 ? .run : .walk
        currentGait = gait
        motion.speed = headingRight ? gait.speed : -gait.speed
        motion.posture = gait == .run ? .runFloor : .walkFloor
        gaitCooldown = TimeInterval.random(in: 3.5...8)
    }

    private func resumeAfterReact() {
        if motion.side == .bottom, currentGait == .idle {
            pickNextFloorGait()
        } else {
            resumeLocomotionPosture()
            if motion.speed == 0, motion.side == .bottom {
                applyGait(.walk, keepDirection: true)
                motion.posture = .walkFloor
            }
        }
    }

    private func maybeSpeak(deltaTime: TimeInterval) {
        speechCooldown -= deltaTime
        if speechCooldown > 0 { return }
        guard motion.posture != .react else { return }
        if Double.random(in: 0...1) < 0.7 {
            onSpeech?(Self.phrases.randomElement() ?? "yip")
        }
        speechCooldown = TimeInterval.random(in: 7...16)
    }

    private func maybeHearts(deltaTime: TimeInterval) {
        heartCooldown -= deltaTime
        if heartCooldown > 0 { return }
        guard motion.posture != .react else { return }
        if Double.random(in: 0...1) < 0.45 {
            onHearts?()
        }
        heartCooldown = TimeInterval.random(in: 12...28)
    }
}
