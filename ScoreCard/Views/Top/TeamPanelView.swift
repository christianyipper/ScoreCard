import SwiftUI

/// The team name field lives outside `TeamPanelView` so the header row (which
/// also holds the score box between the two teams) can be laid out
/// separately from the shots/goal/penalty columns below — otherwise the
/// score box's width pushes those columns apart.
struct TeamNameField: View {
    @EnvironmentObject var gameState: GameState
    let team: TeamSide

    private var teamNameBinding: Binding<String> {
        Binding(
            get: { gameState.teamNames[team] ?? defaultHeaderText },
            set: { gameState.teamNames[team] = $0 }
        )
    }

    private var defaultHeaderText: String { "\(team.defaultName) Shots" }

    var body: some View {
        TextField(defaultHeaderText, text: teamNameBinding)
            .font(AppTypography.teamName)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity)
    }
}

struct TeamPanelView: View {
    @EnvironmentObject var gameState: GameState
    let team: TeamSide

    @State private var isPenaltyTypePickerVisible = false
    @State private var selectedPenaltyTypes: Set<PenaltyType> = []

    private var accent: Color { gameState.accentColor(for: team) }

    private var actionButtonHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight + 16 * 2
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                container {
                    shotsRow
                }

                container {
                    HStack(spacing: 10) {
                        goalButton(label: "Goal", prefix: "")
                        outlinedGoalButton(label: "PP Goal", prefix: "PP", color: .green)
                        outlinedGoalButton(label: "SH Goal", prefix: "SH", color: .orange)
                    }
                }
            }
            // An overlay is exactly as tall as the view it's attached to, so
            // the dropdown covers the shots + goal-buttons cards precisely —
            // no manual height measurement needed. Add Penalty stays outside
            // this group, so it's never covered.
            .overlay {
                if isPenaltyTypePickerVisible {
                    penaltyTypePicker
                }
            }

            addPenaltyButton
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var addPenaltyButton: some View {
        if selectedPenaltyTypes.isEmpty {
            actionButton(
                fill: isPenaltyTypePickerVisible ? Color.orange.opacity(0.1) : nil,
                borderColor: isPenaltyTypePickerVisible ? .orange : .red
            ) {
                withAnimation {
                    isPenaltyTypePickerVisible.toggle()
                }
            } label: {
                Label(isPenaltyTypePickerVisible ? "Select Penalty" : "Add Penalty", systemImage: "exclamationmark.triangle.fill")
                    .fontWeight(.bold)
                    .foregroundStyle(isPenaltyTypePickerVisible ? .orange : .red)
            }
        } else {
            actionButton(fill: .red) {
                addPenalty()
            } label: {
                Label("Add Penalty", systemImage: "exclamationmark.triangle.fill")
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
    }

    private var penaltyTypePicker: some View {
        VStack(spacing: 8) {
            ForEach(PenaltyTypeRow.allCases, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row.types) { type in
                        penaltyTypeToggle(type)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func penaltyTypeToggle(_ type: PenaltyType) -> some View {
        let isSelected = selectedPenaltyTypes.contains(type)
        return Button {
            togglePenaltyType(type)
        } label: {
            Text(type.label)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.orange : Color.gray)
                )
        }
        .buttonStyle(.squish)
    }

    /// Each row is single-select: picking a type clears any other selection
    /// from the same row, while selections from the other row are left
    /// alone so they can combine (e.g. Minor + GM).
    private func togglePenaltyType(_ type: PenaltyType) {
        if selectedPenaltyTypes.contains(type) {
            selectedPenaltyTypes.remove(type)
        } else {
            if let row = PenaltyTypeRow.allCases.first(where: { $0.types.contains(type) }) {
                row.types.forEach { selectedPenaltyTypes.remove($0) }
            }
            selectedPenaltyTypes.insert(type)
        }
    }

    @ViewBuilder
    private func container<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var goalButtonCornerRadius: CGFloat { 8 }

    /// All the action buttons (Add Goal/Add Penalty/shots/etc.) are drawn
    /// manually with `.plain` + an explicit background instead of the
    /// system `.bordered`/`.borderedProminent` styles, which silently add
    /// their own extra content insets — that mismatch is what made the
    /// outlined buttons render shorter than the filled ones despite an
    /// identical `.frame(height:)`.
    private func actionButton<Label: View>(
        fill: Color?,
        borderColor: Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .frame(height: actionButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: goalButtonCornerRadius)
                        .fill(fill ?? Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: goalButtonCornerRadius)
                        .stroke(borderColor ?? Color.clear, lineWidth: borderColor != nil ? 4 : 0)
                )
        }
        .buttonStyle(.squish)
    }

    private func goalButton(label: String, prefix: String) -> some View {
        actionButton(fill: .green) {
            addGoal(prefix: prefix)
        } label: {
            Text(label)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }

    private func outlinedGoalButton(label: String, prefix: String, color: Color) -> some View {
        actionButton(fill: nil, borderColor: color) {
            addGoal(prefix: prefix)
        } label: {
            Text(label)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
    }

    /// Whatever's currently written in the Notes scratchpad becomes the new
    /// entry's text (prefixed to mark goal strength), then the scratchpad
    /// clears for the next note.
    private func addGoal(prefix: String) {
        let text = [prefix, gameState.draftNoteText]
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
        gameState.addGoal(GoalEntry(team: team, period: gameState.currentPeriod, text: text))
        gameState.consumeDraftNotepad()
    }

    private func addPenalty() {
        let types = PenaltyTypeRow.allCases.flatMap { row in
            row.types.filter { selectedPenaltyTypes.contains($0) }
        }
        gameState.addPenalty(PenaltyEntry(team: team, period: gameState.currentPeriod, types: types, text: gameState.draftNoteText))
        gameState.consumeDraftNotepad()
        selectedPenaltyTypes.removeAll()
        isPenaltyTypePickerVisible = false
    }

    private var shotsRow: some View {
        HStack(spacing: 10) {
            actionButton(fill: .gray) {
                gameState.addShot(for: team, delta: -1)
            } label: {
                Image(systemName: "minus")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            Text("\(gameState.shotCount(for: team, period: gameState.currentPeriod))")
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    Text("Shots")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(y: 14)
                }

            actionButton(fill: accent) {
                gameState.addShot(for: team, delta: 1)
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
    }
}
