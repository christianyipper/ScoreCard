import SwiftUI

struct NotesView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        TabView(selection: $gameState.currentNotepadIndex) {
            ForEach(Array(gameState.draftNotepads.indices), id: \.self) { index in
                TextEditor(text: notepadBinding(for: index))
                    .padding(6)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.bottom, gameState.draftNotepads.count > 1 ? 16 : 0)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: gameState.draftNotepads.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func notepadBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { gameState.draftNotepads.indices.contains(index) ? gameState.draftNotepads[index] : "" },
            set: { gameState.setNotepadText($0, at: index) }
        )
    }
}
