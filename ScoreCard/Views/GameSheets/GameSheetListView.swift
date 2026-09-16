import SwiftUI

/// Presented from the hamburger menu: lets the user start a new gamesheet
/// or load/delete one that was saved earlier.
struct GameSheetListView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var gameSheetStore: GameSheetStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    gameState.reset()
                    dismiss()
                } label: {
                    Label("New Gamesheet", systemImage: "plus.circle.fill")
                }

                if !gameSheetStore.sheets.isEmpty {
                    Section("Saved Gamesheets") {
                        ForEach(gameSheetStore.sheets) { sheet in
                            Button {
                                gameState.loadGameSheet(sheet)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sheet.name)
                                        .font(.body.bold())
                                        .foregroundStyle(.primary)
                                    Text(sheet.savedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                gameSheetStore.delete(gameSheetStore.sheets[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gamesheets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
