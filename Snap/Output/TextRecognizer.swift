import AppKit
@preconcurrency import Vision

/// On-device text recognition (Vision). Fully local — no network, no telemetry.
enum TextRecognizer {
    static func recognize(
        in image: CGImage,
        completion: @escaping @MainActor @Sendable (String?) -> Void
    ) {
        let finish: @Sendable (String?) -> Void = { result in
            Task { @MainActor in
                completion(result)
            }
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
