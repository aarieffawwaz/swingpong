import CoreML
import Foundation

struct MotionPrediction: Equatable, Sendable {
    let label: String
    let confidence: Double
}

protocol MotionClassifying {
    func classify(_ window: CapturedMotionWindow) throws -> MotionPrediction
}

enum MotionPreprocessor {
    // These train-only values come from preprocessing-report.json. Keep them in
    // the recorder feature order: user acceleration, rotation rate, gravity.
    static let means = [
        -0.03099741742857143, 0.1594862457142857, 0.075192646,
        0.06505136219047619, -0.05089939761904762, -0.07379777857142857,
        -0.004878928476190475, -0.019157250095238096, -0.8040747327619048
    ]
    static let standardDeviations = [
        0.2550514330216405, 0.2985413281067149, 0.6881272003571862,
        2.683847157814246, 1.6689668186538462, 1.4807010992516922,
        0.37045470176442424, 0.3688809319268798, 0.2815159780958166
    ]

    static func normalizedFeatures(for window: CapturedMotionWindow) -> [[Double]] {
        precondition(window.frames.count == MotionWindowCollector.frameCount)
        return window.frames.indices.map { frameIndex in
            let previous = window.frames[max(frameIndex - 1, 0)].features
            let current = window.frames[frameIndex].features
            let next = window.frames[min(frameIndex + 1, window.frames.count - 1)].features
            return current.indices.map { featureIndex in
                let smoothed = previous[featureIndex] * 0.25
                    + current[featureIndex] * 0.50
                    + next[featureIndex] * 0.25
                return (smoothed - means[featureIndex]) / standardDeviations[featureIndex]
            }
        }
    }
}

final class CoreMLMotionClassifier: MotionClassifying {
    private let model: MLModel

    init(bundle: Bundle = .main) throws {
        guard let modelURL = bundle.url(forResource: "SwingPongMotionClassifier", withExtension: "mlmodelc") else {
            throw ClassifierError.modelMissing
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        model = try MLModel(contentsOf: modelURL, configuration: configuration)
    }

    func classify(_ window: CapturedMotionWindow) throws -> MotionPrediction {
        let rows = MotionPreprocessor.normalizedFeatures(for: window)
        let channelNames = ["ua_x", "ua_y", "ua_z", "rr_x", "rr_y", "rr_z", "g_x", "g_y", "g_z"]
        var input: [String: Any] = [:]

        for (featureIndex, name) in channelNames.enumerated() {
            let array = try MLMultiArray(shape: [NSNumber(value: MotionWindowCollector.frameCount)], dataType: .double)
            for frameIndex in rows.indices {
                array[frameIndex] = NSNumber(value: rows[frameIndex][featureIndex])
            }
            input[name] = array
        }

        let state = try MLMultiArray(shape: [400], dataType: .double)
        for index in 0..<state.count { state[index] = 0 }
        input["stateIn"] = state
        let provider = try MLDictionaryFeatureProvider(dictionary: input)
        let output = try model.prediction(from: provider)
        guard let label = output.featureValue(for: "label")?.stringValue else {
            throw ClassifierError.outputMissing
        }
        let probabilities = output.featureValue(for: "labelProbability")?.dictionaryValue
        let confidence = (probabilities?[label] as? NSNumber)?.doubleValue ?? 0
        return MotionPrediction(label: label, confidence: confidence)
    }

    enum ClassifierError: LocalizedError {
        case modelMissing
        case outputMissing

        var errorDescription: String? {
            switch self {
            case .modelMissing: "The trained model is missing from this app build."
            case .outputMissing: "The trained model returned an unreadable result."
            }
        }
    }
}
