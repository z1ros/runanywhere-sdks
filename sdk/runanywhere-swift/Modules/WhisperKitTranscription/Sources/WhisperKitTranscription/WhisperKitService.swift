import Foundation
import RunAnywhere
import AVFoundation
import WhisperKit
import os

/// WhisperKit implementation of STTService
public class WhisperKitService: STTService {
    private let logger = Logger(subsystem: "com.runanywhere.whisperkit", category: "WhisperKitService")

    // MARK: - Properties

    private var currentModelPath: String?
    private var isInitialized: Bool = false
    private var whisperKit: WhisperKit?

    // Protocol requirements
    public var isReady: Bool { isInitialized && whisperKit != nil }
    public var currentModel: String? { currentModelPath }

    // Properties for streaming
    private var streamingTask: Task<Void, Error>?
    private var audioAccumulator = Data()
    private let minAudioLength = 8000  // 500ms at 16kHz
    private let contextOverlap = 1600   // 100ms overlap for context

    // MARK: - VoiceService Implementation

    public func initialize(modelPath: String?) async throws {
        logger.info("Starting initialization...")
        logger.debug("Model path requested: \(modelPath ?? "default", privacy: .public)")

        // Skip initialization if already initialized with the same model
        if isInitialized && whisperKit != nil && currentModelPath == (modelPath ?? "whisper-base") {
            logger.info("✅ WhisperKit already initialized with model: \(self.currentModelPath ?? "unknown", privacy: .public)")
            return
        }

        do {
            // Determine if modelPath is a full filesystem path or just a model ID
            let isFullPath = modelPath?.hasPrefix("/") ?? false ||
                           modelPath?.contains("/RunAnywhere/Models/WhisperKit/") ?? false

            let localModelPath: URL
            let whisperKitModelName: String

            if isFullPath, let pathString = modelPath {
                // modelPath is already a full path to downloaded model
                localModelPath = URL(fileURLWithPath: pathString)
                // Extract model name from path (e.g., "whisper-base" from "/path/to/whisper-base")
                whisperKitModelName = localModelPath.lastPathComponent
                logger.info("📍 Using provided full path: \(localModelPath.path)")
                logger.info("📝 Extracted model name: \(whisperKitModelName)")
            } else {
                // modelPath is a model ID - construct the path
                whisperKitModelName = mapModelIdToWhisperKitName(modelPath ?? "whisper-base")
                localModelPath = getLocalModelPath(for: whisperKitModelName)
                logger.info("📍 Constructed path from model ID: \(localModelPath.path)")
            }

            logger.info("Creating WhisperKit instance with model: \(whisperKitModelName)")
            logger.info("🔍 Checking for local model at: \(localModelPath.path)")

            // Check if all required model components exist (matching WhisperKit's loadModels() requirements)
            // WhisperKit requires: MelSpectrogram, AudioEncoder, and TextDecoder
            let melSpectrogramPath = localModelPath.appendingPathComponent("MelSpectrogram.mlmodelc")
            let audioEncoderPath = localModelPath.appendingPathComponent("AudioEncoder.mlmodelc")
            let textDecoderPath = localModelPath.appendingPathComponent("TextDecoder.mlmodelc")

            let hasLocalModel = FileManager.default.fileExists(atPath: melSpectrogramPath.path) &&
                               FileManager.default.fileExists(atPath: audioEncoderPath.path) &&
                               FileManager.default.fileExists(atPath: textDecoderPath.path)

            if hasLocalModel {
                logger.info("✅ Found all required model components:")
                logger.info("   - MelSpectrogram.mlmodelc")
                logger.info("   - AudioEncoder.mlmodelc")
                logger.info("   - TextDecoder.mlmodelc")
            }

            if hasLocalModel {
                // Local model exists - use it without downloading
                logger.info("✅ Found complete local model at: \(localModelPath.path)")
                whisperKit = try await WhisperKit(
                    modelFolder: localModelPath.path,
                    verbose: true,
                    logLevel: .info,
                    prewarm: true,
                    download: false  // Use local model only
                )
                logger.info("✅ WhisperKit initialized successfully with local model: \(whisperKitModelName)")
            } else {
                // No local model - need to download
                logger.info("⬇️ No local model found, need to download...")

                // CRITICAL FIX: Set environment variable to bypass offline mode detection
                // This allows download even on cellular/constrained networks
                logger.info("🔧 Disabling offline mode check for model download...")
                setenv("CI_DISABLE_NETWORK_MONITOR", "1", 1)

                defer {
                    // Re-enable network monitoring after download
                    unsetenv("CI_DISABLE_NETWORK_MONITOR")
                }

                do {
                    logger.info("📥 Downloading model: \(whisperKitModelName)...")
                    logger.info("📍 Expected download location: \(localModelPath.path)")
                    logger.info("📍 Repository: argmaxinc/whisperkit-coreml")

                    // Use WhisperKit's download method with explicit configuration
                    let config = WhisperKitConfig(
                        model: whisperKitModelName,
                        downloadBase: nil,  // Use default: ~/Documents/huggingface/
                        modelRepo: "argmaxinc/whisperkit-coreml",
                        modelFolder: nil,
                        tokenizerFolder: nil,
                        computeOptions: nil,
                        audioProcessor: nil,
                        featureExtractor: nil,
                        audioEncoder: nil,
                        textDecoder: nil,
                        logitsFilters: nil,
                        segmentSeeker: nil,
                        verbose: true,
                        logLevel: .info,
                        prewarm: true,
                        load: true,
                        download: true,  // Enable download
                        useBackgroundDownloadSession: false
                    )

                    whisperKit = try await WhisperKit(config)
                    logger.info("✅ WhisperKit initialized successfully with downloaded model: \(whisperKitModelName)")

                    // Verify the download completed successfully
                    if FileManager.default.fileExists(atPath: localModelPath.path) {
                        logger.info("✅ Verified model saved at: \(localModelPath.path)")

                        // List what was downloaded
                        if let contents = try? FileManager.default.contentsOfDirectory(atPath: localModelPath.path) {
                            logger.info("📦 Downloaded model contents:")
                            for item in contents {
                                logger.info("   - \(item)")
                            }
                        }
                    } else {
                        logger.warning("⚠️ Model initialized but not found at expected path: \(localModelPath.path)")
                    }
                } catch {
                    logger.warning("⚠️ Failed to download/initialize model: \(error.localizedDescription)")
                    logger.warning("⚠️ Trying with fallback base model...")

                    // Fallback to base model
                    let fallbackConfig = WhisperKitConfig(
                        model: "openai_whisper-base",
                        downloadBase: nil,
                        modelRepo: "argmaxinc/whisperkit-coreml",
                        modelFolder: nil,
                        tokenizerFolder: nil,
                        computeOptions: nil,
                        audioProcessor: nil,
                        featureExtractor: nil,
                        audioEncoder: nil,
                        textDecoder: nil,
                        logitsFilters: nil,
                        segmentSeeker: nil,
                        verbose: true,
                        logLevel: .info,
                        prewarm: true,
                        load: true,
                        download: true,
                        useBackgroundDownloadSession: false
                    )

                    whisperKit = try await WhisperKit(fallbackConfig)
                    logger.info("✅ WhisperKit initialized with fallback base model")
                }
            }

            currentModelPath = modelPath ?? "whisper-base"
            isInitialized = true
            logger.info("✅ Successfully initialized WhisperKit")
            logger.debug("isInitialized: \(self.isInitialized)")
        } catch {
            logger.error("❌ Failed to initialize WhisperKit: \(error, privacy: .public)")
            logger.error("Error details: \(error.localizedDescription, privacy: .public)")

            // Provide helpful error message
            if error.localizedDescription.contains("Repository not available locally") {
                logger.error("💡 Hint: The model needs to be downloaded but network conditions prevent it.")
                logger.error("💡 This usually happens on cellular data or low data mode.")
                logger.error("💡 Suggested solutions:")
                logger.error("   1. Connect to WiFi (preferred)")
                logger.error("   2. Disable Low Data Mode in Settings")
                logger.error("   3. The app has attempted to bypass this restriction")
            }

            throw VoiceError.transcriptionFailed(error)
        }
    }

    public func transcribe(
        audioData: Data,
        options: STTOptions
    ) async throws -> STTTranscriptionResult {
        // Convert Data to Float array
        let audioSamples = audioData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
        let result = try await transcribeInternal(samples: audioSamples, options: options)
        // Convert STTResult to STTTranscriptionResult
        return STTTranscriptionResult(
            transcript: result.text,
            confidence: result.confidence,
            timestamps: nil,
            language: result.language,
            alternatives: nil
        )
    }

    /// Internal transcription with Float samples
    private func transcribeInternal(
        samples: [Float],
        options: STTOptions
    ) async throws -> STTResult {
        logger.info("transcribe() called with \(samples.count) samples")
        logger.debug("Options - Language: \(options.language, privacy: .public)")

        guard isInitialized, let whisperKit = whisperKit else {
            logger.error("❌ Service not initialized!")
            throw VoiceError.serviceNotInitialized
        }

        guard !samples.isEmpty else {
            logger.error("❌ No audio samples to transcribe!")
            throw VoiceError.unsupportedAudioFormat
        }

        let duration = Double(samples.count) / 16000.0
        logger.info("Audio: \(samples.count) samples, \(String(format: "%.2f", duration))s")

        // Simple audio validation
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))

        logger.info("Audio stats: max=\(String(format: "%.4f", maxAmplitude)), rms=\(String(format: "%.4f", rms))")

        if samples.allSatisfy({ $0 == 0 }) {
            logger.warning("All samples are zero - returning empty result")
            return STTResult(
                text: "",
                language: options.language,
                confidence: 0.0,
                duration: duration
            )
        }

        // For short audio, don't pad with zeros - WhisperKit handles it better
        var processedSamples = samples

        // Only pad if extremely short (less than 1.0 second)
        // WhisperKit performs much better with at least 1 second of audio
        let minRequiredSamples = 16000 // 1.0 seconds minimum
        if samples.count < minRequiredSamples {
            logger.info("📏 Audio too short (\(samples.count) samples), padding to \(minRequiredSamples)")
            // Pad with very low noise instead of zeros to avoid silence detection
            let noise = (0..<(minRequiredSamples - samples.count)).map { _ in Float.random(in: -0.0001...0.0001) }
            processedSamples = samples + noise
        } else {
            logger.info("📏 Processing \(samples.count) samples without padding")
        }

        return try await transcribeWithSamples(processedSamples, options: options, originalDuration: duration)
    }

    private func transcribeWithSamples(
        _ audioSamples: [Float],
        options: STTOptions,
        originalDuration: Double
    ) async throws -> STTResult {
        guard let whisperKit = whisperKit else {
            throw VoiceError.serviceNotInitialized
        }

        logger.info("Starting WhisperKit transcription with \(audioSamples.count) samples...")

        // Adaptive configuration based on audio length for better transcription
        let audioLengthSeconds = Float(audioSamples.count) / 16000.0  // Assuming 16kHz sample rate

        // Adjust noSpeechThreshold based on audio length - shorter audio needs lower threshold
        let adaptiveNoSpeechThreshold: Float = audioLengthSeconds < 2.0 ? 0.3 : 0.4

        // Use more conservative settings to avoid garbled output
        let decodingOptions = DecodingOptions(
            task: .transcribe,
            language: "en",  // Force English
            temperature: 0.0,  // Conservative - no randomness
            temperatureFallbackCount: 1,  // Reduce fallbacks to prevent garbled output
            sampleLength: 224,  // Standard length
            usePrefillPrompt: false,  // Disable prefill to avoid artifacts
            detectLanguage: false,  // Force English instead of auto-detect
            skipSpecialTokens: true,  // Skip special tokens to get clean text
            withoutTimestamps: true,  // No timestamps for cleaner output
            compressionRatioThreshold: 1.8,  // Lower threshold to catch more repetitive patterns
            logProbThreshold: -1.0,  // More conservative probability threshold
            noSpeechThreshold: adaptiveNoSpeechThreshold  // Adaptive threshold based on audio length
        )

        logger.info("🚀 Calling WhisperKit.transcribe() with \(audioSamples.count) samples...")
        let transcriptionResults = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: decodingOptions
        )
        logger.info("✅ WhisperKit.transcribe() completed with \(transcriptionResults.count) results")

        // Extract and clean the transcribed text
        var transcribedText = ""
        if let firstResult = transcriptionResults.first {
            // Get clean text without timestamps or special tokens
            transcribedText = firstResult.text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove any remaining special tokens that might have slipped through
            transcribedText = transcribedText.replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: ">>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Validate result to reject garbled output
        if isGarbledOutput(transcribedText) {
            logger.warning("⚠️ Detected garbled output, rejecting transcription")
            transcribedText = ""
        }

        // Simple logging
        if !transcribedText.isEmpty {
            logger.info("✅ Transcribed: '\(transcribedText)'")
        } else if transcriptionResults.isEmpty {
            logger.warning("⚠️ No transcription results returned")
        } else {
            logger.warning("⚠️ Empty or invalid transcription")
            // Log basic audio stats for debugging
            let rms = sqrt(audioSamples.reduce(0) { $0 + $1 * $1 } / Float(audioSamples.count))
            logger.info("  Audio: \(Double(audioSamples.count) / 16000.0)s, RMS: \(String(format: "%.4f", rms))")
        }

        // Return the result (even if empty)
        let result = STTResult(
            text: transcribedText,
            language: transcriptionResults.first?.language ?? options.language,
            confidence: transcribedText.isEmpty ? 0.0 : 0.95,
            duration: originalDuration
        )
        logger.info("✅ Returning result with text: '\(result.text)'")
        return result
    }


    public func cleanup() async {
        isInitialized = false
        currentModelPath = nil
        whisperKit = nil
    }

    // MARK: - Initialization

    public init() {
        logger.info("Service instance created")
        // No initialization needed for basic service
    }

    // MARK: - Helper Methods

    private func mapModelIdToWhisperKitName(_ modelId: String) -> String {
        // Map common model IDs to WhisperKit model names
        switch modelId.lowercased() {
        case "whisper-tiny", "tiny":
            return "openai_whisper-tiny"
        case "whisper-base", "base":
            return "openai_whisper-base"
        case "whisper-small", "small":
            return "openai_whisper-small"
        case "whisper-medium", "medium":
            return "openai_whisper-medium"
        case "whisper-large", "large":
            return "openai_whisper-large-v3"
        default:
            // Default to base if not recognized
            logger.warning("Unknown model ID: \(modelId), defaulting to whisper-base")
            return "openai_whisper-base"
        }
    }

    /// Get the local path where WhisperKit caches models
    ///
    /// **Path Structure:**
    /// WhisperKit uses the Hub library (swift-transformers) which stores models at:
    /// `~/Documents/huggingface/models/{repo}/{model-name}/`
    ///
    /// **For openai_whisper-base:**
    /// Full path: `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-base/`
    ///
    /// **Expected model structure:**
    /// ```
    /// openai_whisper-base/
    /// ├── MelSpectrogram.mlmodelc/
    /// ├── AudioEncoder.mlmodelc/
    /// ├── TextDecoder.mlmodelc/
    /// ├── config.json
    /// └── generation_config.json
    /// ```
    ///
    /// **Source verification:**
    /// - Hub library default: HubApi.swift lines 24-31 (~/Documents/huggingface/)
    /// - Repo path: HubApi.localRepoLocation() appends "models/{repo-id}"
    /// - This matches WhisperKit's download behavior exactly
    ///
    /// - Parameter modelName: The WhisperKit model name (e.g., "openai_whisper-base")
    /// - Returns: The URL where WhisperKit downloads and caches the model
    private func getLocalModelPath(for modelName: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(modelName)
    }

    // MARK: - Streaming Support

    /// Support for streaming transcription
    public var supportsStreaming: Bool {
        return true
    }

    /// Transcribe audio stream in real-time
    public func streamTranscribe<S: AsyncSequence>(
        audioStream: S,
        options: STTOptions,
        onPartial: @escaping (String) -> Void
    ) async throws -> STTTranscriptionResult where S.Element == Data {
        // For now, return empty result - streaming needs proper implementation
        return STTTranscriptionResult(
            transcript: "",
            confidence: 1.0,
            timestamps: nil,
            language: nil,
            alternatives: nil
        )
    }

    public func transcribeStream(
        audioStream: AsyncStream<VoiceAudioChunk>,
        options: STTOptions
    ) -> AsyncThrowingStream<STTSegment, Error> {
        AsyncThrowingStream { continuation in
            self.streamingTask = Task {
                do {
                    // Ensure WhisperKit is loaded
                    guard let whisperKit = self.whisperKit else {
                        if self.isInitialized {
                            // Already initialized, but whisperKit is nil
                            throw VoiceError.serviceNotInitialized
                        } else {
                            // Not initialized, try to initialize with default model
                            try await self.initialize(modelPath: nil)
                            guard self.whisperKit != nil else {
                                throw VoiceError.serviceNotInitialized
                            }
                        }
                        return
                    }

                    // Process audio stream
                    var audioBuffer = Data()
                    var lastTranscript = ""

                    for await chunk in audioStream {
                        audioBuffer.append(chunk.data)

                        // Process when we have enough audio (500ms)
                        if audioBuffer.count >= minAudioLength {
                            // Convert to float array for WhisperKit
                            let floatArray = audioBuffer.withUnsafeBytes { buffer in
                                Array(buffer.bindMemory(to: Float.self))
                            }

                            // Transcribe using WhisperKit with shorter settings for streaming
                            let decodingOptions = DecodingOptions(
                                task: .transcribe,  // Always transcribe for STT
                                language: options.language,
                                temperature: 0.0,
                                temperatureFallbackCount: 0,
                                sampleLength: 224,  // Shorter for streaming
                                usePrefillPrompt: false,
                                detectLanguage: false,
                                skipSpecialTokens: true,
                                withoutTimestamps: false
                            )

                            let results = try await whisperKit.transcribe(
                                audioArray: floatArray,
                                decodeOptions: decodingOptions
                            )

                            // Get the transcribed text
                            if let result = results.first {
                                let newText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

                                // Only yield if there's new content
                                if !newText.isEmpty && newText != lastTranscript {
                                    let segment = STTSegment(
                                        text: newText,
                                        startTime: chunk.timestamp - 0.5,
                                        endTime: chunk.timestamp,
                                        confidence: 0.95
                                    )
                                    continuation.yield(segment)
                                    lastTranscript = newText
                                }
                            }

                            // Keep last 100ms for context continuity
                            audioBuffer = Data(audioBuffer.suffix(contextOverlap))
                        }
                    }

                    // Process any remaining audio
                    if audioBuffer.count > 0 {
                        // Final transcription with remaining audio
                        let floatArray = audioBuffer.withUnsafeBytes { buffer in
                            Array(buffer.bindMemory(to: Float.self))
                        }

                        let decodingOptions = DecodingOptions(
                            task: .transcribe,  // Always transcribe for STT
                            language: options.language,
                            temperature: 0.0,
                            temperatureFallbackCount: 0,
                            sampleLength: 224,
                            usePrefillPrompt: false,
                            detectLanguage: false,
                            skipSpecialTokens: true,
                            withoutTimestamps: false
                        )

                        let results = try await whisperKit.transcribe(
                            audioArray: floatArray,
                            decodeOptions: decodingOptions
                        )

                        if let result = results.first {
                            let segment = STTSegment(
                                text: result.text,
                                startTime: Date().timeIntervalSince1970 - 0.1,
                                endTime: Date().timeIntervalSince1970,
                                confidence: 0.95
                            )
                            continuation.yield(segment)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Detect garbled or nonsensical WhisperKit output
    private func isGarbledOutput(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty text is not garbled, just empty
        guard !trimmedText.isEmpty else { return false }

        // Check for repetitive word patterns (like "you you you you" or "he said he said")
        let words = trimmedText.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        if words.count > 3 {
            // Check for excessive word repetition
            let wordCounts = Dictionary(words.map { ($0, 1) }, uniquingKeysWith: +)
            for (word, count) in wordCounts {
                // If any single word appears more than 40% of total words, it's likely garbled
                if Double(count) / Double(words.count) > 0.4 {
                    logger.warning("⚠️ Detected excessive word repetition: '\(word)' appears \(count) times in \(words.count) words")
                    return true
                }
            }

            // Check for repeating short phrases (2-3 word patterns)
            if words.count >= 6 {
                // Check 2-word patterns
                var twoWordPatterns: [String: Int] = [:]
                for i in 0..<(words.count - 1) {
                    let pattern = "\(words[i]) \(words[i + 1])"
                    twoWordPatterns[pattern, default: 0] += 1
                }
                for (pattern, count) in twoWordPatterns {
                    if count > 3 && Double(count * 2) / Double(words.count) > 0.5 {
                        logger.warning("⚠️ Detected repeating phrase pattern: '\(pattern)' repeats \(count) times")
                        return true
                    }
                }
            }
        }

        // Check for non-Latin scripts (Hebrew, Arabic, Chinese, etc.)
        // We expect English output, so non-Latin scripts indicate wrong language detection
        let nonLatinRanges: [ClosedRange<UInt32>] = [
            0x0590...0x05FF,  // Hebrew
            0x0600...0x06FF,  // Arabic
            0x0700...0x074F,  // Syriac
            0x0750...0x077F,  // Arabic Supplement
            0x0E00...0x0E7F,  // Thai
            0x1000...0x109F,  // Myanmar
            0x1100...0x11FF,  // Hangul Jamo
            0x3040...0x309F,  // Hiragana
            0x30A0...0x30FF,  // Katakana
            0x4E00...0x9FFF,  // CJK Unified Ideographs
            0xAC00...0xD7AF,  // Hangul Syllables
        ]

        let nonLatinCount = trimmedText.unicodeScalars.filter { scalar in
            nonLatinRanges.contains { range in
                range.contains(scalar.value)
            }
        }.count

        // If more than 30% of characters are non-Latin, it's likely wrong language
        if Double(nonLatinCount) / Double(trimmedText.count) > 0.3 {
            logger.warning("⚠️ Detected non-Latin script in output (\(nonLatinCount)/\(trimmedText.count) characters)")
            return true
        }

        // Check for common garbled patterns
        let garbledPatterns = [
            // Repetitive characters
            "^[\\(\\)\\-\\.\\s]+$",  // Only parentheses, dashes, dots, spaces
            "^[\\-\\s]{10,}",        // Many consecutive dashes or spaces
            "^[\\(]{5,}",           // Many consecutive opening parentheses
            "^[\\)]{5,}",           // Many consecutive closing parentheses
            "^[\\.,]{5,}",          // Many consecutive dots/commas
            // Special token patterns
            "^\\s*\\[.*\\]\\s*$",   // Text wrapped in brackets
            "^\\s*<.*>\\s*$",       // Text wrapped in angle brackets
        ]

        for pattern in garbledPatterns {
            if trimmedText.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        // Check character composition - if more than 70% is punctuation, likely garbled
        let punctuationCount = trimmedText.filter { $0.isPunctuation || $0 == "-" }.count
        let totalCount = trimmedText.count
        if totalCount > 5 && Double(punctuationCount) / Double(totalCount) > 0.7 {
            return true
        }

        // Check for excessive repetition of the same character
        let charCounts = Dictionary(trimmedText.map { ($0, 1) }, uniquingKeysWith: +)
        for (char, count) in charCounts {
            // Ignore spaces and dashes for this check
            if char != " " && char != "-" && count > max(10, trimmedText.count / 2) {
                return true
            }
        }

        return false
    }
}
