import AVFoundation
import Foundation

@MainActor
final class DeepgramVoiceService: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var statusMessage: String?

    private let audioEngine = AVAudioEngine()
    private let sendQueue = DispatchQueue(label: "com.fitcountable.deepgram.audio-send", qos: .userInitiated)
    private var webSocket: URLSessionWebSocketTask?
    private var hasInstalledTap = false
    private var sampleRate = 48_000

    func start(accessToken: String) async -> Bool {
        #if targetEnvironment(simulator)
        statusMessage = "Live voice works on a real iPhone. In Simulator, type or use keyboard dictation."
        return false
        #endif

        if isRecording { return true }
        transcript = ""
        statusMessage = "Listening..."

        let microphoneAllowed = await requestMicrophonePermission()
        guard microphoneAllowed else {
            statusMessage = "Turn on Microphone access in Settings to use voice logging."
            return false
        }

        stop()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Microphone setup failed. Try again."
            return false
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            statusMessage = "Microphone input is unavailable right now."
            return false
        }
        sampleRate = Int(format.sampleRate.rounded())

        guard let url = deepgramURL(sampleRate: sampleRate) else {
            statusMessage = "Voice logging is unavailable right now."
            return false
        }
        var request = URLRequest(url: url)
        request.setValue("Token \(accessToken)", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        webSocket = socket
        socket.resume()
        receiveLoop(socket)

        let audioSendQueue = sendQueue
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            guard let data = Self.linearPCMData(from: buffer) else { return }
            audioSendQueue.async {
                socket.send(.data(data)) { _ in }
            }
        }
        hasInstalledTap = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            return true
        } catch {
            statusMessage = "Recording failed to start. Try again."
            stop()
            return false
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        let socket = webSocket
        sendQueue.async {
            socket?.send(.string("{\"type\":\"CloseStream\"}")) { _ in }
            socket?.cancel(with: .normalClosure, reason: nil)
        }
        webSocket = nil
        isRecording = false
        statusMessage = transcript.isEmpty ? statusMessage : nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal; the next recording attempt will reactivate the session.
        }
    }

    private func deepgramURL(sampleRate: Int) -> URL? {
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")
        components?.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "\(sampleRate)"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "endpointing", value: "300")
        ]
        return components?.url
    }

    private func receiveLoop(_ socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.webSocket === socket else { return }
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.receiveLoop(socket)
                case .failure:
                    if self.isRecording {
                        self.statusMessage = "Voice connection stopped. Try again or type your log."
                    }
                    self.stop()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(DeepgramTranscriptResponse.self, from: data),
              let transcript = response.channel.alternatives.first?.transcript,
              transcript.isEmpty == false else {
            return
        }
        self.transcript = transcript
        statusMessage = response.isFinal ? nil : "Listening..."
    }

    private static func linearPCMData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let frameLength = Int(buffer.frameLength)
        var data = Data(capacity: frameLength * MemoryLayout<Int16>.size)

        for frame in 0..<frameLength {
            let sample = max(-1, min(1, channel[frame]))
            var intSample = Int16(sample * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &intSample) { data.append(contentsOf: $0) }
        }

        return data
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}

private struct DeepgramTranscriptResponse: Decodable {
    var isFinal: Bool
    var channel: DeepgramChannel

    enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case channel
    }
}

private struct DeepgramChannel: Decodable {
    var alternatives: [DeepgramAlternative]
}

private struct DeepgramAlternative: Decodable {
    var transcript: String
}
