import Foundation
import RunAnywhere
import AVFoundation
import Combine
import os

@MainActor
class VoiceAssistantViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.runanywhere.RunAnywhereAI", category: "VoiceAssistantViewModel")
    private let audioCapture = AudioCapture()
    private var cancellables = Set<AnyCancellable>()
    private let selectionStore = VoiceModelSelectionStore.shared

    // MARK: - Published Properties
    @Published var currentTranscript: String = ""
    @Published var assistantResponse: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var isInitialized = false
    @Published var currentStatus = "Initializing..."
    @Published var currentLLMModel: String = ""
    @Published var whisperModel: String = "Whisper Base"
    @Published var isListening: Bool = false

    // MARK: - Model Selection State (from persistent store)
    var sttModel: (framework: LLMFramework, name: String, id: String)? {
        get { selectionStore.sttModel }
        set { selectionStore.sttModel = newValue }
    }

    var llmModel: (framework: LLMFramework, name: String, id: String)? {
        get { selectionStore.llmModel }
        set { selectionStore.llmModel = newValue }
    }

    var ttsModel: (framework: LLMFramework, name: String, id: String)? {
        get { selectionStore.ttsModel }
        set { selectionStore.ttsModel = newValue }
    }

    // MARK: - Model Loading State (from SDK lifecycle tracker)
    @Published var sttModelState: ModelLoadState = .notLoaded
    @Published var llmModelState: ModelLoadState = .notLoaded
    @Published var ttsModelState: ModelLoadState = .notLoaded

    /// Check if all required models are selected for the voice pipeline
    var allModelsReady: Bool {
        sttModel != nil && llmModel != nil && ttsModel != nil
    }

    /// Check if all models are actually loaded in memory
    var allModelsLoaded: Bool {
        sttModelState.isLoaded && llmModelState.isLoaded && ttsModelState.isLoaded
    }

    // Session state for UI
    enum SessionState: Equatable {
        case disconnected
        case connecting
        case connected
        case listening
        case processing
        case speaking
        case error(String)

        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected),
                 (.listening, .listening),
                 (.processing, .processing),
                 (.speaking, .speaking):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    @Published var sessionState: SessionState = .disconnected
    @Published var isSpeechDetected: Bool = false

    // MARK: - Pipeline State
    private var voicePipeline: ModularVoicePipeline?
    private var pipelineTask: Task<Void, Never>?
    private let whisperModelName: String = "whisper-base"

    // MARK: - Initialization

    func initialize() async {
        logger.info("🚀 [INIT] Initializing VoiceAssistantViewModel...")
        let initStartTime = Date()

        // Request microphone permission
        logger.info("🎤 [PERMISSION] Requesting microphone permission...")
        let hasPermission = await AudioCapture.requestMicrophonePermission()
        logger.info("🎤 [PERMISSION] Microphone permission result: \(hasPermission)")
        
        guard hasPermission else {
            currentStatus = "Microphone permission denied"
            errorMessage = "Please enable microphone access in Settings"
            logger.error("❌ [PERMISSION] Microphone permission denied - Voice assistant cannot function")
            return
        }

        logger.info("✅ [PERMISSION] Microphone permission granted")

        // Subscribe to model lifecycle changes from SDK
        logger.info("📡 [LIFECYCLE] Subscribing to model lifecycle tracker...")
        subscribeToModelLifecycle()
        logger.info("✅ [LIFECYCLE] Subscribed to model lifecycle tracker")

        // Get current LLM model info
        logger.info("📊 [MODEL] Updating model info...")
        updateModelInfo()

        // Set the Whisper model display name
        updateWhisperModelName()

        // Listen for model changes (legacy support)
        logger.info("📢 [NOTIFICATION] Registering for model loaded notifications...")
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ModelLoaded"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.logger.info("📢 [NOTIFICATION] Received ModelLoaded notification")
                self?.updateModelInfo()
            }
        }
        logger.info("✅ [NOTIFICATION] Registered for model loaded notifications")

        let initTime = Date().timeIntervalSince(initStartTime)
        logger.info("✅ [INIT] Voice assistant initialized successfully - Time: \(String(format: "%.2f", initTime))s")
        logger.info("📊 [INIT] Initial state - STT: \(self.sttModel?.name ?? "none"), LLM: \(self.llmModel?.name ?? "none"), TTS: \(self.ttsModel?.name ?? "none")")

        // Auto-load previously selected models if they exist
        await autoLoadSelectedModels()

        currentStatus = "Ready to listen"
        isInitialized = true
    }

    /// Auto-load previously selected models on app launch
    private func autoLoadSelectedModels() async {
        logger.info("🔄 [AUTO-LOAD] Checking for previously selected models to auto-load...")

        // Auto-load STT model if selected but not loaded
        if let stt = sttModel, !sttModelState.isLoaded {
            logger.info("📥 [AUTO-LOAD] Auto-loading STT model: \(stt.name) (ID: \(stt.id))")
            await loadSTTModel(modelId: stt.id, modelName: stt.name)
        } else if let stt = sttModel {
            logger.info("✅ [AUTO-LOAD] STT model already loaded: \(stt.name)")
        } else {
            logger.info("ℹ️ [AUTO-LOAD] No STT model selected")
        }

        // Auto-load LLM model if selected but not loaded
        if let llm = llmModel, !llmModelState.isLoaded {
            logger.info("📥 [AUTO-LOAD] Auto-loading LLM model: \(llm.name) (ID: \(llm.id))")
            await loadLLMModel(modelId: llm.id, modelName: llm.name)
        } else if let llm = llmModel {
            logger.info("✅ [AUTO-LOAD] LLM model already loaded: \(llm.name)")
        } else {
            logger.info("ℹ️ [AUTO-LOAD] No LLM model selected")
        }

        // Auto-load TTS model if selected but not loaded
        if let tts = ttsModel, !ttsModelState.isLoaded {
            logger.info("📥 [AUTO-LOAD] Auto-loading TTS model: \(tts.name) (ID: \(tts.id))")
            await loadTTSModel(modelId: tts.id, modelName: tts.name)
        } else if let tts = ttsModel {
            logger.info("✅ [AUTO-LOAD] TTS model already loaded: \(tts.name)")
        } else {
            logger.info("ℹ️ [AUTO-LOAD] No TTS model selected")
        }

        logger.info("✅ [AUTO-LOAD] Auto-load complete - STT: \(self.sttModelState.isLoaded), LLM: \(self.llmModelState.isLoaded), TTS: \(self.ttsModelState.isLoaded)")
    }

    /// Subscribe to SDK's model lifecycle tracker for real-time model state updates
    private func subscribeToModelLifecycle() {
        // Subscribe to the persistent store's model changes to trigger UI updates
        selectionStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Trigger UI update when selection store changes
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe changes to loaded models via the SDK's lifecycle tracker
        // Debounce to prevent excessive updates from SDK state flipping
        ModelLifecycleTracker.shared.$modelsByModality
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] modelsByModality in
                guard let self = self else { return }

                // Update STT model state - ONLY update state, NOT selection
                if let sttState = modelsByModality[.stt] {
                    self.sttModelState = sttState.state
                    if sttState.state.isLoaded {
                        // If we have a selected STT model and it matches the loaded one, just update display name
                        if let currentSTT = self.sttModel, currentSTT.id == sttState.modelId {
                            self.whisperModel = sttState.modelName
                            self.logger.info("✅ STT model loaded: \(sttState.modelName)")
                        }
                        // NEVER auto-select - let user explicitly choose from UI
                    }
                } else if self.sttModel == nil {
                    // Only reset state if no model is selected
                    self.sttModelState = .notLoaded
                }

                // Update LLM model state - ONLY update state, NOT selection
                if let llmState = modelsByModality[.llm] {
                    self.llmModelState = llmState.state
                    if llmState.state.isLoaded {
                        // If we have a selected LLM model and it matches the loaded one, just update display name
                        if let currentLLM = self.llmModel, currentLLM.id == llmState.modelId {
                            self.currentLLMModel = llmState.modelName
                            self.logger.info("✅ LLM model loaded: \(llmState.modelName)")
                        }
                        // NEVER auto-select - let user explicitly choose from UI
                    }
                } else if self.llmModel == nil {
                    // Only reset state if no model is selected
                    self.llmModelState = .notLoaded
                }

                // Update TTS model state - ONLY update state, NOT selection
                if let ttsState = modelsByModality[.tts] {
                    self.ttsModelState = ttsState.state
                    if ttsState.state.isLoaded {
                        // If we have a selected TTS model and it matches the loaded one, just log it
                        if let currentTTS = self.ttsModel, currentTTS.id == ttsState.modelId {
                            self.logger.info("✅ TTS model loaded: \(ttsState.modelName)")
                        }
                        // NEVER auto-select - let user explicitly choose from UI
                    }
                } else if self.ttsModel == nil {
                    // Only reset state if no model is selected
                    self.ttsModelState = .notLoaded
                }

                // Log overall state
                self.logger.info("📊 [LIFECYCLE] Voice pipeline state update:")
                self.logger.info("   - STT: \(self.sttModelState.isLoaded ? "✅ Loaded" : "❌ Not loaded") (\(self.sttModel?.name ?? "none"))")
                self.logger.info("   - LLM: \(self.llmModelState.isLoaded ? "✅ Loaded" : "❌ Not loaded") (\(self.llmModel?.name ?? "none"))")
                self.logger.info("   - TTS: \(self.ttsModelState.isLoaded ? "✅ Loaded" : "❌ Not loaded") (\(self.ttsModel?.name ?? "none"))")
            }
            .store(in: &cancellables)

        // Check initial state - ONLY update load states, NEVER auto-select models
        let modelsByModality = ModelLifecycleTracker.shared.modelsByModality
        if let sttState = modelsByModality[.stt] {
            sttModelState = sttState.state
            // If we already have a selection from persistent storage, update display name
            if sttState.state.isLoaded, let currentSTT = sttModel, currentSTT.id == sttState.modelId {
                whisperModel = sttState.modelName
            }
        }
        if let llmState = modelsByModality[.llm] {
            llmModelState = llmState.state
            // If we already have a selection from persistent storage, update display name
            if llmState.state.isLoaded, let currentLLM = llmModel, currentLLM.id == llmState.modelId {
                currentLLMModel = llmState.modelName
            }
        }
        if let ttsState = modelsByModality[.tts] {
            ttsModelState = ttsState.state
            // TTS display name doesn't need updating
        }
    }

    private func updateModelInfo() {
        // Try ModelManager first
        if let model = ModelManager.shared.getCurrentModel() {
            currentLLMModel = model.name
            logger.info("Using LLM model from ModelManager: \(self.currentLLMModel)")
        }
        // Fallback to ModelListViewModel
        else if let model = ModelListViewModel.shared.currentModel {
            currentLLMModel = model.name
            logger.info("Using LLM model from ModelListViewModel: \(self.currentLLMModel)")
        }
        // Default if no model loaded
        else {
            currentLLMModel = "No model loaded"
            logger.info("No LLM model currently loaded")
        }
    }

    private func updateWhisperModelName() {
        switch whisperModelName {
        case "whisper-base":
            whisperModel = "Whisper Base"
        case "whisper-small":
            whisperModel = "Whisper Small"
        case "whisper-medium":
            whisperModel = "Whisper Medium"
        case "whisper-large":
            whisperModel = "Whisper Large"
        case "whisper-large-v3":
            whisperModel = "Whisper Large v3"
        default:
            whisperModel = whisperModelName.replacingOccurrences(of: "-", with: " ").capitalized
        }
        logger.info("Using Whisper model: \(self.whisperModel)")
    }

    // MARK: - Model Selection for Voice Pipeline

    /// Set the STT model for voice pipeline
    func setSTTModel(_ model: ModelInfo) async {
        logger.info("🎤 [STT] Setting STT model - Name: \(model.name), ID: \(model.id), Framework: \(model.preferredFramework?.displayName ?? "default")")

        let framework = model.preferredFramework ?? .whisperKit
        let previousModel = sttModel

        // CRITICAL: Set the model in the store first to ensure persistence
        sttModel = (framework: framework, name: model.name, id: model.id)
        whisperModel = model.name

        logger.info("✅ [STT] Model set successfully - Previous: \(previousModel?.name ?? "none"), New: \(model.name)")
        logger.info("✅ [STT] Model selection persisted to storage")

        // Note: STT model loading is verified by the ModelSelectionSheet calling RunAnywhere.loadSTTModel()
        // The model state will be updated via the lifecycle tracker subscription
    }

    /// Set the LLM model for voice pipeline
    func setLLMModel(_ model: ModelInfo) async {
        logger.info("🧠 [LLM] Setting LLM model - Name: \(model.name), ID: \(model.id), Framework: \(model.preferredFramework?.displayName ?? "default")")

        let framework = model.preferredFramework ?? .llamaCpp
        let previousModel = llmModel

        // CRITICAL: Set the model in the store first to ensure persistence
        llmModel = (framework: framework, name: model.name, id: model.id)
        currentLLMModel = model.name

        logger.info("✅ [LLM] Model set successfully - Previous: \(previousModel?.name ?? "none"), New: \(model.name)")
        logger.info("✅ [LLM] Model selection persisted to storage")

        // NOTE: LLM model loading is handled by ModelSelectionSheet calling RunAnywhere.loadModel()
        // The model state will be updated via the lifecycle tracker subscription
    }

    /// Set the TTS model for voice pipeline
    func setTTSModel(_ model: ModelInfo) async {
        logger.info("🔊 [TTS] Setting TTS model - Name: \(model.name), ID: \(model.id), Framework: \(model.preferredFramework?.displayName ?? "default")")

        let framework = model.preferredFramework ?? .onnx
        let previousModel = ttsModel

        // CRITICAL: Set the model in the store first to ensure persistence
        ttsModel = (framework: framework, name: model.name, id: model.id)

        logger.info("✅ [TTS] Model set successfully - Previous: \(previousModel?.name ?? "none"), New: \(model.name)")
        logger.info("✅ [TTS] Model selection persisted to storage")

        // Note: TTS model loading is verified by the ModelSelectionSheet calling RunAnywhere.loadTTSModel()
        // The model state will be updated via the lifecycle tracker subscription
    }
    
    // MARK: - Model Loading
    
    /// Load STT model by ID
    private func loadSTTModel(modelId: String, modelName: String) async {
        logger.info("📥 [STT] Starting model load - ID: \(modelId), Name: \(modelName)")
        let startTime = Date()

        do {
            logger.info("⏳ [STT] Calling RunAnywhere.loadSTTModel(\(modelId))...")
            try await RunAnywhere.loadSTTModel(modelId)

            let loadTime = Date().timeIntervalSince(startTime)
            logger.info("✅ [STT] Model loaded successfully - ID: \(modelId), Name: \(modelName), Time: \(String(format: "%.2f", loadTime))s")
        } catch {
            logger.error("❌ [STT] Failed to load model - ID: \(modelId), Error: \(error.localizedDescription)")
            errorMessage = "Failed to load STT model: \(error.localizedDescription)"
        }
    }
    
    /// Load LLM model by ID
    private func loadLLMModel(modelId: String, modelName: String) async {
        logger.info("📥 [LLM] Starting model load - ID: \(modelId), Name: \(modelName)")
        let startTime = Date()

        do {
            logger.info("⏳ [LLM] Calling RunAnywhere.loadModel(\(modelId))...")
            try await RunAnywhere.loadModel(modelId)

            let loadTime = Date().timeIntervalSince(startTime)
            logger.info("✅ [LLM] Model loaded successfully - ID: \(modelId), Name: \(modelName), Time: \(String(format: "%.2f", loadTime))s")
        } catch {
            logger.error("❌ [LLM] Failed to load model - ID: \(modelId), Error: \(error.localizedDescription)")
            logger.error("❌ [LLM] Error type: \(type(of: error))")
            logger.error("❌ [LLM] Error details: \(String(describing: error))")
            errorMessage = "Failed to load LLM model: \(error.localizedDescription)"
        }
    }

    /// Load TTS model by ID
    private func loadTTSModel(modelId: String, modelName: String) async {
        logger.info("📥 [TTS] Starting model load - ID: \(modelId), Name: \(modelName)")
        let startTime = Date()

        do {
            logger.info("⏳ [TTS] Calling RunAnywhere.loadTTSModel(\(modelId))...")
            try await RunAnywhere.loadTTSModel(modelId)

            let loadTime = Date().timeIntervalSince(startTime)
            logger.info("✅ [TTS] Model loaded successfully - ID: \(modelId), Name: \(modelName), Time: \(String(format: "%.2f", loadTime))s")
        } catch {
            logger.error("❌ [TTS] Failed to load model - ID: \(modelId), Error: \(error.localizedDescription)")
            errorMessage = "Failed to load TTS model: \(error.localizedDescription)"
        }
    }

    // MARK: - Conversation Control

    /// Start real-time conversation using modular pipeline
    func startConversation() async {
        logger.info("🚀 [VOICE] Starting voice conversation pipeline...")
        logger.info("📊 [VOICE] Current state - STT: \(self.sttModel?.name ?? "none"), LLM: \(self.llmModel?.name ?? "none"), TTS: \(self.ttsModel?.name ?? "none")")

        // Validate that all models are selected
        guard let stt = sttModel, let llm = llmModel, let tts = ttsModel else {
            let missing = [
                sttModel == nil ? "STT" : nil,
                llmModel == nil ? "LLM" : nil,
                ttsModel == nil ? "TTS" : nil
            ].compactMap { $0 }
            
            logger.error("❌ [VOICE] Cannot start: Missing models - \(missing.joined(separator: ", "))")
            sessionState = .error("Please select all models (STT, LLM, TTS) before starting")
            errorMessage = "Please select all models (STT, LLM, TTS) before starting"
            return
        }

        logger.info("✅ [VOICE] All models selected - STT: \(stt.name) (\(stt.id)), LLM: \(llm.name) (\(llm.id)), TTS: \(tts.name) (\(tts.id))")

        sessionState = .connecting
        currentStatus = "Loading models..."

        // Ensure LLM model is loaded (STT and TTS are loaded by components)
        if !llmModelState.isLoaded {
            logger.info("⏳ [LLM] LLM model not loaded, loading now...")
            currentStatus = "Loading LLM model..."
            let loadStartTime = Date()
            
            do {
                logger.info("📥 [LLM] Loading model: \(llm.id)")
                try await RunAnywhere.loadModel(llm.id)
                let loadTime = Date().timeIntervalSince(loadStartTime)
                logger.info("✅ [LLM] Model loaded successfully - \(llm.name), Time: \(String(format: "%.2f", loadTime))s")
            } catch {
                logger.error("❌ [LLM] Failed to load model - ID: \(llm.id), Error: \(error.localizedDescription)")
                logger.error("❌ [LLM] Error type: \(type(of: error))")
                sessionState = .error("Failed to load LLM model: \(error.localizedDescription)")
                errorMessage = "Failed to load LLM model: \(error.localizedDescription)"
                return
            }
        } else {
            logger.info("✅ [LLM] LLM model already loaded - \(llm.name)")
        }

        logger.info("🔧 [VOICE] Creating pipeline configuration...")
        currentStatus = "Initializing components..."

        // Create pipeline configuration using selected models
        let config = ModularPipelineConfig(
            components: [.vad, .stt, .llm, .tts],
            vad: VADConfig(energyThreshold: 0.005), // Lower threshold for better short phrase detection
            stt: VoiceSTTConfig(modelId: stt.id),
            llm: VoiceLLMConfig(
                modelId: llm.id,
                systemPrompt: "You are a helpful voice assistant. Keep responses concise and conversational.",
                maxTokens: 100  // Limit response to 100 tokens for concise voice interactions
            ),
            tts: VoiceTTSConfig(voice: tts.id)
        )
        
        logger.info("✅ [VOICE] Pipeline config created:")
        logger.info("   - VAD: energyThreshold=0.005")
        logger.info("   - STT: modelId=\(stt.id) (\(stt.name))")
        logger.info("   - LLM: modelId=\(llm.id) (\(llm.name)), maxTokens=100")
        logger.info("   - TTS: voice=\(tts.id) (\(tts.name))")

        // Create the pipeline
        logger.info("🏗️ [VOICE] Creating voice pipeline...")
        let pipelineStartTime = Date()
        
        do {
            voicePipeline = try await RunAnywhere.createVoicePipeline(config: config)
            let pipelineCreationTime = Date().timeIntervalSince(pipelineStartTime)
            logger.info("✅ [VOICE] Pipeline created successfully - Time: \(String(format: "%.2f", pipelineCreationTime))s")
        } catch {
            logger.error("❌ [VOICE] Failed to create pipeline - Error: \(error.localizedDescription)")
            logger.error("❌ [VOICE] Error type: \(type(of: error))")
            logger.error("❌ [VOICE] Error details: \(String(describing: error))")
            sessionState = .error("Failed to create pipeline: \(error.localizedDescription)")
            currentStatus = "Error"
            errorMessage = "Failed to create voice pipeline: \(error.localizedDescription)"
            return
        }

        // Initialize components first
        guard let pipeline = voicePipeline else {
            logger.error("❌ [VOICE] Pipeline is nil after creation")
            sessionState = .error("Failed to create pipeline")
            currentStatus = "Error"
            errorMessage = "Failed to create voice pipeline"
            return
        }

        logger.info("🔧 [VOICE] Initializing pipeline components...")
        let initStartTime = Date()
        var initializedComponents: [String] = []

        // Initialize all components
        do {
            for try await event in pipeline.initializeComponents() {
                handleInitializationEvent(event)
                
                // Track initialized components
                if case .componentInitialized(let name) = event {
                    initializedComponents.append(name)
                }
            }
            
            let initTime = Date().timeIntervalSince(initStartTime)
            logger.info("✅ [VOICE] All components initialized - Components: \(initializedComponents.joined(separator: ", ")), Time: \(String(format: "%.2f", initTime))s")
        } catch {
            logger.error("❌ [VOICE] Component initialization failed - Error: \(error.localizedDescription)")
            logger.error("❌ [VOICE] Error type: \(type(of: error))")
            logger.error("❌ [VOICE] Initialized so far: \(initializedComponents.joined(separator: ", "))")
            sessionState = .error("Initialization failed: \(error.localizedDescription)")
            currentStatus = "Error"
            errorMessage = "Component initialization failed: \(error.localizedDescription)"
            return
        }

        // Start audio capture after initialization is complete
        logger.info("🎤 [AUDIO] Starting audio capture...")
        let audioStream = audioCapture.startContinuousCapture()
        logger.info("✅ [AUDIO] Audio capture started")

        sessionState = .listening
        isListening = true
        currentStatus = "Listening..."
        errorMessage = nil

        // Process audio through pipeline
        logger.info("🔄 [VOICE] Starting pipeline processing task...")
        pipelineTask = Task {
            logger.info("▶️ [VOICE] Pipeline processing started")
            var eventCount = 0
            
            do {
                for try await event in voicePipeline!.process(audioStream: audioStream) {
                    eventCount += 1
                    await handlePipelineEvent(event)
                    
                    // Log every 10th event to avoid spam
                    if eventCount % 10 == 0 {
                        logger.debug("📊 [VOICE] Processed \(eventCount) events so far")
                    }
                }
                
                logger.info("✅ [VOICE] Pipeline processing completed - Total events: \(eventCount)")
            } catch {
                logger.error("❌ [VOICE] Pipeline processing error - Error: \(error.localizedDescription)")
                logger.error("❌ [VOICE] Error type: \(type(of: error))")
                logger.error("❌ [VOICE] Events processed before error: \(eventCount)")
                
                await MainActor.run {
                    self.errorMessage = "Pipeline error: \(error.localizedDescription)"
                    self.sessionState = .error(error.localizedDescription)
                    self.isListening = false
                }
            }
        }

        logger.info("✅ [VOICE] Voice conversation pipeline started successfully")
    }

    /// Stop conversation
    func stopConversation() async {
        logger.info("🛑 [VOICE] Stopping voice conversation...")
        let stateDescription: String = {
            switch sessionState {
            case .disconnected: return "disconnected"
            case .connecting: return "connecting"
            case .connected: return "connected"
            case .listening: return "listening"
            case .processing: return "processing"
            case .speaking: return "speaking"
            case .error(let message): return "error(\(message))"
            }
        }()
        logger.info("📊 [VOICE] Current state - isListening: \(self.isListening), isProcessing: \(self.isProcessing), sessionState: \(stateDescription)")

        isListening = false
        isProcessing = false
        isSpeechDetected = false

        // Cancel pipeline task
        if pipelineTask != nil {
            logger.info("🔄 [VOICE] Cancelling pipeline processing task...")
            pipelineTask?.cancel()
            pipelineTask = nil
            logger.info("✅ [VOICE] Pipeline task cancelled")
        }

        // Stop audio capture
        logger.info("🎤 [AUDIO] Stopping audio capture...")
        audioCapture.stopContinuousCapture()
        logger.info("✅ [AUDIO] Audio capture stopped")

        // Clean up pipeline
        if voicePipeline != nil {
            logger.info("🧹 [VOICE] Cleaning up pipeline...")
            voicePipeline = nil
            logger.info("✅ [VOICE] Pipeline cleaned up")
        }

        // Reset UI state
        currentStatus = "Ready to listen"
        sessionState = .disconnected
        errorMessage = nil

        logger.info("✅ [VOICE] Voice conversation stopped successfully")
    }

    /// Interrupt AI response
    func interruptResponse() async {
        // In the modular pipeline, we can stop and restart
        await stopConversation()
    }

    // MARK: - Initialization Event Handling

    @MainActor
    private func handleInitializationEvent(_ event: ModularPipelineEvent) {
        switch event {
        case .componentInitializing(let componentName):
            currentStatus = "Initializing \(componentName)..."
            logger.info("⏳ [INIT] Initializing component: \(componentName)")

        case .componentInitialized(let componentName):
            currentStatus = "\(componentName) ready"
            logger.info("✅ [INIT] Component initialized successfully: \(componentName)")

        case .componentInitializationFailed(let componentName, let error):
            logger.error("❌ [INIT] Component initialization failed - Component: \(componentName), Error: \(error.localizedDescription)")
            logger.error("❌ [INIT] Error type: \(type(of: error))")
            logger.error("❌ [INIT] Error details: \(String(describing: error))")
            sessionState = .error("Failed to initialize \(componentName)")
            currentStatus = "Error"
            errorMessage = "Failed to initialize \(componentName): \(error.localizedDescription)"

        case .allComponentsInitialized:
            currentStatus = "All components ready"
            logger.info("✅ [INIT] All components initialized successfully")

        default:
            logger.debug("ℹ️ [INIT] Received event: \(String(describing: event))")
            break
        }
    }

    // MARK: - Pipeline Event Handling

    private func handlePipelineEvent(_ event: ModularPipelineEvent) async {
        await MainActor.run {
            switch event {
            case .vadSpeechStart:
                logger.info("🎤 [VAD] Speech detected - Starting to listen")
                sessionState = .listening
                currentStatus = "Listening..."
                isSpeechDetected = true

            case .vadSpeechEnd:
                logger.info("🔇 [VAD] Speech ended - Processing audio")
                isSpeechDetected = false

            case .vadAudioLevel(let level):
                logger.debug("📊 [VAD] Audio level: \(String(format: "%.3f", level))")

            case .sttPartialTranscript(let text):
                currentTranscript = text
                logger.debug("📝 [STT] Partial transcript: '\(text)'")

            case .sttFinalTranscript(let text):
                currentTranscript = text
                sessionState = .processing
                currentStatus = "Thinking..."
                isProcessing = true
                logger.info("✅ [STT] Final transcript: '\(text)' (length: \(text.count) chars)")

            case .sttLanguageDetected(let language):
                logger.info("🌐 [STT] Language detected: \(language)")

            case .llmThinking:
                logger.info("🤔 [LLM] Thinking mode started")
                sessionState = .processing
                currentStatus = "Thinking..."
                assistantResponse = ""

            case .llmPartialResponse(let text):
                assistantResponse = text
                logger.debug("💭 [LLM] Partial response: '\(text.prefix(50))...' (length: \(text.count) chars)")

            case .llmFinalResponse(let text):
                assistantResponse = text
                sessionState = .speaking
                currentStatus = "Speaking..."
                logger.info("✅ [LLM] Final response: '\(text.prefix(100))...' (length: \(text.count) chars)")

            case .llmStreamStarted:
                logger.info("🔄 [LLM] Streaming started")

            case .llmStreamToken(let token):
                logger.debug("🔤 [LLM] Stream token: '\(token)'")

            case .ttsStarted:
                logger.info("🔊 [TTS] TTS started - Speaking response")
                sessionState = .speaking
                currentStatus = "Speaking..."

            case .ttsAudioChunk(let data):
                logger.debug("🔊 [TTS] Audio chunk received - Size: \(data.count) bytes")

            case .ttsCompleted:
                logger.info("✅ [TTS] TTS completed - Ready for next interaction")
                sessionState = .listening
                currentStatus = "Listening..."
                isProcessing = false
                // Clear transcript for next interaction
                currentTranscript = ""

            case .pipelineError(let error):
                logger.error("❌ [PIPELINE] Pipeline error - Error: \(error.localizedDescription)")
                logger.error("❌ [PIPELINE] Error type: \(type(of: error))")
                logger.error("❌ [PIPELINE] Error details: \(String(describing: error))")
                errorMessage = error.localizedDescription
                sessionState = .error(error.localizedDescription)
                isProcessing = false
                isListening = false

            case .pipelineStarted:
                logger.info("▶️ [PIPELINE] Pipeline started processing")

            case .pipelineCompleted:
                logger.info("✅ [PIPELINE] Pipeline completed")

            default:
                logger.debug("ℹ️ [PIPELINE] Received event: \(String(describing: event))")
                break
            }
        }
    }

    // MARK: - Legacy Compatibility Methods

    func startRecording() async throws {
        await startConversation()
    }

    func stopRecordingAndProcess() async throws -> VoicePipelineResult {
        await stopConversation()

        // Return a mock result for compatibility
        return VoicePipelineResult(
            transcription: STTResult(
                text: currentTranscript,
                language: "en",
                confidence: 0.95,
                duration: 0
            ),
            llmResponse: assistantResponse,
            audioOutput: nil,
            processingTime: 0,
            stageTiming: [:]
        )
    }

    func speakResponse(_ text: String) async {
        logger.info("Speaking response: '\(text, privacy: .public)'")
        // TTS is now handled by the pipeline
    }
}

// MARK: - VoicePipelineManagerDelegate

// Delegate no longer needed - ModularVoicePipeline uses events
/*
extension VoiceAssistantViewModel: @preconcurrency ModularPipelineDelegate {
    nonisolated func pipeline(_ pipeline: ModularVoicePipeline, didReceiveEvent event: ModularPipelineEvent) {
        Task { @MainActor in
            await handlePipelineEvent(event)
        }
    }

    nonisolated func pipeline(_ pipeline: ModularVoicePipeline, didEncounterError error: Error) {
        Task { @MainActor in

            errorMessage = error.localizedDescription
            sessionState = .error(error.localizedDescription)
            isListening = false
            isProcessing = false
            logger.error("Pipeline error: \(error)")
        }
    }K
}
*/
