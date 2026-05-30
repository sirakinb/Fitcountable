import SwiftUI
import UIKit

struct CommandBar: View {
    @EnvironmentObject private var appState: AppState
    @State private var text = ""
    @FocusState private var isCommandFieldFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.fitGreen)
                TextField("Tell Fitcountable what to log...", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .focused($isCommandFieldFocused)
                Button {
                    appState.selectedTab = .ai
                    appState.isVoicePromptActive = true
                    appState.commandProcessingMessage = "Tap the keyboard mic or type your log, then send."
                    appState.aiInputFocusRequest = UUID()
                } label: {
                    Image(systemName: appState.isVoicePromptActive ? "mic.circle.fill" : "mic.circle")
                        .font(.title2)
                }
                Button {
                    Task {
                        let command = text
                        guard command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                        appState.selectedTab = .ai
                        appState.isVoicePromptActive = false
                        appState.deepgramVoiceService.stop()
                        await appState.submitCommand(command)
                        text = ""
                    }
                } label: {
                    Image(systemName: appState.isProcessingCommand ? "clock.arrow.circlepath" : "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(appState.isProcessingCommand)
            }
            .padding(12)
            .background(Color.fitCard, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .onChange(of: appState.aiInputFocusRequest) { _, _ in
                isCommandFieldFocused = true
            }
            .onAppear {
                if appState.isVoicePromptActive {
                    isCommandFieldFocused = true
                }
            }

            if let message = appState.commandProcessingMessage {
                HStack(spacing: 8) {
                    if appState.isVoicePromptActive {
                        Image(systemName: "mic.fill")
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(message)
                        .font(.footnote.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(Color.fitGreen)
                .padding(.horizontal, 4)
            }

            if appState.isVoicePromptActive {
                HStack(alignment: .top, spacing: 10) {
                    Text(appState.voiceRecorderService.isRecording
                         ? "Listening. Release the center button when you finish speaking."
                         : "Tip: tap the microphone on the iOS keyboard, say something like \"log grilled chicken and rice for lunch,\" then send it here.")
                        .font(.footnote)
                        .foregroundStyle(Color.fitMuted)
                    Spacer()
                    Button("Done") {
                        isCommandFieldFocused = false
                        appState.isVoicePromptActive = false
                        appState.deepgramVoiceService.stop()
                        appState.commandProcessingMessage = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.fitGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Clear") {
                    text = ""
                    appState.isVoicePromptActive = false
                    appState.commandProcessingMessage = nil
                    isCommandFieldFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                Spacer()
                Button("Done") {
                    isCommandFieldFocused = false
                    appState.isVoicePromptActive = false
                    appState.deepgramVoiceService.stop()
                    appState.commandProcessingMessage = nil
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
