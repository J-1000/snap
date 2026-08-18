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

/// On-device QR recognition. Payloads never leave the Mac; callers decide
/// whether to copy or open the resulting text.
enum QRCodeRecognizer {
    static func recognize(
        in image: CGImage,
        completion: @escaping @MainActor @Sendable (String?) -> Void
    ) {
        let finish: @Sendable (String?) -> Void = { result in
            Task { @MainActor in completion(result) }
        }

        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNBarcodeObservation] else {
                finish(nil)
                return
            }
            finish(preferredPayload(from: observations.compactMap(\.payloadStringValue)))
        }
        request.symbologies = [.qr]

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                finish(nil)
            }
        }
    }

    static func preferredPayload(from payloads: [String]) -> String? {
        payloads.lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
