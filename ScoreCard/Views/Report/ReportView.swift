import SwiftUI

struct ReportView: View {
    @EnvironmentObject var gameState: GameState

    private func opponent(of team: TeamSide) -> TeamSide { team == .home ? .away : .home }

    private func powerPlayChances(for team: TeamSide) -> Int {
        gameState.penalties.filter { $0.team == opponent(of: team) && $0.type.affectsStrength }.count
    }

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
        HStack {
            Text(gameState.teamNames[.home] ?? "Home")
                .font(.title.bold())
                .foregroundStyle(.blue)
            Spacer()
            Text("Game Report")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(gameState.teamNames[.away] ?? "Away")
                .font(.title.bold())
                .foregroundStyle(.orange)
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
                statRow(
                    label: period.fullLabel,
                    home: "\(gameState.penaltyCount(for: .home, period: period))",
                    away: "\(gameState.penaltyCount(for: .away, period: period))"
                )
            }
            statRow(
                label: "Total Penalties",
                home: "\(gameState.penaltyCount(for: .home))",
                away: "\(gameState.penaltyCount(for: .away))",
                emphasized: true
            )
            statRow(
                label: "Power Play Chances",
                home: "\(powerPlayChances(for: .home))",
                away: "\(powerPlayChances(for: .away))",
                emphasized: true
            )

            gridSectionTitle("Goals")
            ForEach(GamePeriod.allCases) { period in
                statRow(
                    label: period.fullLabel,
                    home: "\(gameState.goalCount(for: .home, period: period))",
                    away: "\(gameState.goalCount(for: .away, period: period))"
                )
            }
            statRow(
                label: "Total Goals",
                home: "\(gameState.goalCount(for: .home))",
                away: "\(gameState.goalCount(for: .away))",
                emphasized: true
            )

            gridSectionTitle("Goals by Strength")
            statRow(
                label: "Even Strength",
                home: "\(gameState.goals(for: .home, strength: .evenStrength))",
                away: "\(gameState.goals(for: .away, strength: .evenStrength))"
            )
            statRow(
                label: "Power Play",
                home: "\(gameState.goals(for: .home, strength: .powerPlay))",
                away: "\(gameState.goals(for: .away, strength: .powerPlay))"
            )
            statRow(
                label: "Short Handed",
                home: "\(gameState.goals(for: .home, strength: .shortHanded))",
                away: "\(gameState.goals(for: .away, strength: .shortHanded))"
            )
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func gridSectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private func statRow(label: String, home: String, away: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasized ? .subheadline.bold() : .subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(home)
                .font(emphasized ? .subheadline.bold() : .subheadline.monospacedDigit())
                .foregroundStyle(.blue)
                .frame(width: 80)
            Text(away)
                .font(emphasized ? .subheadline.bold() : .subheadline.monospacedDigit())
                .foregroundStyle(.orange)
                .frame(width: 80)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(emphasized ? Color.primary.opacity(0.05) : Color.clear)
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
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(goals) { goal in
                        Text("⭐️ #\(goal.playerNumber) — \(goal.time.displayString) — \(gameState.strength(for: goal).abbreviation)")
                            .font(.caption)
                    }
                    ForEach(pens) { pen in
                        Text("⚠️ #\(pen.playerNumber) — \(pen.infraction) (\(pen.type.shortLabel)) — \(pen.time.displayString)")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
