import AuthenticationServices
import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var calories = 2450
    @State private var protein = 185
    @State private var carbs = 260
    @State private var fat = 75
    @State private var weeklyWorkouts = 4
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var showingPremium = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileHeader
                    goals
                    goalEditor
                    paywall
                    account
                    support
                }
                .padding()
                .padding(.bottom, 52)
            }
            .background(Color.fitSurface.ignoresSafeArea())
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showingPremium) {
            PremiumUpgradeView()
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Delete Fitcountable account?",
            isPresented: $showingDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    await appState.deleteAccount()
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your Fitcountable profile, logs, friends, proof posts, and synced app data. App Store purchases remain managed by Apple.")
        }
        .onAppear {
            calories = appState.goal.calories
            protein = appState.goal.protein
            carbs = appState.goal.carbs
            fat = appState.goal.fat
            weeklyWorkouts = appState.goal.weeklyWorkouts
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ProfilePhotoView(imageData: appState.profilePhotoData, fallback: appState.profile.displayName, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.profile.displayName)
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                    Text("\(appState.profile.goalType.rawValue) • \(appState.profile.trainingExperience)")
                        .foregroundStyle(Color.fitMuted)
                    PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                        Label(appState.profilePhotoData == nil ? "Choose profile photo" : "Change profile photo", systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(.fitBlue)
                }
            }
            .onChange(of: selectedProfilePhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    appState.updateProfilePhoto(compressedProfileImage(data))
                }
            }
            Text(authStatusText)
                .font(.footnote)
                .foregroundStyle(appState.authSession == nil ? .orange : Color.fitGreen)
            if appState.authSession == nil {
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
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(appState.isSigningInWithApple)
            }
            Picker("Privacy", selection: Binding(
                get: { appState.profile.privacyMode },
                set: { appState.updatePrivacyMode($0) }
            )) {
                ForEach(PrivacyMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(privacyDescription(appState.profile.privacyMode))
                .font(.footnote)
                .foregroundStyle(Color.fitMuted)
        }
        .padding()
        .fitCardSurface()
    }

    private func compressedProfileImage(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2, width: side, height: side)
        guard let cgImage = image.cgImage?.cropping(to: crop) else {
            return image.jpegData(compressionQuality: 0.72) ?? data
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72) ?? data
    }

    private var authStatusText: String {
        guard let session = appState.authSession else {
            return appState.authStatusMessage
        }
        return session.email.localizedCaseInsensitiveContains("@fitcountable.local")
            ? "Signed in with Apple."
            : "Signed in as \(session.email)"
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Goals", action: nil)
            HStack {
                MetricCard(title: "Calories", value: "\(appState.goal.calories)", detail: "daily", color: .fitGreen)
                MetricCard(title: "Workouts", value: "\(appState.goal.weeklyWorkouts)x", detail: "weekly", color: .fitBlue)
            }
        }
    }

    private var goalEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Edit targets", action: nil)
            Stepper("Calories: \(calories)", value: $calories, in: 1200...5000, step: 25)
            Stepper("Protein: \(protein)g", value: $protein, in: 50...320, step: 5)
            Stepper("Carbs: \(carbs)g", value: $carbs, in: 25...600, step: 5)
            Stepper("Fat: \(fat)g", value: $fat, in: 20...220, step: 5)
            Stepper("Workouts: \(weeklyWorkouts)x/week", value: $weeklyWorkouts, in: 1...7)
            PrimaryButton(title: "Save targets", systemImage: "target") {
                appState.updateGoal(GoalPlan(
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    weeklyWorkouts: weeklyWorkouts,
                    targetPace: appState.goal.targetPace
                ))
            }
        }
        .padding()
        .fitCardSurface()
    }

    private var paywall: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image("MascotIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fitcountable Premium")
                        .font(.system(.title3, design: .rounded, weight: .black))
                    Text(appState.isPremium || appState.purchaseService.entitlementActive ? "Premium is active." : "More AI logs, deeper history, and smarter plans.")
                        .font(.subheadline)
                        .foregroundStyle(Color.fitMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.fitMuted)
            }
        }
        .padding()
        .fitCardSurface()
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            showingPremium = true
        }
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.system(.title3, design: .rounded, weight: .bold))
            if let session = appState.authSession {
                Text(session.email.localizedCaseInsensitiveContains("@fitcountable.local") ? "Signed in with Apple." : "Signed in as \(session.email)")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitMuted)
                HStack(spacing: 10) {
                    Button {
                        appState.signOut()
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.fitGreen)

                    Button(role: .destructive) {
                        showingDeleteAccountConfirmation = true
                    } label: {
                        Label(isDeletingAccount ? "Deleting..." : "Delete account", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeletingAccount)
                }
            } else {
                Text("Sign in with Apple to use Fitcountable.")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitMuted)
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
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(appState.isSigningInWithApple)
            }
        }
        .padding()
        .fitCardSurface()
    }

    private var support: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support and policies")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Link(destination: URL(string: "mailto:aki.b@pentridgemedia.com")!) {
                Label("aki.b@pentridgemedia.com", systemImage: "envelope")
            }
            Divider()
            PolicyLink(title: "Privacy Policy", url: "https://fitcountable.vercel.app/privacy")
            PolicyLink(title: "Terms of Use", url: "https://fitcountable.vercel.app/terms")
            PolicyLink(title: "Support Page", url: "https://fitcountable.vercel.app/support")
            Text("Nutrition estimates are informational and not medical advice.")
                .font(.footnote)
                .foregroundStyle(Color.fitMuted)
        }
        .padding()
        .fitCardSurface()
    }

    private func privacyDescription(_ mode: PrivacyMode) -> String {
        switch mode {
        case .privateProfile:
            "Only you can see your profile and proof unless you share a specific post."
        case .friendsOnly:
            "Approved friends can see consistency and proof you mark for friends."
        case .publicProfile:
            "Your public profile can show consistency and proof marked public."
        }
    }
}

private struct PremiumUpgradeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var isPremiumActive: Bool {
        appState.isPremium || appState.purchaseService.entitlementActive
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroHeader

                    VStack(alignment: .leading, spacing: 14) {
                        PremiumBenefit(title: "More voice and text logs", icon: "mic.fill")
                        PremiumBenefit(title: "Smarter training and nutrition plans", icon: "list.bullet.clipboard")
                        PremiumBenefit(title: "Longer progress history", icon: "chart.line.uptrend.xyaxis")
                        PremiumBenefit(title: "More personal accountability nudges", icon: "bell.badge")
                    }
                    .padding(18)
                    .fitCardSurface()

                    if isPremiumActive {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(Color.fitGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Premium is active")
                                    .font(.headline)
                                Text("\(appState.purchaseService.activePlanLabel ?? "Premium") plan · manage in App Store settings")
                                    .font(.footnote)
                                    .foregroundStyle(Color.fitMuted)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.fitGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a plan")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        ForEach(appState.purchaseService.packages, id: \.self) { package in
                            PremiumPlanRow(
                                package: package,
                                isCurrentPlan: appState.purchaseService.isActivePackage(package),
                                canPurchase: appState.purchaseService.hasLoadedStoreProducts && !appState.purchaseService.isActivePackage(package)
                            ) {
                                Task {
                                    appState.trackPremiumPurchaseStarted(package: package)
                                    await appState.purchaseService.purchase(package: package)
                                    await appState.refreshPremiumStatus()
                                    appState.trackPremiumPurchaseFinished(package: package)
                                }
                            }
                        }
                        if appState.purchaseService.isLoadingOfferings && !appState.purchaseService.hasLoadedStoreProducts {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading plans from the App Store...")
                                    .font(.footnote)
                                    .foregroundStyle(Color.fitMuted)
                            }
                            .padding(.top, 2)
                        }
                        if isPremiumActive == false {
                            Button {
                                Task {
                                    appState.trackPremiumRestoreStarted()
                                    await appState.purchaseService.restore()
                                    await appState.refreshPremiumStatus()
                                    appState.trackPremiumRestoreFinished()
                                }
                            } label: {
                                Text("Already upgraded? Restore access")
                                    .font(.footnote.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.fitGreen)
                            .padding(.top, 4)
                        }
                        if let error = appState.purchaseService.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Color.fitMuted)
                        }
                        Text("Subscriptions renew automatically and can be cancelled anytime in App Store settings.")
                            .font(.caption)
                            .foregroundStyle(Color.fitMuted)
                            .padding(.top, 4)
                    }
                }
                .padding()
            }
            .background(Color.fitSurface.ignoresSafeArea())
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            appState.trackPremiumViewed()
            Task {
                await appState.refreshPremiumStatus()
                await appState.purchaseService.loadOfferings()
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Image("MascotIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FITCOUNTABLE")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1.4)
                    Text("Premium")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            Text("Upgrade when you want Fitcountable to coach more of the work — logging stays free.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fitGreen, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.fitGreen.opacity(0.25), radius: 18, y: 8)
    }
}

private struct PremiumPlanRow: View {
    var package: String
    var isCurrentPlan: Bool
    var canPurchase: Bool
    var purchase: () -> Void

    private var planName: String {
        package.components(separatedBy: " $").first ?? package
    }

    private var planPrice: String {
        guard let range = package.range(of: "$") else { return "" }
        return String(package[range.lowerBound...])
    }

    private var billingDetail: String {
        if planName.localizedCaseInsensitiveContains("yearly") { return "Billed once a year · best value" }
        if planName.localizedCaseInsensitiveContains("monthly") { return "Billed monthly · cancel anytime" }
        if planName.localizedCaseInsensitiveContains("lifetime") { return "One-time purchase · yours forever" }
        return "Premium access"
    }

    var body: some View {
        Button(action: purchase) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(planName)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.fitInk)
                    Text(billingDetail)
                        .font(.caption)
                        .foregroundStyle(Color.fitMuted)
                }
                Spacer()
                if isCurrentPlan {
                    Text("Current plan")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(Color.fitGreen)
                        .background(Color.fitGreen.opacity(0.14), in: Capsule())
                } else {
                    Text(planPrice)
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .foregroundStyle(Color.fitInk)
                }
            }
            .padding(16)
            .background(Color.fitCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCurrentPlan ? Color.fitGreen : Color.fitBorder, lineWidth: isCurrentPlan ? 2 : 1)
            )
        }
        .buttonStyle(FitPressableButtonStyle())
        .disabled(!canPurchase)
        .opacity(canPurchase || isCurrentPlan ? 1 : 0.6)
    }
}

private struct PremiumBenefit: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.fitGreen)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
    }
}

private struct PolicyLink: View {
    var title: String
    var url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
            }
            .padding(.vertical, 3)
        }
    }
}
