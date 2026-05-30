import AVFoundation
import Foundation

@MainActor
final class VoiceRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var statusMessage: String?

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func start() async -> Bool {
        #if targetEnvironment(simulator)
        statusMessage = "Voice recording works on a real iPhone. In Simulator, type your log or use keyboard dictation."
        return false
        #else
        return await startOnDevice()
        #endif
    }

    private func startOnDevice() async -> Bool {
        if isRecording { return true }

        let microphoneAllowed = await requestMicrophonePermission()
        guard microphoneAllowed else {
            statusMessage = "Turn on Microphone access in Settings to use voice logging."
            return false
        }

        _ = stop()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("fitcountable-voice-\(UUID().uuidString)")
                .appendingPathExtension("wav")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else {
                statusMessage = "Recording failed to start. Try again."
                return false
            }

            self.recorder = recorder
            recordingURL = url
            isRecording = true
            statusMessage = "Listening..."
            return true
        } catch {
            statusMessage = "Microphone setup failed. Try again."
            _ = stop()
            return false
        }
    }

    func stop() -> URL? {
        let url = recordingURL
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        recorder = nil
        recordingURL = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal; the next recording attempt will reactivate the session.
        }

        return url
    }

    func discard(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}
