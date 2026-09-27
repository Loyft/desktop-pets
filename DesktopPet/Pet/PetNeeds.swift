import Foundation

/// Stub model for future Tamagotchi-style interactivity.
/// Values are 0...1. Decay and UI are intentionally not wired yet.
struct PetNeeds: Equatable, Codable {
    var hunger: Double
    var energy: Double
    var happiness: Double

    static let fresh = PetNeeds(hunger: 0.8, energy: 0.9, happiness: 0.85)

    mutating func feed(amount: Double = 0.25) {
        hunger = min(1, hunger + amount)
        happiness = min(1, happiness + amount * 0.2)
    }

    mutating func play(amount: Double = 0.2) {
        happiness = min(1, happiness + amount)
        energy = max(0, energy - amount * 0.5)
        hunger = max(0, hunger - amount * 0.3)
    }

    mutating func sleep(amount: Double = 0.35) {
        energy = min(1, energy + amount)
        hunger = max(0, hunger - amount * 0.15)
    }

    /// Placeholder decay tick for a future timer. Safe to call; no side effects beyond mutating self.
    mutating func decay(deltaSeconds: TimeInterval) {
        let t = max(0, deltaSeconds)
        hunger = max(0, hunger - 0.002 * t)
        energy = max(0, energy - 0.001 * t)
        happiness = max(0, happiness - 0.0015 * t)
    }
}
