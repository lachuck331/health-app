import SwiftUI
import MuscleMap

/// A production-grade front/back map built from segmented anatomical SVG paths.
/// Keeping both surfaces visible makes the recovery state scannable without rotation.
struct AnatomySceneView: View {
    let readiness: [Muscle: Double]
    let onMuscleTap: (Muscle) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            figure(side: .front, label: "FRONT")
            figure(side: .back, label: "BACK")
        }
        .padding(.horizontal, 10)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    private func figure(side: BodySide, label: String) -> some View {
        VStack(spacing: 4) {
            BodyView(gender: .male, side: side, style: bodyStyle)
                .showSubGroups()
                .heatmap(anatomyIntensities)
                .onMuscleSelected { mappedMuscle, _ in
                    guard let muscle = muscle(for: mappedMuscle) else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onMuscleTap(muscle)
                }
                .frame(height: 350)
                .accessibilityHint("Tap a highlighted muscle to view details")

            Text(label)
                .font(.caption2.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(.tertiary)
        }
    }

    private var bodyStyle: BodyViewStyle {
        BodyViewStyle(
            defaultFillColor: Color(uiColor: .systemGray5),
            strokeColor: Color.primary.opacity(0.18),
            strokeWidth: 0.65,
            selectionColor: .blue,
            selectionStrokeColor: .blue,
            selectionStrokeWidth: 1.5,
            headColor: Color(uiColor: .systemGray5),
            hairColor: Color(uiColor: .systemGray3),
            shadowColor: .black.opacity(0.08),
            shadowRadius: 2,
            shadowOffset: CGSize(width: 0, height: 1)
        )
    }

    private var anatomyIntensities: [MuscleIntensity] {
        Muscle.allCases.flatMap { muscle in
            let score = readiness[muscle, default: 100]
            let color: Color = score >= 65 ? .green : .red
            return mapMuscles(for: muscle).map {
                MuscleIntensity(muscle: $0, intensity: 1, color: color)
            }
        }
    }

    private func mapMuscles(for muscle: Muscle) -> [MuscleMap.Muscle] {
        switch muscle {
        case .quads: [.quadriceps]
        case .hamstrings: [.hamstring]
        case .glutes: [.gluteal]
        case .adductors: [.adductors]
        case .core: [.abs, .obliques]
        case .chest: [.chest]
        case .triceps: [.triceps]
        case .shoulders: [.deltoids]
        case .lats: [.upperBack]
        case .upperBack: [.trapezius, .rhomboids]
        case .lowerBack: [.lowerBack]
        case .calves: [.calves]
        case .tibialis: [.tibialis]
        case .biceps: [.biceps]
        }
    }

    private func muscle(for mapped: MuscleMap.Muscle) -> Muscle? {
        switch mapped {
        case .quadriceps, .innerQuad, .outerQuad, .hipFlexors: .quads
        case .hamstring: .hamstrings
        case .adductors: .adductors
        case .gluteal: .glutes
        case .abs, .upperAbs, .lowerAbs, .obliques, .serratus: .core
        case .chest, .upperChest, .lowerChest: .chest
        case .triceps: .triceps
        case .deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff: .shoulders
        case .upperBack: .lats
        case .trapezius, .upperTrapezius, .lowerTrapezius, .rhomboids: .upperBack
        case .lowerBack: .lowerBack
        case .calves: .calves
        case .tibialis: .tibialis
        case .biceps: .biceps
        case .ankles, .feet, .forearm, .hands, .head, .knees, .neck: nil
        }
    }
}
