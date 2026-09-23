import SwiftUI

struct NotesView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        HStack(spacing: 12) {
            notepad(for: .home)
            notepad(for: .away)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func notepad(for side: TeamSide) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    gameState.setDraftNoteText(gameState.draftNoteText(for: side) + "\n", for: side)
                } label: {
                    Image(systemName: "return")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .systemGray5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Spacer()
            }

            TextEditor(text: notepadBinding(for: side))
                .padding(6)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(gameState.accentColor(for: side).opacity(0.4), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func notepadBinding(for side: TeamSide) -> Binding<String> {
        Binding(
            get: { gameState.draftNoteText(for: side) },
            set: { gameState.setDraftNoteText($0, for: side) }
        )
    }
}
