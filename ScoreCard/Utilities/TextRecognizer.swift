import UIKit
import Vision
import PencilKit

enum TextRecognizer {
    /// Renders a PKDrawing to an image and runs Vision text recognition on it.
    static func recognizeText(from drawing: PKDrawing) async -> String {
        let bounds = drawing.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 1, height: 1)
            : drawing.bounds.insetBy(dx: -20, dy: -20)
        let image = drawing.image(from: bounds, scale: 3.0)

        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    /// Best-effort extraction of a jersey/player number from recognized text.
    static func extractPlayerNumber(from text: String) -> String? {
        let pattern = "#\\s?(\\d{1,3})"
        if let range = text.range(of: pattern, options: .regularExpression) {
            let match = String(text[range])
            return match.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        }
        return nil
    }

    /// Best-effort extraction of a clock time like "14:32" from recognized text.
    static func extractTime(from text: String) -> String? {
        let pattern = "\\b([0-2]?\\d):([0-5]\\d)\\b"
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
}
