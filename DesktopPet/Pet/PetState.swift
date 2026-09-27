import CoreGraphics
import Foundation

enum PetPosture: Equatable {
    case walkFloor
    case runFloor
    case climbLeft
    case climbRight
    case hangTop
    case idle
    case react
}

enum EdgeSide: Equatable {
    case bottom
    case left
    case right
    case top
}

enum PetGait: Equatable {
    case idle
    case walk
    case run

    var speed: CGFloat {
        switch self {
        case .idle: return 0
        case .walk: return 38
        case .run: return 78
        }
    }
}

struct PetMotionState: Equatable {
    var posture: PetPosture = .walkFloor
    var side: EdgeSide = .bottom
    /// Signed travel speed along the current edge (points/sec).
    var speed: CGFloat = PetGait.walk.speed
    var facingRight: Bool = false
    var isPaused: Bool = false
}
