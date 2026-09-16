import SwiftUI
import PencilKit

struct NotesView: View {
    @EnvironmentObject var gameState: GameState
    @Binding var context: NoteContext

    @State private var drawing = PKDrawing()
    @State private var recognizedText: String = ""
    @State private var isRecognizing = false

    @State private var playerNumber: String = ""
    @State private var secondaryField: String = "" // assist (goal) or infraction (penalty)
    @State private var timeText: String = ""
    @State private var penaltyType: PenaltyType = .minor

    @State private var showCopiedConfirmation = false
    @State private var showSubmittedConfirmation = false

    private var team: TeamSide? { context.team }

    private var contextTitle: String {
        switch context {
        case .goal(let team):
            return "New Goal — \(gameState.teamNames[team] ?? team.defaultName)"
        case .penalty(let team):
            return "New Penalty — \(gameState.teamNames[team] ?? team.defaultName)"
        case .general:
            return "General Note"
        }
    }

    private var accentColor: Color {
        switch context {
        case .goal: return .green
        case .penalty: return .red
        case .general: return .blue
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            HStack(alignment: .top, spacing: 16) {
                canvasArea
                    .frame(maxWidth: .infinity)

                detailsPanel
                    .frame(width: 320)
            }
        }
        .padding()
        .onChange(of: context) { _, _ in
            resetDraft()
        }
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(accentColor)
                .frame(width: 10, height: 10)
            Text(contextTitle)
                .font(.title3.bold())

            Spacer()

            if context != .general {
                Button {
                    context = .general
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }

            Button {
                UIPasteboard.general.string = gameState.fullNotesText
                showCopiedConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    showCopiedConfirmation = false
                }
            } label: {
                Label(showCopiedConfirmation ? "Copied!" : "Copy All Notes", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var canvasArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Write here")
                .font(.caption)
                .foregroundStyle(.secondary)

            CanvasRepresentable(drawing: $drawing)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 280)

            HStack {
                Button(role: .destructive) {
                    drawing = PKDrawing()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Button {
                    convertDrawingToText()
                } label: {
                    if isRecognizing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Convert to Text", systemImage: "text.viewfinder")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(drawing.strokes.isEmpty || isRecognizing)

                Spacer()
            }

            Text("Recognized Text")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $recognizedText)
                .frame(height: 90)
                .padding(6)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch context {
            case .goal:
                Text("Goal Details").font(.headline)
                labeledField("Player #", text: $playerNumber, keyboard: .numberPad)
                labeledField("Assist (optional)", text: $secondaryField, keyboard: .numbersAndPunctuation)
                labeledField("Time (MM:SS)", text: $timeText, keyboard: .numbersAndPunctuation)

            case .penalty:
                Text("Penalty Details").font(.headline)
                labeledField("Player #", text: $playerNumber, keyboard: .numberPad)
                labeledField("Infraction", text: $secondaryField, keyboard: .default)
                Picker("Type", selection: $penaltyType) {
                    ForEach(PenaltyType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.menu)
                labeledField("Time (MM:SS)", text: $timeText, keyboard: .numbersAndPunctuation)

            case .general:
                Text("Quick Note").font(.headline)
                Text("Jot anything down and submit it to the game log. Use the Add Goal / Add Penalty buttons above to log structured events instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                submit()
            } label: {
                Label("Submit to Log", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .disabled(!canSubmit)

            if showSubmittedConfirmation {
                Text("Added to log")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var canSubmit: Bool {
        switch context {
        case .goal, .penalty:
            return !playerNumber.isEmpty && PeriodTime.parse(timeText) != nil
        case .general:
            return !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func convertDrawingToText() {
        isRecognizing = true
        Task {
            let text = await TextRecognizer.recognizeText(from: drawing)
            recognizedText = text
            if playerNumber.isEmpty, let number = TextRecognizer.extractPlayerNumber(from: text) {
                playerNumber = number
            }
            if timeText.isEmpty, let time = TextRecognizer.extractTime(from: text) {
                timeText = time
            }
            isRecognizing = false
        }
    }

    private func submit() {
        let time = PeriodTime.parse(timeText) ?? PeriodTime(elapsedSeconds: 0)

        switch context {
        case .goal(let team):
            let goal = GoalEntry(
                team: team,
                period: gameState.currentPeriod,
                playerNumber: playerNumber,
                assist: secondaryField,
                time: time,
                rawNoteText: recognizedText
            )
            gameState.addGoal(goal)

        case .penalty(let team):
            let penalty = PenaltyEntry(
                team: team,
                period: gameState.currentPeriod,
                playerNumber: playerNumber,
                infraction: secondaryField.isEmpty ? "Penalty" : secondaryField,
                type: penaltyType,
                time: time,
                rawNoteText: recognizedText
            )
            gameState.addPenalty(penalty)

        case .general:
            let note = GeneralNote(period: gameState.currentPeriod, text: recognizedText)
            gameState.addGeneralNote(note)
        }

        showSubmittedConfirmation = true
        resetDraft()
        context = .general
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            showSubmittedConfirmation = false
        }
    }

    private func resetDraft() {
        drawing = PKDrawing()
        recognizedText = ""
        playerNumber = ""
        secondaryField = ""
        timeText = ""
        penaltyType = .minor
    }
}
