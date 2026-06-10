import AVFoundation
import Foundation

@MainActor
final class VoiceRecorderService: ObservableObject {
    @Published var isRecording = false
    @Published var statusMessage: String?

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    var permissionState: AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    func start() async -> Bool {
        #if targetEnvironment(simulator)
        statusMessage = "Voice recording works on a real iPhone. In Simulator, type your log or use keyboard dictation."
        return false
        #else
        return await startOnDevice()
        #endif
    }

    /// Returns true only when permission is already granted. When undetermined,
    /// it shows the system prompt and returns false so callers never try to
    /// record while the TCC alert has interrupted the user's hold gesture.
    func ensureMicrophonePermission() async -> MicrophonePermissionOutcome {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            let allowed = await AVAudioApplication.requestRecordPermission()
            return allowed ? .justGranted : .denied
        @unknown default:
            let allowed = await AVAudioApplication.requestRecordPermission()
            return allowed ? .justGranted : .denied
        }
    }

    private func startOnDevice() async -> Bool {
        if isRecording { return true }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            statusMessage = "Turn on Microphone access in Settings to use voice logging."
            return false
        }

        _ = stop()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
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
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record() else {
                statusMessage = "Recording failed to start. Try again."
                _ = stop()
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
}

enum MicrophonePermissionOutcome {
    case granted
    case justGranted
    case denied
}
