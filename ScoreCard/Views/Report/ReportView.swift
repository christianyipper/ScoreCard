import SwiftUI

struct ReportView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsGrid
                HStack(alignment: .top, spacing: 16) {
                    eventLog(for: .home)
                    eventLog(for: .away)
                }
                goaltendersSection
            }
            .padding()
        }
    }

    private var header: some View {
        ZStack {
            Text("Game Report")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Text(gameState.teamNames[.home] ?? TeamSide.home.defaultName)
                    .font(AppTypography.teamName)
                    .foregroundStyle(gameState.accentColor(for: .home))
                Spacer()
                Text(gameState.teamNames[.away] ?? TeamSide.away.defaultName)
                    .font(AppTypography.teamName)
                    .foregroundStyle(gameState.accentColor(for: .away))
            }
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 0) {
            gridSectionTitle("Shots on Goal")
            ForEach(GamePeriod.allCases) { period in
                statRow(
                    label: period.fullLabel,
                    home: "\(gameState.shotCount(for: .home, period: period))",
                    away: "\(gameState.shotCount(for: .away, period: period))"
                )
            }
            statRow(
                label: "Total Shots",
                home: "\(gameState.shotTotal(for: .home))",
                away: "\(gameState.shotTotal(for: .away))",
                emphasized: true
            )

            gridSectionTitle("Penalties")
            ForEach(GamePeriod.allCases) { period in
                eventRow(
                    period: period,
                    homeTexts: gameState.penalties.filter { $0.team == .home && $0.period == period }.map(\.displayText),
                    awayTexts: gameState.penalties.filter { $0.team == .away && $0.period == period }.map(\.displayText)
                )
            }
            statRow(
                label: "Total Penalties",
                home: "\(gameState.penaltyCount(for: .home))",
                away: "\(gameState.penaltyCount(for: .away))",
                emphasized: true
            )

            gridSectionTitle("Goals")
            ForEach(GamePeriod.allCases) { period in
                eventRow(
                    period: period,
                    homeTexts: gameState.goals.filter { $0.team == .home && $0.period == period }.map(\.text),
                    awayTexts: gameState.goals.filter { $0.team == .away && $0.period == period }.map(\.text)
                )
            }
            statRow(
                label: "Total Goals",
                home: "\(gameState.goalCount(for: .home))",
                away: "\(gameState.goalCount(for: .away))",
                emphasized: true
            )
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func gridSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.body.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private func statRow(label: String, home: String, away: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(home)
                .font(AppTypography.body.bold().monospacedDigit())
                .foregroundStyle(gameState.accentColor(for: .home))
                .frame(width: 80, alignment: .leading)
            Text(label)
                .font(emphasized ? AppTypography.body.bold() : AppTypography.body)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(away)
                .font(AppTypography.body.bold().monospacedDigit())
                .foregroundStyle(gameState.accentColor(for: .away))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(emphasized ? Color.primary.opacity(0.05) : Color.clear)
    }

    private func eventRow(period: GamePeriod, homeTexts: [String], awayTexts: [String]) -> some View {
        HStack(alignment: .top) {
            eventColumn(texts: homeTexts, color: gameState.accentColor(for: .home), alignment: .leading)
            Text(period.fullLabel)
                .font(AppTypography.body)
                .frame(width: 110, alignment: .center)
            eventColumn(texts: awayTexts, color: gameState.accentColor(for: .away), alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func eventColumn(texts: [String], color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            if texts.isEmpty {
                Text("–")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                    Text(text.isEmpty ? "•" : text)
                        .fontWeight(.bold)
                }
            }
        }
        .font(AppTypography.body)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func eventLog(for team: TeamSide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(gameState.teamNames[team] ?? team.defaultName) Events")
                .font(.headline)

            ForEach(GamePeriod.allCases) { period in
                let goals = gameState.goals.filter { $0.team == team && $0.period == period }
                let pens = gameState.penalties.filter { $0.team == team && $0.period == period }
                if !goals.isEmpty || !pens.isEmpty {
                    Text(period.fullLabel)
                        .font(AppTypography.body.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach($gameState.goals) { $goal in
                        if goal.team == team && goal.period == period {
                            goalRow($goal)
                        }
                    }
                    ForEach($gameState.penalties) { $penalty in
                        if penalty.team == team && penalty.period == period {
                            penaltyRow($penalty)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var goaltendersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goaltenders")
                .font(AppTypography.body.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .top, spacing: 16) {
                goaltenderCard(for: .home)
                goaltenderCard(for: .away)
            }
        }
    }

    private func goaltenderCard(for team: TeamSide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gameState.teamNames[team] ?? team.defaultName)
                .font(.headline)
                .foregroundStyle(gameState.accentColor(for: team))

            TextEditor(text: goaltenderNotesBinding(for: team))
                .font(AppTypography.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(6)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func goaltenderNotesBinding(for team: TeamSide) -> Binding<String> {
        Binding(
            get: { gameState.goaltenderNotes[team] ?? "" },
            set: { gameState.goaltenderNotes[team] = $0 }
        )
    }

    private func goalRow(_ goal: Binding<GoalEntry>) -> some View {
        HStack(spacing: 6) {
            Text("⭐️")
            TextField("Goal note", text: goal.text)
                .textFieldStyle(.roundedBorder)
            Button(role: .destructive) {
                gameState.deleteGoal(goal.wrappedValue)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.squish)
            .foregroundStyle(.secondary)
        }
        .font(AppTypography.body)
    }

    private func penaltyRow(_ penalty: Binding<PenaltyEntry>) -> some View {
        HStack(spacing: 6) {
            Text("⚠️")
            if !penalty.wrappedValue.types.isEmpty {
                Text(penalty.wrappedValue.types.map(\.label).joined(separator: " + "))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            TextField("Penalty note", text: penalty.text)
                .textFieldStyle(.roundedBorder)
            Button(role: .destructive) {
                gameState.deletePenalty(penalty.wrappedValue)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.squish)
            .foregroundStyle(.secondary)
        }
        .font(AppTypography.body)
    }
}
