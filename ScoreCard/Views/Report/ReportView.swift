import SwiftUI

/// One goal or penalty line in the report's per-period grid.
private struct ReportEvent: Identifiable {
    let id: UUID
    let text: String
}

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
                    home: gameState.penalties.filter { $0.team == .home && $0.period == period }.map { ReportEvent(id: $0.id, text: $0.displayText) },
                    away: gameState.penalties.filter { $0.team == .away && $0.period == period }.map { ReportEvent(id: $0.id, text: $0.displayText) }
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
                    home: gameState.goals.filter { $0.team == .home && $0.period == period }.map { ReportEvent(id: $0.id, text: $0.text) },
                    away: gameState.goals.filter { $0.team == .away && $0.period == period }.map { ReportEvent(id: $0.id, text: $0.text) }
                )
            }
            statRow(
                label: "Total Goals",
                home: "\(gameState.goalCount(for: .home))",
                away: "\(gameState.goalCount(for: .away))",
                emphasized: true
            )

            gridSectionTitle("Goaltenders")
            ForEach(GoaltenderField.allCases, id: \.self) { field in
                statRow(
                    label: field.placeholder,
                    home: goaltenderValue(.home, field),
                    away: goaltenderValue(.away, field)
                )
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func goaltenderValue(_ team: TeamSide, _ field: GoaltenderField) -> String {
        let value = gameState.goaltenderDraft(for: team).display(field)
        return value.isEmpty ? "–" : value
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

    private func eventRow(period: GamePeriod, home: [ReportEvent], away: [ReportEvent]) -> some View {
        HStack(alignment: .top) {
            eventColumn(events: home, color: gameState.accentColor(for: .home), alignment: .leading)
            Text(period.fullLabel)
                .font(AppTypography.body)
                .frame(width: 110, alignment: .center)
            eventColumn(events: away, color: gameState.accentColor(for: .away), alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// Tapping an entry turns its text green; tapping again restores the
    /// team color.
    private func eventColumn(events: [ReportEvent], color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            if events.isEmpty {
                Text("–")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    Text(event.text.isEmpty ? "•" : event.text)
                        .fontWeight(.bold)
                        .foregroundStyle(gameState.highlightedEventIDs.contains(event.id) ? Color.green : color)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            gameState.toggleEventHighlight(event.id)
                        }
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
            if penalty.wrappedValue.infraction != nil {
                Text(penalty.wrappedValue.displayText)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("Penalty note", text: penalty.text)
                    .textFieldStyle(.roundedBorder)
                if !penalty.wrappedValue.types.isEmpty {
                    Text(penalty.wrappedValue.types.map(\.label).joined(separator: " + "))
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            }
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
