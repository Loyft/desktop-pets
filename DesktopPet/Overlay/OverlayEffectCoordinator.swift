import Foundation

/// Serializes floating chrome (speech, hearts, …) so they never overlap in time.
final class OverlayEffectCoordinator {
    enum Effect: Hashable {
        case hearts
        case speech
        case heartBurst

        /// Higher wins when something must preempt.
        var priority: Int {
            switch self {
            case .hearts: return 0
            case .speech: return 1
            case .heartBurst: return 2
            }
        }

        var isHearts: Bool {
            self == .hearts || self == .heartBurst
        }
    }

    /// Called when a lower-priority effect is bumped by a higher one (clear UI here).
    var onPreempt: ((Effect) -> Void)?

    private var active: Effect?
    private var queue: [(Effect, () -> Void)] = []

    func present(_ effect: Effect, _ action: @escaping () -> Void) {
        if let active {
            if effect.priority > active.priority {
                // Claim the slot before clearing so preempted end() callbacks are ignored.
                let bumped = active
                self.active = effect
                onPreempt?(bumped)
                action()
                return
            }
            // Same effect: replace in place (e.g. new bubble text).
            if effect == active {
                action()
                return
            }
            // Lower / equal: keep one pending slot per effect.
            queue.removeAll { $0.0 == effect }
            queue.append((effect, action))
            queue.sort { $0.0.priority > $1.0.priority }
            return
        }

        active = effect
        action()
    }

    func end(_ effect: Effect) {
        guard active == effect else {
            queue.removeAll { $0.0 == effect }
            return
        }
        active = nil
        drain()
    }

    /// Release whichever hearts effect is currently occupying the lane.
    func endActiveHearts() {
        guard let active, active.isHearts else {
            queue.removeAll { $0.0.isHearts }
            return
        }
        end(active)
    }

    func clear() {
        active = nil
        queue.removeAll()
    }

    private func drain() {
        guard active == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        active = next.0
        next.1()
    }
}
