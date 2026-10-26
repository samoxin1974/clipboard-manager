import Foundation
import Vision

final class OCRService {
    private let queue: OperationQueue
    private var generation = 0
    var isEnabled = true

    init() {
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        queue.name = "local.clipboardmanager.pro.ocr"
    }

    func recognize(imageData: Data, completion: @escaping (String?) -> Void) {
        guard isEnabled else { completion(nil); return }
        queue.addOperation { [weak self] in
            guard self != nil else { return }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(data: imageData, options: [:])
            do {
                try handler.perform([request])
                let observations = request.results ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    completion(text.isEmpty ? nil : text)
                }
            } catch {
                AppLog.write("ocr failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
