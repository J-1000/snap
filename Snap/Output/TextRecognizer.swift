import AppKit
import Vision

/// On-device text recognition (Vision). Fully local — no network, no telemetry.
enum TextRecognizer {
    static func recognize(in image: CGImage, completion: @escaping (String?) -> Void) {
        func finish(_ result: String?) {
            DispatchQueue.main.async { completion(result) }
        }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                finish(nil)
                return
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            finish(lines.isEmpty ? nil : lines.joined(separator: "\n"))
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                finish(nil)
            }
        }
    }
}
