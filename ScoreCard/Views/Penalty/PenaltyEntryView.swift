import SwiftUI

/// Three columns: Home penalty rows, the shared period/time/numpad column,
/// and Away penalty rows. Selecting a row on one side slides an infraction
/// overlay over the opposite side's column.
struct PenaltyEntryView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        HStack(spacing: 16) {
            penaltyColumn(for: .home)
            periodColumn
                .frame(width: AppLayout.centerColumnWidth)
            penaltyColumn(for: .away)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: gameState.activePenaltyRow?.side)
    }

    // MARK: - Home / Away columns

    private func penaltyColumn(for side: TeamSide) -> some View {
        VStack(spacing: 8) {
            Text(gameState.teamNames[side] ?? side.defaultName)
                .font(AppTypography.body.bold())
                .foregroundStyle(gameState.accentColor(for: side))

            ForEach(0..<PenaltyDraftRow.rowsPerSide, id: \.self) { index in
                penaltyRow(side: side, index: index)
            }

            submitButton(for: side)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if gameState.activePenaltyRow?.side == side.opposite {
                infractionOverlay(activeSide: side.opposite)
                    .transition(.move(edge: side == .home ? .leading : .trailing))
            }
        }
        .clipped()
    }

    private func penaltyRow(side: TeamSide, index: Int) -> some View {
        let id = PenaltyRowID(side: side, index: index)
        let row = gameState.draftRows(for: side)[index]
        let isActive = gameState.activePenaltyRow == id
        let accent = gameState.accentColor(for: side)

        return Button {
            gameState.selectPenaltyRow(id)
        } label: {
            HStack(spacing: 8) {
                rowField(row.infraction?.label, placeholder: "Infraction")
                rowField(row.types.isEmpty ? nil : row.types.ordered.map(\.label).joined(separator: " + "), placeholder: "Type")
                rowField(row.numberDisplay(showsSlash: gameState.isEditingServedBy(id)), placeholder: "#")
                    .frame(width: 72)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accent, lineWidth: isActive ? 3 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private func rowField(_ value: String?, placeholder: String) -> some View {
        Text(value ?? placeholder)
            .font(AppTypography.body.weight(value == nil ? .regular : .bold))
            .foregroundStyle(value == nil ? Color.secondary : Color.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }

    private func submitButton(for side: TeamSide) -> some View {
        let canSubmit = gameState.canSubmit(for: side)
        return Button {
            gameState.submit(for: side)
        } label: {
            Text("Submit")
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 8).fill(canSubmit ? Color.green : Color.gray))
        }
        .buttonStyle(.squish)
        .disabled(!canSubmit)
    }

    private func infractionOverlay(activeSide: TeamSide) -> some View {
        let selected = gameState.activePenaltyRow.map { gameState.draftRows(for: $0.side)[$0.index].infraction } ?? nil

        return VStack(spacing: 10) {
            Text("Infraction")
                .font(AppTypography.body.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(Infraction.allCases) { infraction in
                    Button {
                        gameState.setInfraction(infraction)
                    } label: {
                        Text(infraction.label)
                            .fontWeight(.bold)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selected == infraction ? gameState.accentColor(for: activeSide) : Color.gray)
                            )
                    }
                    .buttonStyle(.squish)
                }
            }

            Spacer(minLength: 0)

            Divider()
                .frame(height: 2)
                .overlay(Color.gray)

            penaltyTypePicker(activeSide: activeSide)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gameState.accentColor(for: activeSide).opacity(0.5), lineWidth: 2))
    }

    private func penaltyTypePicker(activeSide: TeamSide) -> some View {
        let selected = gameState.activeRowTypes(for: activeSide)
        return VStack(spacing: 8) {
            ForEach(PenaltyTypeRow.allCases, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row.types) { type in
                        Button {
                            gameState.togglePenaltyType(type)
                        } label: {
                            Text(type.label)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selected.contains(type) ? gameState.accentColor(for: activeSide) : Color.gray)
                                )
                        }
                        .buttonStyle(.squish)
                    }
                }
            }
        }
    }

    // MARK: - Period column

    private var periodColumn: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(gameState.currentPeriod.fullLabel)
                    .font(AppTypography.body.bold())
                    .foregroundStyle(.secondary)

                periodTimeButton
            }

            numpad
                .frame(maxHeight: .infinity)
        }
    }

    private var periodTimeButton: some View {
        Button {
            gameState.beginEditingPeriodTime()
        } label: {
            Text(gameState.periodTimeDisplay)
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(gameState.isEditingPeriodTime ? Color.blue : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: gameState.isEditingPeriodTime ? 3 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    private var numpad: some View {
        let rows: [[NumpadKey]] = [
            [.digit(1), .digit(2), .digit(3)],
            [.digit(4), .digit(5), .digit(6)],
            [.digit(7), .digit(8), .digit(9)],
            [.next, .digit(0), .backspace]
        ]
        return VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<rows[r].count, id: \.self) { c in
                        numpadButton(rows[r][c])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func numpadButton(_ key: NumpadKey) -> some View {
        switch key {
        case .next:
            numpadKeyLabel(enabled: gameState.canAdvanceNumpad) {
                gameState.advanceNumpad()
            } label: {
                Image(systemName: "return")
                    .font(.title2)
            }
        case .digit(let digit):
            numpadKeyLabel(enabled: gameState.isNumpadEnabled) {
                gameState.pressNumpadDigit(digit)
            } label: {
                Text("\(digit)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
        case .backspace:
            numpadKeyLabel(enabled: gameState.canBackspaceNumpad) {
                gameState.numpadBackspace()
            } label: {
                Image(systemName: "delete.left")
                    .font(.title2)
            }
        }
    }

    private func numpadKeyLabel<Label: View>(
        enabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.squish)
        .disabled(!enabled)
    }

    private enum NumpadKey {
        case digit(Int)
        case backspace
        case next
    }
}
