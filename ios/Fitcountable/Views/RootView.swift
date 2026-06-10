import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingSplash = ProcessInfo.processInfo.environment["FITCOUNTABLE_SCREENSHOT"] == nil
    @State private var splashDismissTask: Task<Void, Never>?
    @State private var didTrackOpen = false

    var body: some View {
        Group {
            if showingSplash {
                SplashView()
            } else if appState.hasCompletedOnboarding && appState.authSession != nil {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(.fitGreen)
        .background(Color.fitSurface.ignoresSafeArea())
        .onAppear {
            scheduleSplashDismissal()
            if didTrackOpen == false {
                didTrackOpen = true
                appState.trackAppOpened()
            }
        }
        .onDisappear {
            splashDismissTask?.cancel()
        }
    }

    private func scheduleSplashDismissal() {
        guard showingSplash else { return }
        splashDismissTask?.cancel()
        splashDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard Task.isCancelled == false else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                showingSplash = false
            }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.fitMist, Color.fitSurface], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image("MascotIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.fitGreen.opacity(0.24), radius: 28, y: 14)
                Text("Fitcountable")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                ProgressView()
                    .tint(.fitGreen)
                    .padding(.top, 4)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isPressingVoiceButton = false
    @State private var didStartVoiceHold = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                TodayView()
                    .tabItem { Label(AppTab.today.rawValue, systemImage: AppTab.today.systemImage) }
                    .tag(AppTab.today)
                LogView()
                    .tabItem { Label(AppTab.log.rawValue, systemImage: AppTab.log.systemImage) }
                    .tag(AppTab.log)
                AICommandCenterView()
                    .tabItem {
                        EmptyView()
                    }
                    .tag(AppTab.ai)
                SocialView()
                    .tabItem { Label(AppTab.social.rawValue, systemImage: AppTab.social.systemImage) }
                    .tag(AppTab.social)
                ProfileView()
                    .tabItem { Label(AppTab.profile.rawValue, systemImage: AppTab.profile.systemImage) }
                    .tag(AppTab.profile)
            }

            VStack {
                Spacer()
                CenterVoiceTabButton(
                    isRecording: appState.isVoicePromptActive,
                    isPrimed: isPressingVoiceButton && didStartVoiceHold == false
                )
                .accessibilityLabel("AI voice log")
                .gesture(voiceGesture)
                .padding(.bottom, 26)
            }
            .ignoresSafeArea(.keyboard)
            .zIndex(2)
        }
    }

    private var voiceGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard isPressingVoiceButton == false else { return }
                isPressingVoiceButton = true
                didStartVoiceHold = false
                holdTask?.cancel()
                holdTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    guard Task.isCancelled == false else { return }
                    guard isPressingVoiceButton else { return }
                    didStartVoiceHold = true
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    await appState.startVoiceHold()
                }
            }
            .onEnded { _ in
                holdTask?.cancel()
                holdTask = nil
                isPressingVoiceButton = false
                if didStartVoiceHold {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    appState.finishVoiceHold()
                } else {
                    appState.openAI()
                }
                didStartVoiceHold = false
            }
    }
}

private struct CenterVoiceTabButton: View {
    var isRecording: Bool
    var isPrimed: Bool

    var body: some View {
        ZStack {
            if isRecording {
                Circle()
                    .stroke(Color.red.opacity(0.28), lineWidth: 10)
                    .frame(width: 84, height: 84)
                    .scaleEffect(1.08)
                    .transition(.opacity)
            }
            Circle()
                .fill(isRecording ? Color.red : Color.fitGreen)
                .shadow(color: (isRecording ? Color.red : Color.fitGreen).opacity(0.32), radius: 16, y: 7)
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white)
            if isRecording == false {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .offset(x: 18, y: -18)
            }
        }
        .frame(width: 66, height: 66)
        .overlay(
            Circle()
                .stroke(.white, lineWidth: 5)
        )
        .overlay(alignment: .top) {
            if isRecording {
                Text("Dictate")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red, in: Capsule())
                    .offset(y: -32)
                    .transition(.opacity.combined(with: .scale))
            }
        }
            .scaleEffect(isPrimed || isRecording ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isPrimed)
            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isRecording)
    }
}
