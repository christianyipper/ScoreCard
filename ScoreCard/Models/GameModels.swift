import Foundation

enum TeamSide: String, CaseIterable, Identifiable, Codable {
    case home
    case away

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .home: return "Home"
        case .away: return "Away"
        }
    }

    var opposite: TeamSide {
        switch self {
        case .home: return .away
        case .away: return .home
        }
    }
}

enum GamePeriod: Int, CaseIterable, Identifiable, Codable, Comparable {
    case first = 1
    case second = 2
    case third = 3
    case overtime = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .first: return "1"
        case .second: return "2"
        case .third: return "3"
        case .overtime: return "4+"
        }
    }

    var fullLabel: String {
        switch self {
        case .first: return "Period 1"
        case .second: return "Period 2"
        case .third: return "Period 3"
        case .overtime: return "Period 4+"
        }
    }

    static func < (lhs: GamePeriod, rhs: GamePeriod) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The penalty types selectable from the Add Penalty dropdown, grouped into
/// two rows of three buttons.
enum PenaltyType: String, CaseIterable, Identifiable, Codable {
    case minor
    case doubleMinor
    case major
    case match
    case misc
    case gameMisconduct

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minor: return "Minor"
        case .doubleMinor: return "Double Minor"
        case .major: return "Major"
        case .match: return "Match"
        case .misc: return "Misc"
        case .gameMisconduct: return "GM"
        }
    }
}

/// The two rows the penalty-type dropdown groups its buttons into. Each row
/// is single-select on its own, but a selection from one row combines with a
/// selection from the other (e.g. Minor + GM).
enum PenaltyTypeRow: CaseIterable, Hashable {
    case severity
    case additional

    var types: [PenaltyType] {
        switch self {
        case .severity: return [.minor, .doubleMinor, .major]
        case .additional: return [.match, .misc, .gameMisconduct]
        }
    }
}

/// A penalty entry's display text is its selected penalty type(s) (e.g.
/// "Minor + GM") plus an optional free-form note.
struct PenaltyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var team: TeamSide
    var period: GamePeriod
    var types: [PenaltyType]
    var text: String

    init(id: UUID = UUID(), team: TeamSide, period: GamePeriod, types: [PenaltyType] = [], text: String = "") {
        self.id = id
        self.team = team
        self.period = period
        self.types = types
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case id, team, period, types, text
    }

    /// Custom decoding so gamesheets saved before `types` existed (which
    /// lack that key entirely) still decode instead of failing the whole
    /// saved-gamesheets array.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        team = try container.decode(TeamSide.self, forKey: .team)
        period = try container.decode(GamePeriod.self, forKey: .period)
        types = try container.decodeIfPresent([PenaltyType].self, forKey: .types) ?? []
        text = try container.decode(String.self, forKey: .text)
    }

    var displayText: String {
        [types.map(\.label).joined(separator: " + "), text]
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }
}

struct GoalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var team: TeamSide
    var period: GamePeriod
    var text: String

    init(id: UUID = UUID(), team: TeamSide, period: GamePeriod, text: String = "") {
        self.id = id
        self.team = team
        self.period = period
        self.text = text
    }
}

/// A free-form note submitted from the Quick Note field that isn't tied to
/// a specific goal or penalty (e.g. a general observation).
struct GeneralNote: Identifiable, Codable, Equatable {
    let id: UUID
    var period: GamePeriod
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), period: GamePeriod, text: String, createdAt: Date = Date()) {
        self.id = id
        self.period = period
        self.text = text
        self.createdAt = createdAt
    }
}

/// A saved snapshot of a `GameState`, persisted so a game can be closed and
/// reopened later from the hamburger menu's gamesheet list.
struct GameSheet: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var savedAt: Date
    var teamNames: [TeamSide: String]
    var shots: [TeamSide: [GamePeriod: Int]]
    var goals: [GoalEntry]
    var penalties: [PenaltyEntry]
    var generalNotes: [GeneralNote]
    var currentPeriod: GamePeriod
    var goaltenderNotes: [TeamSide: String]

    init(
        id: UUID,
        name: String,
        savedAt: Date,
        teamNames: [TeamSide: String],
        shots: [TeamSide: [GamePeriod: Int]],
        goals: [GoalEntry],
        penalties: [PenaltyEntry],
        generalNotes: [GeneralNote],
        currentPeriod: GamePeriod,
        goaltenderNotes: [TeamSide: String]
    ) {
        self.id = id
        self.name = name
        self.savedAt = savedAt
        self.teamNames = teamNames
        self.shots = shots
        self.goals = goals
        self.penalties = penalties
        self.generalNotes = generalNotes
        self.currentPeriod = currentPeriod
        self.goaltenderNotes = goaltenderNotes
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, savedAt, teamNames, shots, goals, penalties, generalNotes, currentPeriod, goaltenderNotes
    }

    /// Custom decoding so gamesheets saved before `goaltenderNotes` existed
    /// (which lack that key entirely) still decode instead of failing the
    /// whole saved-gamesheets array.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        teamNames = try container.decode([TeamSide: String].self, forKey: .teamNames)
        shots = try container.decode([TeamSide: [GamePeriod: Int]].self, forKey: .shots)
        goals = try container.decode([GoalEntry].self, forKey: .goals)
        penalties = try container.decode([PenaltyEntry].self, forKey: .penalties)
        generalNotes = try container.decode([GeneralNote].self, forKey: .generalNotes)
        currentPeriod = try container.decode(GamePeriod.self, forKey: .currentPeriod)
        goaltenderNotes = try container.decodeIfPresent([TeamSide: String].self, forKey: .goaltenderNotes) ?? [.home: "", .away: ""]
    }
}
