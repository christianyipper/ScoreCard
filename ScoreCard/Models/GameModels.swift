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
        case .overtime: return "Period 4+ (OT)"
        }
    }

    /// Regulation period length in seconds, used to bound penalty windows.
    var lengthSeconds: Int {
        self == .overtime ? 300 : 1200
    }

    static func < (lhs: GamePeriod, rhs: GamePeriod) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum PenaltyType: String, CaseIterable, Identifiable, Codable {
    case minor
    case doubleMinor
    case major
    case misconduct

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minor: return "Minor (2 min)"
        case .doubleMinor: return "Double Minor (4 min)"
        case .major: return "Major (5 min)"
        case .misconduct: return "Misconduct (10 min)"
        }
    }

    var shortLabel: String {
        switch self {
        case .minor: return "2 min"
        case .doubleMinor: return "4 min"
        case .major: return "5 min"
        case .misconduct: return "10 min"
        }
    }

    var durationSeconds: Int {
        switch self {
        case .minor: return 120
        case .doubleMinor: return 240
        case .major: return 300
        case .misconduct: return 600
        }
    }

    /// Misconducts are served without reducing skaters on the ice.
    var affectsStrength: Bool {
        self != .misconduct
    }
}

enum GoalStrength: String, Codable {
    case evenStrength
    case powerPlay
    case shortHanded

    var abbreviation: String {
        switch self {
        case .evenStrength: return "EV"
        case .powerPlay: return "PP"
        case .shortHanded: return "SH"
        }
    }

    var label: String {
        switch self {
        case .evenStrength: return "Even Strength"
        case .powerPlay: return "Power Play"
        case .shortHanded: return "Short Handed"
        }
    }
}

/// A time within a period, stored as elapsed seconds since the period started.
struct PeriodTime: Codable, Equatable {
    var elapsedSeconds: Int

    var displayString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Best-effort parse of "MM:SS", "M:SS", or a bare number of minutes.
    static func parse(_ text: String) -> PeriodTime? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":")
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
            return PeriodTime(elapsedSeconds: m * 60 + s)
        }
        if parts.count == 1, let m = Int(parts[0]) {
            return PeriodTime(elapsedSeconds: m * 60)
        }
        return nil
    }
}

struct PenaltyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var team: TeamSide
    var period: GamePeriod
    var playerNumber: String
    var infraction: String
    var type: PenaltyType
    var time: PeriodTime
    var rawNoteText: String

    init(id: UUID = UUID(), team: TeamSide, period: GamePeriod, playerNumber: String, infraction: String, type: PenaltyType, time: PeriodTime, rawNoteText: String) {
        self.id = id
        self.team = team
        self.period = period
        self.playerNumber = playerNumber
        self.infraction = infraction
        self.type = type
        self.time = time
        self.rawNoteText = rawNoteText
    }

    var endElapsedSeconds: Int {
        min(time.elapsedSeconds + type.durationSeconds, period.lengthSeconds)
    }

    func isActive(at elapsedSeconds: Int) -> Bool {
        type.affectsStrength && elapsedSeconds >= time.elapsedSeconds && elapsedSeconds < endElapsedSeconds
    }
}

struct GoalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var team: TeamSide
    var period: GamePeriod
    var playerNumber: String
    var assist: String
    var time: PeriodTime
    var rawNoteText: String

    init(id: UUID = UUID(), team: TeamSide, period: GamePeriod, playerNumber: String, assist: String, time: PeriodTime, rawNoteText: String) {
        self.id = id
        self.team = team
        self.period = period
        self.playerNumber = playerNumber
        self.assist = assist
        self.time = time
        self.rawNoteText = rawNoteText
    }
}

/// A free-form note that was submitted from the drawing notepad but is not
/// tied to a specific goal or penalty (e.g. a general observation).
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
