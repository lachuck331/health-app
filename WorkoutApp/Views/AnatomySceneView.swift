import SwiftUI
import MuscleMap

/// A production-grade front/back map built from segmented anatomical SVG paths.
/// Keeping both surfaces visible makes the recovery state scannable without rotation.
struct AnatomySceneView: View {
    let readiness: [Muscle: Double]
    let focusedMuscle: Muscle?
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
                .selected(selectedMapMuscles)
                .onMuscleSelected { mappedMuscle, _ in
                    guard let muscle = muscle(for: mappedMuscle) else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onMuscleTap(muscle)
                }
                .frame(height: focusedMuscle == nil ? 350 : 225)
                .scaleEffect(figureScale(for: side))
                .opacity(figureOpacity(for: side))
                .animation(.snappy(duration: 0.36, extraBounce: 0.05), value: focusedMuscle)
                .accessibilityHint("Tap a highlighted muscle to view details")

            Text(label)
                .font(.caption2.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(.tertiary)
                .opacity(focusedMuscle == nil || figureOpacity(for: side) == 1 ? 1 : 0.3)
        }
    }

    private var bodyStyle: BodyViewStyle {
        let selectionColor = focusedMuscle.map {
            ReadinessColorScale.color(for: readiness[$0, default: 100])
        } ?? .blue

        return BodyViewStyle(
            defaultFillColor: Color(uiColor: focusedMuscle == nil ? .systemGray5 : .systemGray6),
            strokeColor: focusedMuscle == nil ? Color.primary.opacity(0.18) : .clear,
            strokeWidth: 0.65,
            selectionColor: selectionColor,
            selectionStrokeColor: .white.opacity(0.92),
            selectionStrokeWidth: 1.6,
            headColor: Color(uiColor: .systemGray5),
            hairColor: Color(uiColor: .systemGray3),
            shadowColor: .black.opacity(0.08),
            shadowRadius: 2,
            shadowOffset: CGSize(width: 0, height: 1)
        )
    }

    private var anatomyIntensities: [MuscleIntensity] {
        let visibleMuscles = focusedMuscle.map { [$0] } ?? Muscle.allCases
        return visibleMuscles.flatMap { muscle in
            let score = readiness[muscle, default: 100]
            let color = ReadinessColorScale.color(for: score)
            return mapMuscles(for: muscle).map {
                MuscleIntensity(muscle: $0, intensity: 1, color: color)
            }
        }
    }

    private var selectedMapMuscles: Set<MuscleMap.Muscle> {
        Set(focusedMuscle.map(mapMuscles(for:)) ?? [])
    }

    private func figureScale(for side: BodySide) -> CGFloat {
        guard focusedMuscle != nil else { return 1 }
        return isFocusedSide(side) ? 1.07 : 0.92
    }

    private func figureOpacity(for side: BodySide) -> Double {
        guard focusedMuscle != nil else { return 1 }
        return isFocusedSide(side) ? 1 : 0.24
    }

    private func isFocusedSide(_ side: BodySide) -> Bool {
        guard let focusedMuscle else { return true }
        switch focusedMuscle {
        case .chest, .biceps, .core, .quads, .adductors, .tibialis:
            return side == .front
        case .hamstrings, .glutes, .triceps, .lats, .upperBack, .lowerBack, .calves:
            return side == .back
        case .shoulders:
            return true
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
