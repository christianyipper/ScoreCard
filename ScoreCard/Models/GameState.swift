import Foundation
import Combine

@MainActor
final class GameState: ObservableObject {
    @Published var teamNames: [TeamSide: String] = [.home: "Home", .away: "Away"]
    @Published var currentPeriod: GamePeriod = .first

    @Published var shots: [TeamSide: [GamePeriod: Int]] = [
        .home: [:],
        .away: [:]
    ]

    @Published var goals: [GoalEntry] = []
    @Published var penalties: [PenaltyEntry] = []
    @Published var generalNotes: [GeneralNote] = []

    // MARK: - Shots

    func shotCount(for team: TeamSide, period: GamePeriod) -> Int {
        shots[team]?[period] ?? 0
    }

    func shotTotal(for team: TeamSide) -> Int {
        GamePeriod.allCases.reduce(0) { $0 + shotCount(for: team, period: $1) }
    }

    func addShot(for team: TeamSide, delta: Int = 1) {
        let current = shots[team]?[currentPeriod] ?? 0
        let updated = max(0, current + delta)
        shots[team, default: [:]][currentPeriod] = updated
    }

    // MARK: - Goals & Penalties

    func addGoal(_ goal: GoalEntry) {
        goals.append(goal)
        goals.sort { ($0.period, $0.time.elapsedSeconds) < ($1.period, $1.time.elapsedSeconds) }
    }

    func addPenalty(_ penalty: PenaltyEntry) {
        penalties.append(penalty)
        penalties.sort { ($0.period, $0.time.elapsedSeconds) < ($1.period, $1.time.elapsedSeconds) }
    }

    func addGeneralNote(_ note: GeneralNote) {
        generalNotes.append(note)
    }

    func deleteGoal(_ goal: GoalEntry) {
        goals.removeAll { $0.id == goal.id }
    }

    func deletePenalty(_ penalty: PenaltyEntry) {
        penalties.removeAll { $0.id == penalty.id }
    }

    func goalCount(for team: TeamSide, period: GamePeriod? = nil) -> Int {
        goals.filter { $0.team == team && (period == nil || $0.period == period) }.count
    }

    func penaltyCount(for team: TeamSide, period: GamePeriod? = nil) -> Int {
        penalties.filter { $0.team == team && (period == nil || $0.period == period) }.count
    }

    // MARK: - Strength calculation

    /// Skaters on the ice for a team at a given moment, floored at 3.
    private func skaterCount(for team: TeamSide, period: GamePeriod, elapsedSeconds: Int) -> Int {
        let active = penalties.filter {
            $0.team == team && $0.period == period && $0.isActive(at: elapsedSeconds)
        }.count
        return max(3, 5 - active)
    }

    func strength(for goal: GoalEntry) -> GoalStrength {
        let opponent: TeamSide = goal.team == .home ? .away : .home
        let scoringSkaters = skaterCount(for: goal.team, period: goal.period, elapsedSeconds: goal.time.elapsedSeconds)
        let opponentSkaters = skaterCount(for: opponent, period: goal.period, elapsedSeconds: goal.time.elapsedSeconds)
        if scoringSkaters > opponentSkaters {
            return .powerPlay
        } else if scoringSkaters < opponentSkaters {
            return .shortHanded
        } else {
            return .evenStrength
        }
    }

    func goals(for team: TeamSide, period: GamePeriod, strength: GoalStrength) -> Int {
        goals.filter { $0.team == team && $0.period == period && self.strength(for: $0) == strength }.count
    }

    func goals(for team: TeamSide, strength: GoalStrength) -> Int {
        goals.filter { $0.team == team && self.strength(for: $0) == strength }.count
    }

    // MARK: - Export

    /// A plain-text log of every submitted note, formatted for pasting into
    /// another app (e.g. a stats sheet or league messaging app).
    var fullNotesText: String {
        var lines: [String] = []
        lines.append("\(teamNames[.home] ?? "Home") vs \(teamNames[.away] ?? "Away")")
        lines.append("")

        for period in GamePeriod.allCases {
            let periodGoals = goals.filter { $0.period == period }
            let periodPenalties = penalties.filter { $0.period == period }
            let periodGeneral = generalNotes.filter { $0.period == period }
            guard !(periodGoals.isEmpty && periodPenalties.isEmpty && periodGeneral.isEmpty) else { continue }

            lines.append("== \(period.fullLabel) ==")
            for goal in periodGoals.sorted(by: { $0.time.elapsedSeconds < $1.time.elapsedSeconds }) {
                let team = teamNames[goal.team] ?? goal.team.defaultName
                var line = "GOAL (\(strength(for: goal).abbreviation)) - \(team) - #\(goal.playerNumber) - \(goal.time.displayString)"
                if !goal.assist.isEmpty {
                    line += " - Assist: \(goal.assist)"
                }
                lines.append(line)
            }
            for penalty in periodPenalties.sorted(by: { $0.time.elapsedSeconds < $1.time.elapsedSeconds }) {
                let team = teamNames[penalty.team] ?? penalty.team.defaultName
                lines.append("PENALTY - \(team) - #\(penalty.playerNumber) - \(penalty.infraction) (\(penalty.type.shortLabel)) - \(penalty.time.displayString)")
            }
            for note in periodGeneral.sorted(by: { $0.createdAt < $1.createdAt }) {
                lines.append("NOTE - \(note.text)")
            }
            lines.append("")
        }

        lines.append("Final Shots: \(teamNames[.home] ?? "Home") \(shotTotal(for: .home)) - \(teamNames[.away] ?? "Away") \(shotTotal(for: .away))")
        lines.append("Final Score: \(teamNames[.home] ?? "Home") \(goalCount(for: .home)) - \(teamNames[.away] ?? "Away") \(goalCount(for: .away))")

        return lines.joined(separator: "\n")
    }
}
