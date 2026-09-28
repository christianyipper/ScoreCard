import SwiftUI

/// The team name field lives outside `TeamPanelView` so the header row (which
/// also holds the score box between the two teams) can be laid out
/// separately from the shots/goal columns below — otherwise the
/// score box's width pushes those columns apart.
struct TeamNameField: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var rosterStore: RosterStore
    let team: TeamSide

    @State private var isCustomNamePresented = false
    @State private var customName = ""

    private var teamName: String { gameState.teamNames[team] ?? team.defaultName }

    /// The team name is itself the menu for picking this side's league team
    /// (Division → Team), which fills in the name and turns on player
    /// lookups for typed jersey numbers. A custom name can still be typed.
    var body: some View {
        let selectedID = gameState.teamRosters[team]?.id
        Menu {
            ForEach(rosterStore.league?.divisions ?? []) { division in
                Menu(division.name) {
                    ForEach(division.teams) { rosterTeam in
                        Button {
                            gameState.selectRosterTeam(rosterTeam, for: team)
                        } label: {
                            if rosterTeam.id == selectedID {
                                Label(rosterTeam.name, systemImage: "checkmark")
                            } else {
                                Text(rosterTeam.name)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    customName = teamName
                    isCustomNamePresented = true
                } label: {
                    Label("Custom Name…", systemImage: "pencil")
                }

                if selectedID != nil {
                    Button("No Roster", role: .destructive) {
                        gameState.selectRosterTeam(nil, for: team)
                    }
                }
            }

            Section(rosterStore.league.map { "Updated \($0.updatedAt.formatted(date: .abbreviated, time: .shortened))" } ?? "No rosters downloaded") {
                Button {
                    Task { await rosterStore.refresh() }
                } label: {
                    Label("Refresh Rosters", systemImage: "arrow.clockwise")
                }
                .disabled(rosterStore.isRefreshing)
            }
        } label: {
            HStack(spacing: 6) {
                Text(teamName)
                    .font(AppTypography.teamName)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(gameState.accentColor(for: team))
            }
            .frame(maxWidth: .infinity)
        }
        .alert("\(team.defaultName) Team Name", isPresented: $isCustomNamePresented) {
            TextField(team.defaultName, text: $customName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = customName.trimmingCharacters(in: .whitespaces)
                gameState.teamNames[team] = trimmed.isEmpty ? team.defaultName : trimmed
            }
        } message: {
            Text("Keeps the current roster, if one is picked.")
        }
    }
}

/// The small line under a typed jersey number: the player's name (plus
/// season goals where `showsGoals`), or a warning when the number isn't on
/// the side's roster. Empty when the side has no roster.
struct PlayerLookupCaption: View {
    let lookup: PlayerLookup
    var showsGoals = true
    var usesSurname = false

    var body: some View {
        switch lookup {
        case .noRoster:
            EmptyView()
        case .notOnRoster:
            Text("Not on roster")
                .font(.caption.bold())
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        case .player(let player, let seasonGoals):
            Text("\(usesSurname ? player.surname : player.name)\(showsGoals ? " (\(seasonGoals))" : "")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// The middle column of the top section: a Home and an Away column, each
/// with individually selectable Starter, Backup and Time inputs. Both columns
/// use the same row heights so each input lines up across them. Filled from
/// the numpad on the Penalties tab.
struct GoaltenderPanelView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack(spacing: 10) {
            Text("Goaltenders")
                .font(AppTypography.body.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                column(for: .home)
                column(for: .away)
            }
        }
        .padding(AppLayout.sectionPadding)
        .frame(maxWidth: .infinity)
        .frame(height: AppLayout.teamPanelHeight)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func column(for side: TeamSide) -> some View {
        VStack(spacing: 8) {
            Text(gameState.teamNames[side] ?? side.defaultName)
                .font(AppTypography.caption.bold())
                .foregroundStyle(gameState.accentColor(for: side))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            ForEach(GoaltenderField.allCases, id: \.self) { field in
                fieldButton(side: side, field: field)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fieldButton(side: TeamSide, field: GoaltenderField) -> some View {
        let id = GoaltenderFieldID(side: side, field: field)
        let value = gameState.goaltenderDraft(for: side).display(field)
        let isActive = gameState.activeGoaltenderField == id
        return Button {
            gameState.selectGoaltenderField(id)
        } label: {
            Text(value.isEmpty ? field.placeholder : value)
                .font(AppTypography.body.weight(value.isEmpty ? .regular : .bold).monospacedDigit())
                .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(gameState.accentColor(for: side), lineWidth: isActive ? 3 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

struct TeamPanelView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var gameSheetStore: GameSheetStore
    @EnvironmentObject var rosterStore: RosterStore
    let team: TeamSide

    private var accent: Color { gameState.accentColor(for: team) }

    private var actionButtonHeight: CGFloat { AppLayout.actionButtonHeight }

    var body: some View {
        VStack(spacing: AppLayout.sectionSpacing) {
            container {
                shotsRow
            }

            container {
                HStack(spacing: 10) {
                    ForEach(GoalStrength.allCases, id: \.self) { strength in
                        goalStrengthButton(strength)
                    }
                }

                goalInputRow
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func container<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
        }
        .padding(AppLayout.sectionPadding)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var goalButtonCornerRadius: CGFloat { 8 }

    /// All the action buttons (Add Goal/shots/etc.) are drawn
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

    /// Outlined in green, filled green with white text while selected.
    /// Selecting one doesn't add a goal; the Submit button on the Penalties
    /// tab does.
    private func goalStrengthButton(_ strength: GoalStrength) -> some View {
        let isSelected = gameState.goalStrengths[team] == strength
        return actionButton(fill: isSelected ? .green : nil, borderColor: .green) {
            gameState.selectGoalStrength(strength, for: team)
        } label: {
            Text(strength.label)
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .white : .green)
        }
    }

    /// One tappable field holding the scorer and both assists, sized like
    /// the buttons in the sections above it and outlined in the team's color while active,
    /// with the field currently being typed into tinted.
    private var goalInputRow: some View {
        let draft = gameState.goalDraft(for: team)
        let activeField = gameState.activeGoalField?.side == team ? gameState.activeGoalField?.field : nil
        return Button {
            gameState.selectGoalInput(for: team)
        } label: {
            HStack(spacing: 8) {
                ForEach(GoalField.allCases, id: \.self) { field in
                    let value = draft[field]
                    VStack(spacing: 0) {
                        Text(value.isEmpty ? field.placeholder : value)
                            .font(AppTypography.body.weight(value.isEmpty ? .regular : .bold))
                            .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
                            .lineLimit(value.isEmpty ? 2 : 1)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)

                        if !value.isEmpty {
                            PlayerLookupCaption(lookup: gameState.lookupPlayer(
                                number: value,
                                side: team,
                                league: rosterStore.league,
                                savedSheets: gameSheetStore
                            ))
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(activeField == field ? accent.opacity(0.2) : Color.clear)
                        )
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: actionButtonHeight)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: goalButtonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: goalButtonCornerRadius)
                    .stroke(accent, lineWidth: activeField != nil ? 3 : 0)
            )
        }
        .buttonStyle(.plain)
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
