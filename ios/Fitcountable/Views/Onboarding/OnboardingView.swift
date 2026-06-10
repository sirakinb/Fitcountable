import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0
    @State private var goal: GoalType = .recomp
    @State private var accountability = true
    @State private var weeklyWorkouts = 4.0
    @State private var nutritionStyle = "Balanced"
    @State private var calories = 2450
    @State private var protein = 185
    @State private var carbs = 260
    @State private var fat = 75

    private let totalSteps = 7

    init() {
        let screenshotScreen = ProcessInfo.processInfo.environment["FITCOUNTABLE_SCREENSHOT"]
        _step = State(initialValue: screenshotScreen == "onboarding" ? 6 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(.fitGreen)
                .padding(.horizontal)
                .padding(.top, 14)
                .padding(.bottom, 10)

            currentStep
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack {
                if step > 0 {
                    Button {
                        step -= 1
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.headline)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(Color.fitGreen.opacity(0.13), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.fitGreen)
                }
                PrimaryButton(title: step == totalSteps - 1 ? "Enter Fitcountable" : "Continue", systemImage: "arrow.right") {
                    if step == totalSteps - 1 {
                        appState.updateGoal(GoalPlan(
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            weeklyWorkouts: Int(weeklyWorkouts),
                            targetPace: nutritionStyle
                        ))
                        appState.completeOnboarding(
                            goalType: goal,
                            weeklyWorkouts: Int(weeklyWorkouts),
                            accountability: accountability
                        )
                    } else {
                        step += 1
                    }
                }
                .disabled(shouldDisablePrimaryButton)
                .opacity(shouldDisablePrimaryButton ? 0.45 : 1)
            }
            .padding()
            .background(Color.fitSurface)
        }
        .background(Color.fitSurface.ignoresSafeArea())
        .onAppear {
            appState.trackOnboardingStarted()
        }
        .onChange(of: appState.authSession?.userId) { _, userId in
            guard step == 5, userId != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                step = 6
            }
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case 0: welcome
        case 1: goalStep
        case 2: trainingStep
        case 3: nutritionStep
        case 4: accountabilityStep
        case 5: signIn
        default: planReveal
        }
    }

    private var shouldDisablePrimaryButton: Bool {
        step == 5 && appState.authSession == nil
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image("MascotIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: Color.fitGreen.opacity(0.22), radius: 24, y: 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                VStack(alignment: .leading, spacing: 18) {
                    Text("AI-NATIVE FITNESS ACCOUNTABILITY")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.fitBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Log workouts and meals by saying what happened.")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Fitcountable turns natural language into editable workout, nutrition, and accountability records.")
                        .font(.title3)
                        .foregroundStyle(Color.fitMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingPanel(
                eyebrow: "Secure account",
                title: "Save your plan with Apple.",
                description: "Sign in to keep your logs, goals, friends, proof, and premium access connected to your private Fitcountable account.",
                systemImage: "apple.logo"
            )
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        appState.recordAppleSignIn(
                            userIdentifier: credential.user,
                            email: credential.email,
                            identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) },
                            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                        )
                    }
                case .failure(let error):
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        appState.authStatusMessage = "Apple sign-in didn't finish. Please try again."
                    }
                }
            }
                .frame(height: 52)
                .cornerRadius(8)
                .disabled(appState.isSigningInWithApple)
            HStack(spacing: 10) {
                if appState.isSigningInWithApple {
                    ProgressView()
                        .tint(Color.fitGreen)
                }
                Text(appState.authStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(appState.authSession == nil ? Color.fitMuted : Color.fitGreen)
            }
        }
        .padding(24)
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's the main goal?")
                .font(.largeTitle.bold())
            ForEach(GoalType.allCases) { option in
                Button {
                    goal = option
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.rawValue)
                                .font(.headline)
                            Text(goalDetail(for: option))
                                .font(.subheadline)
                                .foregroundStyle(Color.fitMuted)
                        }
                        Spacer()
                        Image(systemName: goal == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(goal == option ? Color.fitGreen : Color.fitMuted)
                    }
                    .padding()
                    .background(goal == option ? Color.fitGreen.opacity(0.16) : Color.fitCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(goal == option ? Color.fitGreen : Color.fitBorder, lineWidth: goal == option ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }

    private var trainingStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            WeeklyTargetPhoto()
                .frame(height: 150)
            Text("Build the weekly target.")
                .font(.largeTitle.bold())
            Text("Fitcountable uses this to score consistency and create accountability prompts.")
                .foregroundStyle(Color.fitMuted)
            Stepper("Gym sessions per week: \(Int(weeklyWorkouts))", value: $weeklyWorkouts, in: 1...7)
                .font(.headline)
                .padding()
                .fitCardSurface()
            MetricCard(title: "Starting plan", value: "\(Int(weeklyWorkouts)) workouts", detail: planDetail(for: goal), color: .fitBlue)
        }
        .padding(24)
    }

    private var nutritionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Nutrition tracking style")
                    .font(.largeTitle.bold())
                Text("Choose a starting style now. You can edit exact targets anytime from Profile.")
                    .foregroundStyle(Color.fitMuted)
                Picker("Style", selection: $nutritionStyle) {
                    Text("Balanced").tag("Balanced")
                    Text("High protein").tag("High protein")
                    Text("Lower carb").tag("Lower carb")
                }
                .pickerStyle(.segmented)
                .onChange(of: nutritionStyle) { _, style in
                    applyNutritionStyle(style)
                }
                VStack(spacing: 12) {
                    Stepper("Calories: \(calories)", value: $calories, in: 1200...5000, step: 25)
                    Stepper("Protein: \(protein)g", value: $protein, in: 50...320, step: 5)
                    Stepper("Carbs: \(carbs)g", value: $carbs, in: 25...600, step: 5)
                    Stepper("Fat: \(fat)g", value: $fat, in: 20...220, step: 5)
                }
                .font(.headline)
                .padding()
                .fitCardSurface()
                Text("Nutrition estimates are informational and should be reviewed before saving.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitMuted)
            }
            .padding(24)
        }
    }

    private var accountabilityStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccountabilityPhoto()
                .frame(height: 170)
            Text("Accountability mode")
                .font(.largeTitle.bold())
            Toggle("Let selected friends see consistency and proof posts", isOn: $accountability)
                .font(.headline)
                .padding()
                .fitCardSurface()
            Text("New accounts start private. Sharing is opt-in and can be changed later.")
                .foregroundStyle(Color.fitMuted)
        }
        .padding(24)
    }

    private var planReveal: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your starting plan is ready.")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Image("MascotIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.rawValue)
                            .font(.headline)
                        Text(planDetail(for: goal))
                            .font(.subheadline)
                            .foregroundStyle(Color.fitMuted)
                    }
                }
                .padding()
                .fitCardSurface()
                HStack {
                    MetricCard(title: "Calories", value: "\(calories)", detail: "per day", color: .fitGreen)
                    MetricCard(title: "Training", value: "\(Int(weeklyWorkouts))x", detail: "per week", color: .fitBlue)
                }
                HStack {
                    MetricCard(title: "Protein", value: "\(protein)g", detail: "per day", color: .orange)
                    MetricCard(title: "Sharing", value: accountability ? "On" : "Off", detail: "change anytime", color: .teal)
                }
                Text(appState.authSession == nil ? "Sign in with Apple before entering Fitcountable so your logs and proof stay saved." : "Your account is ready. Premium stays optional and can be managed from Profile.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitMuted)
            }
            .padding(24)
        }
    }

    private func goalDetail(for option: GoalType) -> String {
        switch option {
        case .loseFat: "Track calories while keeping protein high."
        case .buildMuscle: "Prioritize progressive workouts and surplus habits."
        case .maintain: "Keep meals and training consistent."
        case .recomp: "Balance strength progress with macro targets."
        case .consistency: "Use proof, streaks, and friends to show up."
        }
    }

    private func applyNutritionStyle(_ style: String) {
        switch style {
        case "High protein":
            protein = 205
            carbs = 230
            fat = 70
        case "Lower carb":
            protein = 190
            carbs = 175
            fat = 95
        default:
            protein = 185
            carbs = 260
            fat = 75
        }
    }

    private func planDetail(for option: GoalType) -> String {
        switch option {
        case .loseFat: "Calorie-aware routine"
        case .buildMuscle: "Progressive overload routine"
        case .maintain: "Consistency maintenance routine"
        case .recomp: "Strength and macro balance"
        case .consistency: "Accountability-first routine"
        }
    }
}

struct OnboardingPanel: View {
    var eyebrow: String
    var title: String
    var description: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(Color.fitGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.fitBlue)
            Text(title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(description)
                .font(.title3)
                .foregroundStyle(Color.fitMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WarmAccountabilityIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.fitGreen.opacity(0.16), Color.fitBlue.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 28) {
                accountabilityPerson(
                    skin: Color(red: 0.55, green: 0.31, blue: 0.18),
                    shirt: Color.fitBlue,
                    hair: Color(red: 0.08, green: 0.06, blue: 0.05)
                )
                handshake
                    .frame(width: 96, height: 70)
                accountabilityPerson(
                    skin: Color(red: 0.68, green: 0.42, blue: 0.24),
                    shirt: Color.fitGreen,
                    hair: Color(red: 0.11, green: 0.07, blue: 0.04)
                )
            }
            .padding(.horizontal, 24)

            VStack {
                Spacer()
                HStack {
                    Label("Proof", systemImage: "checkmark.seal.fill")
                    Spacer()
                    Label("Nudges", systemImage: "bell.badge.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.fitInk.opacity(0.72))
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func accountabilityPerson(skin: Color, shirt: Color, hair: Color) -> some View {
        VStack(spacing: -4) {
            ZStack {
                Circle()
                    .fill(skin)
                    .frame(width: 58, height: 58)
                Circle()
                    .fill(hair)
                    .frame(width: 58, height: 28)
                    .offset(y: -18)
                    .clipShape(Circle())
                HStack(spacing: 14) {
                    Circle().fill(.white).frame(width: 6, height: 6)
                    Circle().fill(.white).frame(width: 6, height: 6)
                }
                .offset(y: 4)
                Capsule()
                    .fill(Color.fitInk.opacity(0.55))
                    .frame(width: 18, height: 4)
                    .offset(y: 18)
            }
            RoundedRectangle(cornerRadius: 22)
                .fill(shirt)
                .frame(width: 74, height: 62)
                .overlay(
                    Image(systemName: "bolt.heart.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                )
        }
    }

    private var handshake: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.55, green: 0.31, blue: 0.18))
                .frame(width: 62, height: 22)
                .rotationEffect(.degrees(-18))
                .offset(x: -18, y: 0)
            Capsule()
                .fill(Color(red: 0.68, green: 0.42, blue: 0.24))
                .frame(width: 62, height: 22)
                .rotationEffect(.degrees(18))
                .offset(x: 18, y: 0)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.61, green: 0.36, blue: 0.21))
                .frame(width: 42, height: 30)
            Image(systemName: "checkmark")
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
    }
}

struct AccountabilityPhoto: View {
    var body: some View {
        Image("AccountabilityHero")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}

struct WeeklyTargetPhoto: View {
    var body: some View {
        Image("WeeklyTargetHero")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}
