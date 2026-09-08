import Foundation

enum Muscle: String, Codable, CaseIterable, Identifiable, Sendable {
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case adductors = "Adductors"
    case core = "Core"
    case chest = "Chest"
    case triceps = "Triceps"
    case shoulders = "Shoulders"
    case lats = "Lats"
    case upperBack = "Upper Back"
    case lowerBack = "Lower Back"
    case calves = "Calves"
    case tibialis = "Tibialis"
    case biceps = "Biceps"

    var id: String { rawValue }
}
