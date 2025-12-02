//
//  VoiceModelSelectionStore.swift
//  RunAnywhereAI
//
//  Persistent storage for voice assistant model selections
//

import Foundation
import RunAnywhere
import Combine

/// Persists voice model selections across app launches
@MainActor
final class VoiceModelSelectionStore: ObservableObject {
    static let shared = VoiceModelSelectionStore()

    // MARK: - Published Properties

    @Published var sttModel: (framework: LLMFramework, name: String, id: String)? {
        didSet {
            saveSTTModel()
        }
    }

    @Published var llmModel: (framework: LLMFramework, name: String, id: String)? {
        didSet {
            saveLLMModel()
        }
    }

    @Published var ttsModel: (framework: LLMFramework, name: String, id: String)? {
        didSet {
            saveTTSModel()
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let sttFramework = "voiceAssistant.stt.framework"
        static let sttName = "voiceAssistant.stt.name"
        static let sttId = "voiceAssistant.stt.id"

        static let llmFramework = "voiceAssistant.llm.framework"
        static let llmName = "voiceAssistant.llm.name"
        static let llmId = "voiceAssistant.llm.id"

        static let ttsFramework = "voiceAssistant.tts.framework"
        static let ttsName = "voiceAssistant.tts.name"
        static let ttsId = "voiceAssistant.tts.id"
    }

    private let defaults = UserDefaults.standard

    private init() {
        loadSavedSelections()
    }

    // MARK: - Load Saved Selections

    private func loadSavedSelections() {
        // Load STT model
        if let frameworkRaw = defaults.string(forKey: Keys.sttFramework),
           let framework = LLMFramework(rawValue: frameworkRaw),
           let name = defaults.string(forKey: Keys.sttName),
           let id = defaults.string(forKey: Keys.sttId) {
            sttModel = (framework: framework, name: name, id: id)
        }

        // Load LLM model
        if let frameworkRaw = defaults.string(forKey: Keys.llmFramework),
           let framework = LLMFramework(rawValue: frameworkRaw),
           let name = defaults.string(forKey: Keys.llmName),
           let id = defaults.string(forKey: Keys.llmId) {
            llmModel = (framework: framework, name: name, id: id)
        }

        // Load TTS model
        if let frameworkRaw = defaults.string(forKey: Keys.ttsFramework),
           let framework = LLMFramework(rawValue: frameworkRaw),
           let name = defaults.string(forKey: Keys.ttsName),
           let id = defaults.string(forKey: Keys.ttsId) {
            ttsModel = (framework: framework, name: name, id: id)
        }
    }

    // MARK: - Save Methods

    private func saveSTTModel() {
        if let model = sttModel {
            defaults.set(model.framework.rawValue, forKey: Keys.sttFramework)
            defaults.set(model.name, forKey: Keys.sttName)
            defaults.set(model.id, forKey: Keys.sttId)
        } else {
            defaults.removeObject(forKey: Keys.sttFramework)
            defaults.removeObject(forKey: Keys.sttName)
            defaults.removeObject(forKey: Keys.sttId)
        }
    }

    private func saveLLMModel() {
        if let model = llmModel {
            defaults.set(model.framework.rawValue, forKey: Keys.llmFramework)
            defaults.set(model.name, forKey: Keys.llmName)
            defaults.set(model.id, forKey: Keys.llmId)
        } else {
            defaults.removeObject(forKey: Keys.llmFramework)
            defaults.removeObject(forKey: Keys.llmName)
            defaults.removeObject(forKey: Keys.llmId)
        }
    }

    private func saveTTSModel() {
        if let model = ttsModel {
            defaults.set(model.framework.rawValue, forKey: Keys.ttsFramework)
            defaults.set(model.name, forKey: Keys.ttsName)
            defaults.set(model.id, forKey: Keys.ttsId)
        } else {
            defaults.removeObject(forKey: Keys.ttsFramework)
            defaults.removeObject(forKey: Keys.ttsName)
            defaults.removeObject(forKey: Keys.ttsId)
        }
    }

    // MARK: - Clear Methods

    func clearAll() {
        sttModel = nil
        llmModel = nil
        ttsModel = nil
    }

    func clearSTT() {
        sttModel = nil
    }

    func clearLLM() {
        llmModel = nil
    }

    func clearTTS() {
        ttsModel = nil
    }
}
