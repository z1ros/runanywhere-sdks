import Foundation
import RunAnywhere
import AVFoundation
import os

#if canImport(CRunAnywhereONNX)
import CRunAnywhereONNX
#endif

/// TTS Service implementation using Sherpa-ONNX with VITS/Piper models
/// This allows users to bring any compatible Piper/VITS TTS model
public final class PiperTTSService: NSObject, TTSService, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.runanywhere.onnx", category: "PiperTTS")

    private var ttsHandle: ra_sherpa_tts_handle?
    private var modelPath: String?
    private var _isSynthesizing = false
    private var modelSampleRate: Int32 = 22050
    private var modelNumSpeakers: Int32 = 1

    private let synthesisQueue = DispatchQueue(label: "com.runanywhere.piper.synthesis")

    public override init() {
        super.init()
    }

    /// Initialize with a specific model directory path
    public init(modelPath: String) {
        self.modelPath = modelPath
        super.init()
    }

    // MARK: - TTSService Protocol

    public func initialize() async throws {
        guard let modelPath = modelPath else {
            logger.error("No model path provided for Piper TTS")
            throw SDKError.modelNotFound("No model path provided for Piper TTS")
        }

        logger.info("Initializing Piper TTS with model at: \(modelPath)")

        // Create the TTS engine using sherpa-onnx
        let handle = ra_sherpa_tts_create(modelPath, nil)

        guard handle != nil else {
            logger.error("Failed to create Piper TTS engine. Check model files in: \(modelPath)")
            throw SDKError.loadingFailed("Failed to create Piper TTS engine. Ensure the model directory contains model.onnx and tokens.txt")
        }

        self.ttsHandle = handle

        // Get model properties
        self.modelSampleRate = Int32(ra_sherpa_tts_sample_rate(handle))
        self.modelNumSpeakers = Int32(ra_sherpa_tts_num_speakers(handle))

        logger.info("Piper TTS initialized successfully")
        logger.info("  Sample rate: \(self.modelSampleRate) Hz")
        logger.info("  Num speakers: \(self.modelNumSpeakers)")
    }

    public func synthesize(text: String, options: TTSOptions) async throws -> Data {
        guard let handle = ttsHandle else {
            throw SDKError.componentNotInitialized("Piper TTS not initialized")
        }

        _isSynthesizing = true
        defer { _isSynthesizing = false }

        logger.info("Synthesizing: \"\(text.prefix(50))...\"")

        // Prepare output variables
        var samples: UnsafeMutablePointer<Float>?
        var numSamples: Int32 = 0
        var sampleRate: Int32 = 0

        // Parse speaker ID from voice option (default to 0)
        let speakerId: Int32 = Int32(options.voice.flatMap { Int($0) } ?? 0)

        // Speed: options.rate where 1.0 = normal
        let speed = options.rate

        // Generate speech
        let result = ra_sherpa_tts_generate(
            handle,
            text,
            speakerId,
            speed,
            &samples,
            &numSamples,
            &sampleRate
        )

        guard result == 0, let samples = samples, numSamples > 0 else {
            logger.error("Failed to generate speech. Error code: \(result)")
            throw SDKError.generationFailed("Failed to generate speech from Piper TTS")
        }

        defer {
            ra_sherpa_tts_free_samples(samples)
        }

        logger.info("Generated \(numSamples) samples at \(sampleRate) Hz")

        // Convert float samples to audio data
        // The samples are normalized to [-1, 1], convert to 16-bit PCM
        let audioData = convertToPCMData(samples: samples, count: Int(numSamples), sampleRate: Int(sampleRate))

        logger.info("Audio data size: \(audioData.count) bytes")

        return audioData
    }

    public func synthesizeStream(
        text: String,
        options: TTSOptions,
        onChunk: @escaping (Data) -> Void
    ) async throws {
        // Piper/VITS doesn't natively support streaming, so we synthesize the whole thing
        // and return it as a single chunk
        let audioData = try await synthesize(text: text, options: options)
        onChunk(audioData)
    }

    public func stop() {
        _isSynthesizing = false
        // Note: Sherpa-ONNX TTS doesn't have a cancel mechanism for synthesis
        // The synthesis is blocking, so we just mark as not synthesizing
    }

    public var isSynthesizing: Bool {
        _isSynthesizing
    }

    public var availableVoices: [String] {
        // Return speaker IDs as "voices" for multi-speaker models
        guard ttsHandle != nil else { return [] }
        return (0..<modelNumSpeakers).map { String($0) }
    }

    public func cleanup() async {
        logger.info("Cleaning up Piper TTS")
        if let handle = ttsHandle {
            ra_sherpa_tts_destroy(handle)
            ttsHandle = nil
        }
    }

    // MARK: - Private Helpers

    /// Convert float samples [-1, 1] to 16-bit PCM WAV data
    private func convertToPCMData(samples: UnsafePointer<Float>, count: Int, sampleRate: Int) -> Data {
        // Create WAV header + PCM data
        let bytesPerSample = 2  // 16-bit
        let numChannels = 1
        let dataSize = count * bytesPerSample
        let fileSize = 44 + dataSize  // WAV header is 44 bytes

        var data = Data(capacity: fileSize)

        // WAV Header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize - 8).littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // Format chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // Chunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // Audio format (PCM)
        data.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Array($0) })  // Channels
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })  // Sample rate
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * numChannels * bytesPerSample).littleEndian) { Array($0) })  // Byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels * bytesPerSample).littleEndian) { Array($0) })  // Block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(bytesPerSample * 8).littleEndian) { Array($0) })  // Bits per sample

        // Data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Convert float samples to 16-bit PCM
        for i in 0..<count {
            let sample = samples[i]
            // Clamp to [-1, 1] and convert to Int16
            let clampedSample = max(-1.0, min(1.0, sample))
            let int16Sample = Int16(clampedSample * Float(Int16.max))
            data.append(contentsOf: withUnsafeBytes(of: int16Sample.littleEndian) { Array($0) })
        }

        return data
    }
}

// MARK: - Piper TTS Service Provider

/// Service provider for Piper TTS models
public struct PiperTTSServiceProvider: TTSServiceProvider {
    private static let logger = Logger(subsystem: "com.runanywhere.onnx", category: "PiperTTSProvider")

    public let name: String = "Piper TTS"
    public let version: String = "1.0.0"

    public init() {}

    public func createTTSService(configuration: TTSConfiguration) async throws -> TTSService {
        Self.logger.info("Creating Piper TTS service for voice: \(configuration.voice)")

        // The voice field contains the model ID for Piper models
        let modelId = configuration.voice

        // Get the actual model file path from the model registry
        var modelPath: String? = nil

        // Query all available models and find the one we need
        let allModels = try await RunAnywhere.availableModels()
        let modelInfo = allModels.first { $0.id == modelId }

        // Check if model is downloaded and has a local path
        if let localPath = modelInfo?.localPath {
            modelPath = localPath.path
            Self.logger.info("Found local model path: \(modelPath ?? "nil")")
        } else {
            // Model not downloaded yet
            Self.logger.error("Model '\(modelId)' is not downloaded. Please download the model first.")
            throw SDKError.modelNotFound("TTS Model '\(modelId)' is not downloaded. Please download the model before using it.")
        }

        guard let path = modelPath else {
            throw SDKError.modelNotFound("Could not find model path for: \(modelId)")
        }

        let service = PiperTTSService(modelPath: path)
        try await service.initialize()
        return service
    }

    public func canHandle(modelId: String?) -> Bool {
        guard let modelId = modelId else { return false }

        let lowercased = modelId.lowercased()

        Self.logger.debug("Checking if can handle TTS model: \(modelId)")

        // Handle Piper TTS models
        if lowercased.contains("piper") {
            Self.logger.debug("Model \(modelId) matches Piper TTS pattern")
            return true
        }

        // Handle VITS models
        if lowercased.contains("vits") {
            Self.logger.debug("Model \(modelId) matches VITS pattern")
            return true
        }

        // Handle generic ONNX TTS models
        if lowercased.contains("tts") && lowercased.contains("onnx") {
            Self.logger.debug("Model \(modelId) matches ONNX TTS pattern")
            return true
        }

        Self.logger.debug("Model \(modelId) does not match any Piper TTS patterns")
        return false
    }

    /// Register this provider with the ModuleRegistry
    @MainActor
    public static func register(priority: Int = 100) async {
        logger.info("Registering Piper TTS provider with priority \(priority)")
        let provider = PiperTTSServiceProvider()
        ModuleRegistry.shared.registerTTS(provider, priority: priority)
        logger.info("Piper TTS provider registered")
    }
}

// Note: TTSServiceProvider protocol is defined in ModuleRegistry.swift
