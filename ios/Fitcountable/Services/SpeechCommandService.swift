import Foundation
import AVFoundation
import Speech

@MainActor
final class SpeechCommandService: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    @Published var statusMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledTap = false
    private var isStopping = false

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.authorizationStatus = status
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task { await startRecording() }
        }
    }

    @discardableResult
    func startRecording() async -> Bool {
        #if targetEnvironment(simulator)
        statusMessage = "Voice logging is ready on a real iPhone. In Simulator, type a meal or workout and tap send."
        isRecording = false
        return false
        #endif

        if isRecording { return true }
        isStopping = false
        statusMessage = nil

        if authorizationStatus == .notDetermined {
            authorizationStatus = await requestAuthorization()
        }

        switch authorizationStatus {
        case .denied, .restricted:
            statusMessage = "Turn on Speech Recognition in Settings to use voice logging."
            return false
        case .authorized:
            break
        case .notDetermined:
            statusMessage = "Allow speech recognition, then hold the microphone again."
            return false
        @unknown default:
            statusMessage = "Speech recognition is unavailable right now."
            return false
        }

        let microphoneAllowed = await requestMicrophonePermission()
        guard microphoneAllowed else {
            statusMessage = "Turn on Microphone access in Settings to use voice logging."
            return false
        }

        guard recognizer?.isAvailable == true else {
            statusMessage = "Voice logging is unavailable right now. You can still type your log."
            return false
        }

        transcript = ""
        statusMessage = "Listening..."
        cleanupAudio()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Microphone setup failed. Try again."
            cleanupAudio()
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            statusMessage = "Microphone input is unavailable right now."
            cleanupAudio()
            return false
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        hasInstalledTap = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            statusMessage = "Recording failed to start. Try again."
            cleanupAudio()
            return false
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if result?.isFinal == true {
                    self.stopRecording()
                } else if error != nil, self.transcript.isEmpty {
                    self.statusMessage = "Voice logging stopped. Try again or type your log."
                    self.stopRecording()
                }
            }
        }

        return true
    }

    func stopRecording() {
        guard isStopping == false else { return }
        isStopping = true

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        statusMessage = transcript.isEmpty ? statusMessage : nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal; the next recording attempt will reactivate the session.
        }
        isStopping = false
    }

    private func cleanupAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}
