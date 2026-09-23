import SwiftUI

enum MainViewMode: String, CaseIterable, Identifiable {
    case penalties = "Penalties"
    case report = "Report"

    var id: String { rawValue }
}

struct NavSectionView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var gameSheetStore: GameSheetStore
    @Binding var viewMode: MainViewMode

    @State private var isResetConfirmationPresented = false

    /// The free-text notepad has been replaced by the penalty-entry screen;
    /// flip this back on to restore its Clear/Undo/Back controls.
    private let notepadEnabled = false

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                if notepadEnabled {
                    Button(role: .destructive) {
                        gameState.clearDraftNoteText()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .disabled(gameState.isDraftNoteTextEmpty)

                    Button {
                        gameState.undoDraftNoteTextClear()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!gameState.canUndoDraftNoteText)

                    Button {
                        gameState.backspaceDraftNoteText()
                    } label: {
                        Label("Back", systemImage: "delete.left")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!gameState.canBackspaceDraftNoteText)
                } else {
                    Button {
                        gameState.flipSides()
                    } label: {
                        Label("Flip", systemImage: "arrow.left.arrow.right")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        gameSheetStore.save(gameState)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        isResetConfirmationPresented = true
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.small)
            .frame(width: 320, alignment: .leading)

            Spacer()

            Picker("View", selection: $viewMode) {
                ForEach(MainViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .center) {
            PeriodPickerView()
        }
        .confirmationDialog(
            "Reset this gamesheet?",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                gameState.reset()
            }
        } message: {
            Text("This clears all shots, goals, and penalties. This can't be undone.")
        }
    }
}

struct PeriodPickerView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GamePeriod.allCases) { period in
                let isSelected = gameState.currentPeriod == period
                Button {
                    gameState.currentPeriod = period
                } label: {
                    Text(period.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.squish)
            }
        }
        .padding(2)
        .background(Color(uiColor: .systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(width: 240)
    }
}
