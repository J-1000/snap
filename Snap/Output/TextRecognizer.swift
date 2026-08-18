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
            finish(preferredText(from: lines))
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

    static func preferredText(from lines: [String]) -> String? {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? nil : cleaned.joined(separator: "\n")
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
