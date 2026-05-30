import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var selectedTab: AppTab = .today
    @Published var profile = UserProfile.sample
    @Published var profilePhotoData: Data?
    @Published var goal = GoalPlan.sample
    @Published var workouts: [WorkoutLog] = []
    @Published var meals: [MealLog] = []
    @Published var commands: [AICommandRecord] = []
    @Published var friends: [FriendProfile] = []
    @Published var isPremium = false
    @Published var accountabilityEnabled = false
    @Published var authSession: AuthSession?
    @Published var authStatusMessage = "Use Sign in with Apple to keep your Fitcountable account connected."
    @Published var lastSyncMessage: String?
    @Published var friendSearchResults: [FriendSearchResult] = []
    @Published var incomingFriendRequests: [FriendSearchResult] = []
    @Published var outgoingFriendRequests: [FriendSearchResult] = []
    @Published var proofPosts: [SocialProofPost] = []
    @Published var proofMediaData: [String: Data] = [:]
    @Published var selectedSocialProfile: SocialProfileView?
    @Published var socialStatusMessage: String?
    @Published var isProcessingCommand = false
    @Published var commandProcessingMessage: String?
    @Published var preferredLogMode: LogMode = .workout
    @Published var preferredMealType: MealType = .lunch
    @Published var isVoicePromptActive = false
    @Published var aiInputFocusRequest = UUID()

    let apiClient = RemoteFitcountableAPI(
        functionBaseURL: URL(string: "https://hxvc7grj.us-east.insforge.app/functions")!,
        apiBaseURL: URL(string: "https://hxvc7grj.us-east.insforge.app/api")!,
        fallback: LocalMockAPI()
    )
    lazy var deepgramVoiceService = DeepgramVoiceService()
    lazy var voiceRecorderService = VoiceRecorderService()
    let purchaseService = PurchaseService()
    private let snapshotKey = "fitcountable.local.snapshot.v1"
    private var voiceTimeoutTask: Task<Void, Never>?
    private var isVoiceHoldActive = false

    init() {
        if ProcessInfo.processInfo.environment["FITCOUNTABLE_RESET_STATE"] == "1" {
            UserDefaults.standard.removeObject(forKey: snapshotKey)
        }
        if let screenshotScreen = ProcessInfo.processInfo.environment["FITCOUNTABLE_SCREENSHOT"] {
            configureForScreenshot(screen: screenshotScreen)
        } else {
            loadSnapshot()
            Task { await refreshPremiumStatus() }
        }
    }

    var caloriesConsumed: Int {
        meals.reduce(0) { $0 + $1.totalCalories }
    }

    var proteinConsumed: Int {
        meals.reduce(0) { $0 + Int($1.totalProtein.rounded()) }
    }

    var carbsConsumed: Int {
        meals.reduce(0) { $0 + Int($1.totalCarbs.rounded()) }
    }

    var fatConsumed: Int {
        meals.reduce(0) { $0 + Int($1.totalFat.rounded()) }
    }

    var caloriesRemaining: Int {
        max(goal.calories - caloriesConsumed, 0)
    }

    var shouldShowUpgradePrompt: Bool {
        isPremium == false && purchaseService.entitlementActive == false && workouts.count + meals.count >= 2
    }

    var savedFoodItems: [FoodItem] {
        var seen = Set<String>()
        return meals
            .flatMap(\.items)
            .filter { item in
                let key = "\(item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(item.quantityText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
                guard seen.contains(key) == false else { return false }
                seen.insert(key)
                return true
            }
    }

    func submitCommand(_ text: String, currentMealType: MealType? = nil) async {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        let draft = AICommandRecord(rawText: text, status: .parsing)
        commands.insert(draft, at: 0)
        isProcessingCommand = true
        commandProcessingMessage = "Turning that into an editable log..."
        defer {
            isProcessingCommand = commands.contains { record in
                if case .parsing = record.status { true } else { false }
            }
            commandProcessingMessage = isProcessingCommand ? "Turning that into an editable log..." : nil
        }

        do {
            let proposal = try await apiClient.parseCommand(
                text: text,
                context: .init(
                    profile: profile,
                    goal: goal,
                    savedFoods: Array(savedFoodItems.prefix(30)),
                    currentMealType: currentMealType
                )
            )
            if let index = commands.firstIndex(where: { $0.id == draft.id }) {
                commands[index] = AICommandRecord(id: draft.id, rawText: text, status: .ready, proposal: proposal)
            }
        } catch {
            if let index = commands.firstIndex(where: { $0.id == draft.id }) {
                commands[index] = AICommandRecord(id: draft.id, rawText: text, status: .failed(error.localizedDescription))
            }
        }
    }

    func refineCommand(_ command: AICommandRecord, detail: String) async {
        let cleanDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanDetail.isEmpty == false else { return }
        guard commands.contains(where: { $0.id == command.id }) else { return }

        let refinedText = "\(command.rawText). More detail: \(cleanDetail)"
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = AICommandRecord(id: command.id, rawText: refinedText, status: .parsing, proposal: command.proposal)
        }
        isProcessingCommand = true
        commandProcessingMessage = "Updating your draft..."
        defer {
            isProcessingCommand = commands.contains { record in
                if case .parsing = record.status { true } else { false }
            }
            commandProcessingMessage = isProcessingCommand ? "Turning that into an editable log..." : nil
        }

        do {
            let proposal = try await apiClient.parseCommand(text: refinedText, context: .init(profile: profile, goal: goal, savedFoods: Array(savedFoodItems.prefix(30))))
            if let index = commands.firstIndex(where: { $0.id == command.id }) {
                commands[index] = AICommandRecord(id: command.id, rawText: refinedText, status: .ready, proposal: proposal)
            }
        } catch {
            if let index = commands.firstIndex(where: { $0.id == command.id }) {
                commands[index] = AICommandRecord(id: command.id, rawText: refinedText, status: .failed(error.localizedDescription), proposal: command.proposal)
            }
        }
    }

    func signIn(email: String, password: String) async {
        do {
            let session = try await apiClient.signIn(email: email, password: password)
            authSession = session
            apiClient.authToken = session.accessToken
            authStatusMessage = "Signed in as \(session.email). Confirmed logs will sync."
            _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: profile.privacyMode, avatarData: profilePhotoData)
            await refreshPremiumStatus()
            await refreshSocial()
            saveSnapshot()
        } catch {
            authStatusMessage = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    func recordAppleSignIn(userIdentifier: String, email: String?) {
        let displayEmail = email ?? "Apple private relay"
        authStatusMessage = "Finishing Apple sign-in..."
        Task {
            do {
                let session = try await apiClient.signInWithApple(userIdentifier: userIdentifier, email: email, displayName: profile.displayName)
                authSession = session
                apiClient.authToken = session.accessToken
                authStatusMessage = "Signed in with Apple as \(displayEmail)."
                _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: profile.privacyMode, avatarData: profilePhotoData)
                await refreshPremiumStatus()
                await refreshSocial()
                saveSnapshot()
            } catch {
                apiClient.authToken = nil
                authStatusMessage = "Apple sign-in could not finish. Check your connection and try again."
                lastSyncMessage = "You can keep testing locally, but sync, social, and premium need Sign in with Apple."
                saveSnapshot()
            }
        }
    }

    func completeOnboarding(goalType: GoalType, weeklyWorkouts: Int, accountability: Bool) {
        guard authSession != nil else {
            authStatusMessage = "Sign in with Apple before entering Fitcountable."
            return
        }
        profile.goalType = goalType
        goal.weeklyWorkouts = weeklyWorkouts
        accountabilityEnabled = accountability
        hasCompletedOnboarding = true
        saveSnapshot()
    }

    func updateGoal(_ newGoal: GoalPlan) {
        goal = newGoal
        saveSnapshot()
    }

    func openFoodLog(mealType: MealType) {
        preferredLogMode = .food
        preferredMealType = mealType
        selectedTab = .log
    }

    func openWorkoutLog() {
        preferredLogMode = .workout
        selectedTab = .log
    }

    func openAI() {
        selectedTab = .ai
        isVoicePromptActive = false
    }

    func startVoiceHold() async {
        selectedTab = .ai
        isVoiceHoldActive = true
        isVoicePromptActive = true
        commandProcessingMessage = "Listening..."
        let didStartRecording = await voiceRecorderService.start()
        guard isVoiceHoldActive else {
            voiceRecorderService.discard(voiceRecorderService.stop())
            return
        }
        if didStartRecording == false {
            commandProcessingMessage = voiceRecorderService.statusMessage ?? "Voice is unavailable. Type your log instead."
            aiInputFocusRequest = UUID()
        }
    }

    func finishVoiceHold() {
        selectedTab = .ai
        voiceTimeoutTask?.cancel()
        voiceTimeoutTask = nil
        isVoiceHoldActive = false
        let recordingURL = voiceRecorderService.stop()
        deepgramVoiceService.stop()
        isVoicePromptActive = false

        guard let recordingURL else {
            commandProcessingMessage = "Type your log or use keyboard dictation, then tap send."
            aiInputFocusRequest = UUID()
            return
        }

        Task {
            commandProcessingMessage = "Turning your voice into a log..."
            do {
                let audioData = try Data(contentsOf: recordingURL)
                voiceRecorderService.discard(recordingURL)
                let transcription = try await apiClient.transcribeVoiceRecording(audioData: audioData, mimeType: "audio/wav")
                let transcript = transcription.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard transcript.isEmpty == false else {
                    commandProcessingMessage = "I did not catch that. Try again or type your log."
                    return
                }
                commandProcessingMessage = "Building your editable log..."
                await submitCommand(transcript)
            } catch {
                voiceRecorderService.discard(recordingURL)
                commandProcessingMessage = error.localizedDescription
                aiInputFocusRequest = UUID()
            }
        }
    }

    func updatePrivacyMode(_ mode: PrivacyMode) {
        profile.privacyMode = mode
        saveSnapshot()
        Task {
            _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: mode, avatarData: profilePhotoData)
            _ = try? await apiClient.setAccountabilitySettings(enabled: accountabilityEnabled, visibility: visibilityFromPrivacyMode(mode))
        }
    }

    func updateProfilePhoto(_ data: Data?) {
        profilePhotoData = data
        saveSnapshot()
        Task {
            _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: profile.privacyMode, avatarData: data)
        }
    }

    func confirm(_ proposal: ActionProposal, rawText: String? = nil) {
        switch proposal.actionType {
        case .logWorkout:
            workouts.insert(.fromProposal(proposal), at: 0)
        case .logMeal, .estimateFood:
            meals.insert(.fromProposal(proposal), at: 0)
        case .updateGoal:
            goal = goal.updated(from: proposal)
        case .createAccountabilityNudge:
            friends = friends.map { friend in
                guard friend.id == proposal.targetFriendId else { return friend }
                return friend.withNudge(proposal.summary)
            }
        case .createWorkoutPlan, .createNutritionPlan, .summarizeProgress, .correctLastLog:
            break
        }

        Task {
            await persist(proposal, rawText: rawText)
        }
        saveSnapshot()
    }

    func confirm(_ command: AICommandRecord) {
        guard let proposal = command.proposal else { return }
        guard case .confirmed = command.status else {
            confirm(proposal, rawText: command.rawText)
            if let index = commands.firstIndex(where: { $0.id == command.id }) {
                commands[index] = AICommandRecord(id: command.id, rawText: command.rawText, status: .confirmed, proposal: proposal)
            }
            return
        }
    }

    func redo(_ command: AICommandRecord) {
        commands.removeAll { $0.id == command.id }
        isProcessingCommand = commands.contains { record in
            if case .parsing = record.status { true } else { false }
        }
        commandProcessingMessage = nil
        isVoicePromptActive = false
        selectedTab = .ai
        aiInputFocusRequest = UUID()
        saveSnapshot()
    }


    func saveManualWorkout(_ workout: WorkoutLog) {
        workouts.insert(workout, at: 0)
        let proposal = ActionProposal(
            actionType: .logWorkout,
            confidence: 1,
            requiresConfirmation: false,
            summary: workout.notes.isEmpty ? "Manual workout saved." : workout.notes,
            title: workout.title,
            mealType: nil,
            calories: nil,
            protein: nil,
            carbs: nil,
            fat: nil,
            weeklyWorkouts: nil,
            durationMinutes: workout.durationMinutes,
            targetFriendId: nil,
            workoutSets: workout.sets,
            foodItems: [],
            assumptions: [],
            missingFields: []
        )
        Task { await persist(proposal, rawText: "Manual workout: \(workout.title)") }
        saveSnapshot()
    }

    func saveManualMeal(_ meal: MealLog) {
        meals.insert(meal, at: 0)
        let proposal = ActionProposal(
            actionType: .logMeal,
            confidence: 1,
            requiresConfirmation: false,
            summary: meal.notes.isEmpty ? "Manual meal saved." : meal.notes,
            title: nil,
            mealType: meal.mealType,
            calories: nil,
            protein: nil,
            carbs: nil,
            fat: nil,
            weeklyWorkouts: nil,
            durationMinutes: nil,
            targetFriendId: nil,
            workoutSets: [],
            foodItems: meal.items,
            assumptions: [],
            missingFields: []
        )
        Task { await persist(proposal, rawText: "Manual meal: \(meal.items.map(\.name).joined(separator: ", "))") }
        saveSnapshot()
    }

    func searchFriends(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            friendSearchResults = []
            return
        }

        do {
            friendSearchResults = try await apiClient.searchUsers(query: trimmed)
            socialStatusMessage = friendSearchResults.isEmpty ? "No matching users yet." : nil
        } catch {
            socialStatusMessage = "Friend search unavailable: \(error.localizedDescription)"
        }
    }

    func addFriend(name: String) {
        addFriend(FriendProfile(name: name, streak: 0, status: "Invite pending", lastNudge: nil))
    }

    func addFriend(_ friend: FriendProfile) {
        if let targetId = friend.remoteUserId {
            Task {
                await followUser(targetUserId: targetId)
            }
            return
        }
        guard friends.contains(where: { $0.remoteUserId == friend.remoteUserId && friend.remoteUserId != nil || $0.name == friend.name }) == false else {
            socialStatusMessage = "\(friend.name) is already in your accountability list."
            return
        }
        friends.insert(friend, at: 0)
        socialStatusMessage = "Follow request prepared for \(friend.name)."
        saveSnapshot()
    }

    func refreshSocial() async {
        guard authSession != nil else {
            socialStatusMessage = "Sign in to use real friends, proof feeds, and nudges."
            return
        }
        do {
            let lists = try await apiClient.friendsList()
            friends = lists.friends.map(\.friendProfile)
            incomingFriendRequests = lists.incoming
            outgoingFriendRequests = lists.outgoing
            proofPosts = try await apiClient.proofFeed(targetUserId: nil)
            socialStatusMessage = proofPosts.isEmpty && friends.isEmpty ? "Find friends or post your first proof." : nil
            saveSnapshot()
        } catch {
            socialStatusMessage = "Social sync failed: \(error.localizedDescription)"
        }
    }

    func followUser(targetUserId: String) async {
        do {
            let result = try await apiClient.followUser(targetUserId: targetUserId)
            socialStatusMessage = result.status == "accepted" ? "Friend request accepted." : "Friend request sent."
            friendSearchResults = []
            await refreshSocial()
        } catch {
            socialStatusMessage = "Friend request failed: \(error.localizedDescription)"
        }
    }

    func respondToFollow(userId: String, action: String) async {
        do {
            _ = try await apiClient.respondFollow(userId: userId, action: action)
            socialStatusMessage = action == "accept" ? "Friend approved." : "Request removed."
            await refreshSocial()
        } catch {
            socialStatusMessage = "Could not update request: \(error.localizedDescription)"
        }
    }

    func createProofPost(caption: String, visibility: Visibility, workout: WorkoutLog?, meal: MealLog?, proofKind: String, photoData: Data?) async {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackCaption = trimmed.isEmpty
            ? (proofKind == "food" ? "Food accountability proof." : "Proof from today's training.")
            : trimmed
        let detailLines = proofDetailLines(workout: workout, meal: meal, proofKind: proofKind)
        do {
            let post = try await apiClient.createProofPost(
                workoutId: nil,
                mealId: nil,
                caption: fallbackCaption,
                visibility: visibility,
                proofKind: proofKind,
                detailLines: detailLines,
                photoData: photoData
            )
            let hydratedPost = enriched(post, workout: workout, meal: meal, proofKind: proofKind, detailLines: detailLines)
            proofPosts.insert(hydratedPost, at: 0)
            if let photoData {
                proofMediaData[hydratedPost.id] = photoData
            }
            socialStatusMessage = visibility == .privateOnly ? "Proof saved privately." : "Proof posted to \(visibility.rawValue.lowercased())."
            saveSnapshot()
        } catch {
            socialStatusMessage = "Proof could not be saved: \(error.localizedDescription)"
            saveSnapshot()
        }
    }

    func loadSocialProfile(userId: String) async {
        do {
            selectedSocialProfile = try await apiClient.profileView(targetUserId: userId)
        } catch {
            socialStatusMessage = "Profile unavailable: \(error.localizedDescription)"
        }
    }

    func removeFriend(_ friend: FriendProfile) async {
        guard let remoteUserId = friend.remoteUserId else {
            friends.removeAll { $0.id == friend.id }
            saveSnapshot()
            return
        }
        do {
            _ = try await apiClient.respondFollow(userId: remoteUserId, action: "remove")
            socialStatusMessage = "\(friend.name) removed."
            await refreshSocial()
        } catch {
            socialStatusMessage = "Could not remove friend: \(error.localizedDescription)"
        }
    }

    func setAccountabilityEnabled(_ enabled: Bool) {
        accountabilityEnabled = enabled
        saveSnapshot()
        Task {
            do {
                _ = try await apiClient.setAccountabilitySettings(enabled: enabled, visibility: visibilityFromPrivacyMode(profile.privacyMode))
            } catch {
                socialStatusMessage = "Accountability setting will retry when sync is available."
            }
        }
    }

    func attachProofNote(_ caption: String, visibility: Visibility, workout: WorkoutLog? = nil) {
        guard let workout else { return }
        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        workouts[index].notes = "\(workouts[index].notes) \(caption)".trimmingCharacters(in: .whitespaces)
        workouts[index].visibility = visibility
        saveSnapshot()
    }

    func sendNudge(to friend: FriendProfile) async {
        let message = "Nudge \(friend.name) to stay consistent today"
        do {
            _ = try await apiClient.sendNudge(to: friend, message: message)
            friends = friends.map { candidate in
                guard candidate.id == friend.id else { return candidate }
                return candidate.withNudge(message)
            }
            socialStatusMessage = "Nudge queued for \(friend.name)."
            saveSnapshot()
        } catch {
            socialStatusMessage = "Nudge failed: \(error.localizedDescription)"
        }
    }

    private func enriched(_ post: SocialProofPost, workout: WorkoutLog?, meal: MealLog?, proofKind: String, detailLines: [String]) -> SocialProofPost {
        guard post.detailLines?.isEmpty != false || post.proofKind == nil || post.workoutTitle == "Gym proof" || post.workoutTitle == "Workout proof" else { return post }
        let title = proofTitle(workout: workout, meal: meal, proofKind: proofKind)
        return SocialProofPost(
            id: post.id,
            userId: post.userId,
            displayName: post.displayName,
            avatarURL: post.avatarURL,
            workoutId: workout?.id.uuidString,
            mealId: meal?.id.uuidString,
            workoutTitle: title,
            durationMinutes: workout?.durationMinutes,
            setCount: workout?.sets.count ?? 0,
            caption: post.caption,
            visibility: post.visibility,
            mediaURL: post.mediaURL,
            mediaType: post.mediaType,
            createdAt: post.createdAt,
            relationship: post.relationship,
            proofKind: proofKind,
            detailLines: post.detailLines?.isEmpty == false ? post.detailLines : detailLines
        )
    }

    private func localProofPost(caption: String, visibility: Visibility, workout: WorkoutLog?, meal: MealLog?, proofKind: String) -> SocialProofPost {
        SocialProofPost(
            id: UUID().uuidString,
            userId: authSession?.userId ?? "local-demo",
            displayName: profile.displayName,
            avatarURL: nil,
            workoutId: workout?.id.uuidString,
            mealId: meal?.id.uuidString,
            workoutTitle: proofTitle(workout: workout, meal: meal, proofKind: proofKind),
            durationMinutes: workout?.durationMinutes,
            setCount: workout?.sets.count ?? 0,
            caption: caption,
            visibility: visibility,
            mediaURL: nil,
            mediaType: "image",
            createdAt: ISO8601DateFormatter().string(from: .now),
            relationship: "own",
            proofKind: proofKind,
            detailLines: proofDetailLines(workout: workout, meal: meal, proofKind: proofKind)
        )
    }

    private func proofTitle(workout: WorkoutLog?, meal: MealLog?, proofKind: String) -> String {
        if proofKind == "food" {
            if let meal {
                return "\(meal.mealType.rawValue) proof"
            }
            return "Food proof"
        }
        return workout?.title ?? "Gym proof"
    }

    private func proofDetailLines(workout: WorkoutLog?, meal: MealLog?, proofKind: String) -> [String] {
        if proofKind == "food" {
            guard let meal else { return ["Food accountability proof"] }
            let itemLines = meal.items.prefix(4).map { item in
                "\(item.name) · \(item.quantityText) · \(item.calories) cal"
            }
            return itemLines.isEmpty ? ["\(meal.totalCalories) cal logged"] : itemLines + ["\(meal.totalCalories) cal total"]
        }
        guard let workout else { return ["Gym accountability proof"] }
        let setLines = workout.compactSetSummaries.prefix(4).map { $0 }
        return setLines.isEmpty ? ["\(workout.durationMinutes)m workout logged"] : Array(setLines)
    }

    private func visibilityFromPrivacyMode(_ mode: PrivacyMode) -> Visibility {
        switch mode {
        case .privateProfile:
            .privateOnly
        case .friendsOnly:
            .friends
        case .publicProfile:
            .publicPost
        }
    }

    func setPremiumPreviewActive() {
        isPremium = true
        saveSnapshot()
    }

    func refreshPremiumStatus() async {
        guard let authSession else {
            isPremium = false
            return
        }
        await purchaseService.identify(appUserId: authSession.userId)
        isPremium = purchaseService.entitlementActive
        saveSnapshot()
    }

    private func persist(_ proposal: ActionProposal, rawText: String?) async {
        do {
            let confirmation = try await apiClient.confirmAction(rawText: rawText ?? proposal.summary, proposal: proposal)
            lastSyncMessage = confirmation.persisted
                ? "Saved to Fitcountable."
                : "Saved. Sync will retry when the connection is available."
        } catch {
            lastSyncMessage = "Saved. Sync failed: \(error.localizedDescription)"
        }
        saveSnapshot()
    }

    private func saveSnapshot() {
        let snapshot = LocalSnapshot(
            hasCompletedOnboarding: hasCompletedOnboarding,
            profile: profile,
            profilePhotoData: profilePhotoData,
            goal: goal,
            workouts: workouts,
            meals: meals,
            friends: friends,
            incomingFriendRequests: incomingFriendRequests,
            outgoingFriendRequests: outgoingFriendRequests,
            proofPosts: proofPosts,
            proofMediaData: proofMediaData,
            isPremium: isPremium,
            accountabilityEnabled: accountabilityEnabled,
            authSession: authSession,
            authStatusMessage: authStatusMessage,
            lastSyncMessage: lastSyncMessage,
            socialStatusMessage: socialStatusMessage
        )
        if let data = try? JSONEncoder.fitcountable.encode(snapshot) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }

    private func loadSnapshot() {
        guard
            let data = UserDefaults.standard.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder.fitcountable.decode(LocalSnapshot.self, from: data)
        else { return }
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        profile = snapshot.profile
        profilePhotoData = snapshot.profilePhotoData
        goal = snapshot.goal
        workouts = snapshot.workouts
        meals = snapshot.meals
        friends = snapshot.friends
        incomingFriendRequests = snapshot.incomingFriendRequests
        outgoingFriendRequests = snapshot.outgoingFriendRequests
        proofPosts = snapshot.proofPosts
        proofMediaData = snapshot.proofMediaData
        isPremium = snapshot.isPremium
        accountabilityEnabled = snapshot.accountabilityEnabled
        authSession = snapshot.authSession
        authStatusMessage = snapshot.authStatusMessage
        lastSyncMessage = snapshot.lastSyncMessage
        socialStatusMessage = snapshot.socialStatusMessage
        apiClient.authToken = snapshot.authSession?.accessToken
        if authSession == nil {
            hasCompletedOnboarding = false
            authStatusMessage = "Sign in with Apple before entering Fitcountable."
        }
        selectedTab = .today
        isVoicePromptActive = false
        commandProcessingMessage = nil
    }

    private func configureForScreenshot(screen: String) {
        hasCompletedOnboarding = screen != "onboarding"
        profile = UserProfile.sample
        goal = GoalPlan(calories: 2450, protein: 185, carbs: 260, fat: 75, weeklyWorkouts: 4, targetPace: "Steady recomp")
        workouts = [
            WorkoutLog(title: "Push Day", startedAt: .now, durationMinutes: 58, source: .ai, notes: "Proof logged. Bench felt strong and accountability is on.", visibility: .friends, sets: [
                WorkoutSet(exerciseName: "Bench Press", setIndex: 1, reps: 5, weight: 185, rpe: 8),
                WorkoutSet(exerciseName: "Incline Dumbbell Press", setIndex: 2, reps: 10, weight: 60, rpe: 7),
                WorkoutSet(exerciseName: "Triceps Pushdown", setIndex: 3, reps: 12, weight: 70, rpe: 8)
            ]),
            WorkoutLog(title: "Lower Strength", startedAt: .now.addingTimeInterval(-86_400), durationMinutes: 52, source: .manual, notes: "Squats, RDLs, calves.", visibility: .friends, sets: [
                WorkoutSet(exerciseName: "Back Squat", setIndex: 1, reps: 5, weight: 225, rpe: 8),
                WorkoutSet(exerciseName: "Romanian Deadlift", setIndex: 2, reps: 8, weight: 185, rpe: 7)
            ])
        ]
        meals = [
            MealLog(mealType: .breakfast, loggedAt: .now, source: .manual, notes: "Quick breakfast", items: [
                FoodItem(name: "Eggs", quantityText: "3 large", calories: 210, protein: 18, carbs: 2, fat: 15, confidence: 0.9),
                FoodItem(name: "Protein shake", quantityText: "1 serving", calories: 150, protein: 30, carbs: 4, fat: 2, confidence: 0.86)
            ]),
            MealLog(mealType: .lunch, loggedAt: .now, source: .ai, notes: "AI estimate reviewed before saving.", items: [
                FoodItem(name: "Chicken burrito bowl", quantityText: "1 bowl", calories: 760, protein: 48, carbs: 78, fat: 28, confidence: 0.88)
            ]),
            MealLog(mealType: .snack, loggedAt: .now, source: .ai, notes: "Editable macro estimate.", items: [
                FoodItem(name: "Greek yogurt and berries", quantityText: "1 cup", calories: 220, protein: 24, carbs: 25, fat: 3, confidence: 0.83)
            ])
        ]
        commands = [
            AICommandRecord(
                rawText: "Estimate my chicken burrito bowl with rice, beans, corn, sour cream, guac, and steak.",
                status: .ready,
                proposal: ActionProposal(
                    actionType: .estimateFood,
                    confidence: 0.88,
                    requiresConfirmation: true,
                    summary: "Estimated lunch: 760 calories with high protein. Review portions before saving.",
                    title: nil,
                    mealType: .lunch,
                    calories: 760,
                    protein: 48,
                    carbs: 78,
                    fat: 28,
                    weeklyWorkouts: nil,
                    durationMinutes: nil,
                    targetFriendId: nil,
                    workoutSets: [],
                    foodItems: [
                        FoodItem(name: "Burrito bowl", quantityText: "1 bowl", calories: 760, protein: 48, carbs: 78, fat: 28, confidence: 0.88)
                    ],
                    assumptions: ["Regular serving sizes.", "Restaurant-style toppings included."],
                    missingFields: []
                )
            ),
            AICommandRecord(
                rawText: "Log push day. Bench 185 for 5x5, incline dumbbell 60s for 3x10, triceps pushdown 3x12.",
                status: .confirmed,
                proposal: ActionProposal(
                    actionType: .logWorkout,
                    confidence: 0.94,
                    requiresConfirmation: true,
                    summary: "Push Day saved with three exercises and proof visibility set to friends.",
                    title: "Push Day",
                    mealType: nil,
                    calories: nil,
                    protein: nil,
                    carbs: nil,
                    fat: nil,
                    weeklyWorkouts: nil,
                    durationMinutes: 58,
                    targetFriendId: nil,
                    workoutSets: workouts.first?.sets ?? [],
                    foodItems: [],
                    assumptions: ["Weight unit interpreted as pounds."],
                    missingFields: []
                )
            )
        ]
        friends = [
            FriendProfile(name: "Jordan", streak: 12, status: "Lifted yesterday", lastNudge: "Nudge Jordan to stay consistent today"),
            FriendProfile(name: "Maya", streak: 5, status: "Needs a meal log", lastNudge: nil),
            FriendProfile(name: "Chris", streak: 8, status: "Proof posted today", lastNudge: nil)
        ]
        isPremium = false
        accountabilityEnabled = true
        authSession = AuthSession(
            userId: "launch-screenshot-user",
            email: "barack@fitcountable.app",
            accessToken: "launch-screenshot-session",
            refreshToken: nil
        )
        apiClient.authToken = authSession?.accessToken
        authStatusMessage = "Signed in with Apple."
        lastSyncMessage = "Review and confirm AI drafts before saving."
        socialStatusMessage = "Nudge queued for Jordan."

        switch screen {
        case "log":
            selectedTab = .log
        case "ai":
            selectedTab = .ai
        case "social":
            selectedTab = .social
        case "profile":
            selectedTab = .profile
        default:
            selectedTab = .today
        }
    }
}

private struct LocalSnapshot: Codable {
    var hasCompletedOnboarding: Bool
    var profile: UserProfile
    var profilePhotoData: Data?
    var goal: GoalPlan
    var workouts: [WorkoutLog]
    var meals: [MealLog]
    var friends: [FriendProfile]
    var incomingFriendRequests: [FriendSearchResult] = []
    var outgoingFriendRequests: [FriendSearchResult] = []
    var proofPosts: [SocialProofPost] = []
    var proofMediaData: [String: Data] = [:]
    var isPremium: Bool
    var accountabilityEnabled: Bool
    var authSession: AuthSession?
    var authStatusMessage: String
    var lastSyncMessage: String?
    var socialStatusMessage: String?

    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding
        case profile
        case profilePhotoData
        case goal
        case workouts
        case meals
        case friends
        case incomingFriendRequests
        case outgoingFriendRequests
        case proofPosts
        case proofMediaData
        case isPremium
        case accountabilityEnabled
        case authSession
        case authStatusMessage
        case lastSyncMessage
        case socialStatusMessage
    }

    init(
        hasCompletedOnboarding: Bool,
        profile: UserProfile,
        profilePhotoData: Data? = nil,
        goal: GoalPlan,
        workouts: [WorkoutLog],
        meals: [MealLog],
        friends: [FriendProfile],
        incomingFriendRequests: [FriendSearchResult] = [],
        outgoingFriendRequests: [FriendSearchResult] = [],
        proofPosts: [SocialProofPost] = [],
        proofMediaData: [String: Data] = [:],
        isPremium: Bool,
        accountabilityEnabled: Bool,
        authSession: AuthSession?,
        authStatusMessage: String,
        lastSyncMessage: String?,
        socialStatusMessage: String?
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.profile = profile
        self.profilePhotoData = profilePhotoData
        self.goal = goal
        self.workouts = workouts
        self.meals = meals
        self.friends = friends
        self.incomingFriendRequests = incomingFriendRequests
        self.outgoingFriendRequests = outgoingFriendRequests
        self.proofPosts = proofPosts
        self.proofMediaData = proofMediaData
        self.isPremium = isPremium
        self.accountabilityEnabled = accountabilityEnabled
        self.authSession = authSession
        self.authStatusMessage = authStatusMessage
        self.lastSyncMessage = lastSyncMessage
        self.socialStatusMessage = socialStatusMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container.decode(Bool.self, forKey: .hasCompletedOnboarding)
        profile = try container.decode(UserProfile.self, forKey: .profile)
        profilePhotoData = try container.decodeIfPresent(Data.self, forKey: .profilePhotoData)
        goal = try container.decode(GoalPlan.self, forKey: .goal)
        workouts = try container.decode([WorkoutLog].self, forKey: .workouts)
        meals = try container.decode([MealLog].self, forKey: .meals)
        friends = try container.decode([FriendProfile].self, forKey: .friends)
        incomingFriendRequests = try container.decodeIfPresent([FriendSearchResult].self, forKey: .incomingFriendRequests) ?? []
        outgoingFriendRequests = try container.decodeIfPresent([FriendSearchResult].self, forKey: .outgoingFriendRequests) ?? []
        proofPosts = try container.decodeIfPresent([SocialProofPost].self, forKey: .proofPosts) ?? []
        proofMediaData = try container.decodeIfPresent([String: Data].self, forKey: .proofMediaData) ?? [:]
        isPremium = try container.decode(Bool.self, forKey: .isPremium)
        accountabilityEnabled = try container.decode(Bool.self, forKey: .accountabilityEnabled)
        authSession = try container.decodeIfPresent(AuthSession.self, forKey: .authSession)
        authStatusMessage = try container.decode(String.self, forKey: .authStatusMessage)
        lastSyncMessage = try container.decodeIfPresent(String.self, forKey: .lastSyncMessage)
        socialStatusMessage = try container.decodeIfPresent(String.self, forKey: .socialStatusMessage)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case log = "Log"
    case ai = "AI"
    case social = "Social"
    case profile = "Profile"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "gauge.with.dots.needle.bottom.50percent"
        case .log: "plus.square.on.square"
        case .ai: "sparkles"
        case .social: "person.2"
        case .profile: "person.crop.circle"
        }
    }
}

enum LogMode: Int, Codable {
    case workout = 0
    case food = 1
}
