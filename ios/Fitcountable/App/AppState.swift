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
    @Published var isSigningInWithApple = false
    @Published var lastSyncMessage: String?
    @Published var friendSearchResults: [FriendSearchResult] = []
    @Published var incomingFriendRequests: [FriendSearchResult] = []
    @Published var outgoingFriendRequests: [FriendSearchResult] = []
    @Published var proofPosts: [SocialProofPost] = []
    @Published var proofMediaData: [String: Data] = [:]
    @Published var selectedSocialProfile: SocialProfileView?
    @Published var socialStatusMessage: String?
    @Published var isProcessingCommand = false
    @Published var isSavingProof = false
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
    let analytics = AnalyticsService(endpoint: URL(string: "https://hxvc7grj.us-east.insforge.app/functions/track-event")!)
    let purchaseService = PurchaseService()
    private let snapshotKey = "fitcountable.local.snapshot.v1"
    private var voiceTimeoutTask: Task<Void, Never>?
    private var isVoiceHoldActive = false

    init() {
        apiClient.onSessionRefreshed = { [weak self] session in
            guard let self else { return }
            self.authSession = session
            self.apiClient.authToken = session.accessToken
            self.apiClient.refreshToken = session.refreshToken
            self.saveSnapshot()
        }
        if ProcessInfo.processInfo.environment["FITCOUNTABLE_RESET_STATE"] == "1" {
            UserDefaults.standard.removeObject(forKey: snapshotKey)
        }
        if let screenshotScreen = ProcessInfo.processInfo.environment["FITCOUNTABLE_SCREENSHOT"] {
            configureForScreenshot(screen: screenshotScreen)
        } else {
            loadSnapshot()
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

    func trackAppOpened() {
        track("app_opened", properties: [
            "has_completed_onboarding": .bool(hasCompletedOnboarding),
            "is_authenticated": .bool(authSession != nil),
            "selected_tab": .string(selectedTab.rawValue),
            "is_premium": .bool(isPremium || purchaseService.entitlementActive)
        ])
    }

    func trackPremiumViewed() {
        track("premium_viewed", properties: [
            "is_premium": .bool(isPremium || purchaseService.entitlementActive),
            "has_loaded_store_products": .bool(purchaseService.hasLoadedStoreProducts)
        ])
    }

    func trackPremiumPurchaseStarted(package: String) {
        track("premium_purchase_started", properties: [
            "package": .string(package)
        ])
    }

    func trackPremiumPurchaseFinished(package: String) {
        track("premium_purchase_finished", properties: [
            "package": .string(package),
            "is_premium": .bool(isPremium || purchaseService.entitlementActive),
            "active_plan": .string(purchaseService.activePlanLabel ?? "unknown")
        ])
    }

    func trackPremiumRestoreStarted() {
        track("premium_restore_started")
    }

    func trackPremiumRestoreFinished() {
        track("premium_restore_finished", properties: [
            "is_premium": .bool(isPremium || purchaseService.entitlementActive),
            "active_plan": .string(purchaseService.activePlanLabel ?? "unknown")
        ])
    }

    func submitCommand(_ text: String, currentMealType: MealType? = nil) async {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        track("command_submitted", properties: [
            "input_length": .int(text.count),
            "current_meal_type": .string(currentMealType?.rawValue ?? "none")
        ])
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
            track("command_parsed", properties: [
                "action_type": .string(proposal.actionType.rawValue),
                "confidence": .double(proposal.confidence),
                "food_item_count": .int(proposal.foodItems.count),
                "workout_set_count": .int(proposal.workoutSets.count)
            ])
        } catch {
            if let index = commands.firstIndex(where: { $0.id == draft.id }) {
                commands[index] = AICommandRecord(id: draft.id, rawText: text, status: .failed(AppState.friendlyMessage(for: error, fallback: "Couldn't turn that into a log. Check your connection and try again.")))
            }
            track("command_parse_failed", properties: [
                "message": .string(error.localizedDescription)
            ])
        }
    }

    func refineCommand(_ command: AICommandRecord, detail: String) async {
        let cleanDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanDetail.isEmpty == false else { return }
        guard commands.contains(where: { $0.id == command.id }) else { return }
        track("command_refine_started", properties: [
            "detail_length": .int(cleanDetail.count),
            "had_proposal": .bool(command.proposal != nil)
        ])

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
            let proposal = try await apiClient.parseCommand(
                text: refinedText,
                context: .init(
                    profile: profile,
                    goal: goal,
                    savedFoods: Array(savedFoodItems.prefix(30)),
                    currentMealType: command.proposal?.mealType
                )
            )
            if let index = commands.firstIndex(where: { $0.id == command.id }) {
                commands[index] = AICommandRecord(id: command.id, rawText: refinedText, status: .ready, proposal: proposal)
            }
            track("command_refine_completed", properties: [
                "action_type": .string(proposal.actionType.rawValue),
                "confidence": .double(proposal.confidence)
            ])
        } catch {
            if let index = commands.firstIndex(where: { $0.id == command.id }) {
                commands[index] = AICommandRecord(id: command.id, rawText: refinedText, status: .failed(AppState.friendlyMessage(for: error, fallback: "Couldn't update that draft. Check your connection and try again.")), proposal: command.proposal)
            }
            track("command_refine_failed", properties: [
                "message": .string(error.localizedDescription)
            ])
        }
    }

    private var didTrackOnboardingStart = false

    func trackOnboardingStarted() {
        guard didTrackOnboardingStart == false else { return }
        didTrackOnboardingStart = true
        track("onboarding_started")
    }

    func signIn(email: String, password: String) async {
        track("sign_in_started", properties: ["provider": .string("email")])
        do {
            let session = try await apiClient.signIn(email: email, password: password)
            authSession = session
            apiClient.authToken = session.accessToken
            apiClient.refreshToken = session.refreshToken
            authStatusMessage = "Signed in as \(session.email). Confirmed logs will sync."
            _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: profile.privacyMode, avatarData: profilePhotoData)
            await refreshSocial()
            saveSnapshot()
            track("sign_in_completed", properties: ["provider": .string("email")])
        } catch {
            authStatusMessage = AppState.friendlyMessage(for: error, fallback: "Sign-in didn't finish. Check your connection and try again.")
            track("sign_in_failed", properties: ["provider": .string("email")])
        }
    }

    func recordAppleSignIn(userIdentifier: String, email: String?, identityToken: String? = nil, authorizationCode: String? = nil) {
        guard isSigningInWithApple == false else { return }
        track("sign_in_started", properties: ["provider": .string("apple")])
        let displayEmail = email ?? "Apple private relay"
        isSigningInWithApple = true
        authStatusMessage = "Finishing Apple sign-in..."
        Task {
            defer {
                isSigningInWithApple = false
            }
            do {
                let session = try await apiClient.signInWithApple(
                    userIdentifier: userIdentifier,
                    email: email,
                    displayName: profile.displayName,
                    identityToken: identityToken,
                    authorizationCode: authorizationCode
                )
                authSession = session
                apiClient.authToken = session.accessToken
                apiClient.refreshToken = session.refreshToken
                authStatusMessage = "Signed in with Apple as \(displayEmail)."
                await purchaseService.identify(appUserId: session.userId)
                isPremium = purchaseService.entitlementActive
                _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: profile.privacyMode, avatarData: profilePhotoData)
                await refreshSocial()
                saveSnapshot()
                track("sign_in_completed", properties: [
                    "provider": .string("apple"),
                    "revenuecat_identified": .bool(true),
                    "is_premium": .bool(isPremium)
                ])
            } catch {
                apiClient.authToken = nil
                apiClient.refreshToken = nil
                authStatusMessage = "Apple sign-in could not finish. Check your connection and try again."
                lastSyncMessage = nil
                saveSnapshot()
                track("sign_in_failed", properties: [
                    "provider": .string("apple"),
                    "message": .string(error.localizedDescription)
                ])
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
        track("onboarding_completed", properties: [
            "goal_type": .string(goalType.rawValue),
            "weekly_workouts": .int(weeklyWorkouts),
            "accountability_enabled": .bool(accountability)
        ])
    }

    func signOut() {
        track("signed_out")
        authSession = nil
        apiClient.authToken = nil
        apiClient.refreshToken = nil
        selectedTab = .today
        hasCompletedOnboarding = false
        isVoicePromptActive = false
        isProcessingCommand = false
        commandProcessingMessage = nil
        friendSearchResults = []
        incomingFriendRequests = []
        outgoingFriendRequests = []
        selectedSocialProfile = nil
        socialStatusMessage = nil
        authStatusMessage = "Signed out. Sign in with Apple to continue."
        lastSyncMessage = nil
        isPremium = false
        Task {
            await purchaseService.logOut()
        }
        purchaseService.clearLocalEntitlementState()
        saveSnapshot()
    }

    func deleteAccount() async {
        guard authSession != nil else {
            signOut()
            return
        }
        do {
            _ = try await apiClient.deleteAccount()
            track("account_deleted")
            clearLocalAccountState(message: "Account deleted.")
        } catch {
            authStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't delete your account right now. Try again in a moment.")
            track("account_delete_failed")
            saveSnapshot()
        }
    }

    func updateGoal(_ newGoal: GoalPlan) {
        goal = newGoal
        track("goal_updated", properties: [
            "calories": .int(newGoal.calories),
            "protein": .int(newGoal.protein),
            "carbs": .int(newGoal.carbs),
            "fat": .int(newGoal.fat),
            "weekly_workouts": .int(newGoal.weeklyWorkouts)
        ])
        saveSnapshot()
    }

    func openFoodLog(mealType: MealType) {
        track("log_opened", properties: ["mode": .string("food"), "meal_type": .string(mealType.rawValue)])
        preferredLogMode = .food
        preferredMealType = mealType
        selectedTab = .log
    }

    func openWorkoutLog() {
        track("log_opened", properties: ["mode": .string("workout")])
        preferredLogMode = .workout
        selectedTab = .log
    }

    func openAI() {
        track("ai_opened")
        selectedTab = .ai
        isVoicePromptActive = false
    }

    func startVoiceHold() async {
        track("voice_hold_started")
        selectedTab = .ai
        isVoiceHoldActive = true
        isVoicePromptActive = true
        commandProcessingMessage = "Listening..."

        #if !targetEnvironment(simulator)
        switch await voiceRecorderService.ensureMicrophonePermission() {
        case .denied:
            isVoiceHoldActive = false
            isVoicePromptActive = false
            commandProcessingMessage = "Turn on Microphone access in Settings to use voice logging."
            track("voice_permission_denied")
            return
        case .justGranted:
            // The system permission alert interrupted the hold gesture; ask for a fresh hold.
            isVoiceHoldActive = false
            isVoicePromptActive = false
            commandProcessingMessage = "Microphone is ready. Hold the mic button and speak."
            track("voice_permission_granted")
            return
        case .granted:
            break
        }
        #endif

        let didStartRecording = await voiceRecorderService.start()
        guard isVoiceHoldActive else {
            voiceRecorderService.discard(voiceRecorderService.stop())
            return
        }
        if didStartRecording == false {
            commandProcessingMessage = voiceRecorderService.statusMessage ?? "Voice is unavailable. Type your log instead."
            aiInputFocusRequest = UUID()
            track("voice_recording_failed", properties: [
                "message": .string(commandProcessingMessage ?? "unknown")
            ])
        }
    }

    func finishVoiceHold() {
        track("voice_hold_finished")
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
            track("voice_recording_empty")
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
                    track("voice_transcription_empty")
                    return
                }
                commandProcessingMessage = "Building your editable log..."
                track("voice_transcription_completed", properties: [
                    "transcript_length": .int(transcript.count)
                ])
                await submitCommand(transcript)
            } catch {
                voiceRecorderService.discard(recordingURL)
                commandProcessingMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't process that recording. Type your log instead.")
                aiInputFocusRequest = UUID()
                track("voice_transcription_failed", properties: [
                    "message": .string(error.localizedDescription)
                ])
            }
        }
    }

    func updatePrivacyMode(_ mode: PrivacyMode) {
        profile.privacyMode = mode
        track("privacy_mode_updated", properties: ["mode": .string(mode.rawValue)])
        saveSnapshot()
        Task {
            _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: mode, avatarData: profilePhotoData)
            _ = try? await apiClient.setAccountabilitySettings(enabled: accountabilityEnabled, visibility: visibilityFromPrivacyMode(mode))
        }
    }

    func updateProfilePhoto(_ data: Data?) {
        profilePhotoData = data
        track("profile_photo_updated", properties: ["has_photo": .bool(data != nil)])
        saveSnapshot()
        Task {
            _ = try? await apiClient.bootstrapProfile(displayName: profile.displayName, goalType: profile.goalType, privacyMode: profile.privacyMode, avatarData: data)
        }
    }

    func confirm(_ proposal: ActionProposal, rawText: String? = nil) {
        track("proposal_confirmed", properties: [
            "action_type": .string(proposal.actionType.rawValue),
            "confidence": .double(proposal.confidence),
            "food_item_count": .int(proposal.foodItems.count),
            "workout_set_count": .int(proposal.workoutSets.count)
        ])
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
        track("command_redone", properties: [
            "had_proposal": .bool(command.proposal != nil)
        ])
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
        track("manual_workout_saved", properties: [
            "duration_minutes": .int(workout.durationMinutes),
            "set_count": .int(workout.sets.count),
            "visibility": .string(workout.visibility.rawValue)
        ])
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
        track("manual_meal_saved", properties: [
            "meal_type": .string(meal.mealType.rawValue),
            "item_count": .int(meal.items.count),
            "calories": .int(meal.totalCalories)
        ])
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
        track("friend_search_submitted", properties: [
            "query_length": .int(trimmed.count)
        ])

        do {
            friendSearchResults = try await apiClient.searchUsers(query: trimmed)
            socialStatusMessage = friendSearchResults.isEmpty ? "No matching users yet." : nil
            track("friend_search_completed", properties: [
                "result_count": .int(friendSearchResults.count)
            ])
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Friend search isn't available right now. Try again in a moment.")
            track("friend_search_failed")
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
            await hydrateProofMedia(for: proofPosts)
            socialStatusMessage = proofPosts.isEmpty && friends.isEmpty ? "Find friends or post your first proof." : nil
            saveSnapshot()
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't refresh your feed. Check your connection and try again.")
        }
    }

    func followUser(targetUserId: String) async {
        do {
            let result = try await apiClient.followUser(targetUserId: targetUserId)
            socialStatusMessage = result.status == "accepted" ? "Friend request accepted." : "Friend request sent."
            track("follow_request_sent", properties: [
                "status": .string(result.status)
            ])
            friendSearchResults = []
            await refreshSocial()
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't send that friend request. Try again in a moment.")
            track("follow_request_failed")
        }
    }

    func respondToFollow(userId: String, action: String) async {
        do {
            _ = try await apiClient.respondFollow(userId: userId, action: action)
            socialStatusMessage = action == "accept" ? "Friend approved." : "Request removed."
            track("follow_request_responded", properties: [
                "action": .string(action)
            ])
            await refreshSocial()
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't update that request. Try again in a moment.")
            track("follow_request_response_failed", properties: [
                "action": .string(action)
            ])
        }
    }

    @discardableResult
    func createProofPost(caption: String, visibility: Visibility, workout: WorkoutLog?, meal: MealLog?, proofKind: String, photoData: Data?) async -> Bool {
        guard isSavingProof == false else { return false }
        isSavingProof = true
        socialStatusMessage = "Saving proof..."
        defer { isSavingProof = false }

        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        track("proof_post_started", properties: [
            "proof_kind": .string(proofKind),
            "visibility": .string(visibility.rawValue),
            "has_photo": .bool(photoData != nil),
            "has_workout": .bool(workout != nil),
            "has_meal": .bool(meal != nil)
        ])
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
            track("proof_post_created", properties: [
                "proof_kind": .string(proofKind),
                "visibility": .string(visibility.rawValue),
                "has_photo": .bool(photoData != nil)
            ])
            saveSnapshot()
            return true
        } catch {
            socialStatusMessage = photoData == nil
                ? "Proof could not be saved. Please try again."
                : "Proof photo could not be saved. Please try again."
            track("proof_post_failed", properties: [
                "proof_kind": .string(proofKind),
                "visibility": .string(visibility.rawValue),
                "has_photo": .bool(photoData != nil)
            ])
            saveSnapshot()
            return false
        }
    }

    func removeProofPhoto(_ post: SocialProofPost) async {
        guard post.relationship == "own" else { return }
        socialStatusMessage = "Removing photo..."
        do {
            _ = try await apiClient.removeProofMedia(postId: post.id)
            if let index = proofPosts.firstIndex(where: { $0.id == post.id }) {
                proofPosts[index].mediaURL = nil
                proofPosts[index].mediaType = nil
            }
            proofMediaData.removeValue(forKey: post.id)
            socialStatusMessage = "Photo removed."
            track("proof_photo_removed")
            saveSnapshot()
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't remove that photo. Try again in a moment.")
            track("proof_photo_remove_failed")
            saveSnapshot()
        }
    }

    func deleteProofPost(_ post: SocialProofPost) async {
        guard post.relationship == "own" else { return }
        socialStatusMessage = "Deleting proof..."
        do {
            _ = try await apiClient.deleteProofPost(postId: post.id)
            proofPosts.removeAll { $0.id == post.id }
            proofMediaData.removeValue(forKey: post.id)
            socialStatusMessage = "Proof deleted."
            track("proof_post_deleted")
            saveSnapshot()
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't delete that proof. Try again in a moment.")
            track("proof_post_delete_failed")
            saveSnapshot()
        }
    }

    private func hydrateProofMedia(for posts: [SocialProofPost]) async {
        for post in posts {
            guard proofMediaData[post.id] == nil, let mediaURL = post.mediaURL else {
                continue
            }
            if let data = try? await apiClient.proofMediaData(from: mediaURL.absoluteString) {
                proofMediaData[post.id] = data
            }
        }
    }

    func loadSocialProfile(userId: String) async {
        do {
            selectedSocialProfile = try await apiClient.profileView(targetUserId: userId)
            track("social_profile_viewed")
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "That profile isn't available right now.")
            track("social_profile_view_failed")
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
            track("friend_removed")
            await refreshSocial()
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't remove that friend. Try again in a moment.")
            track("friend_remove_failed")
        }
    }

    func setAccountabilityEnabled(_ enabled: Bool) {
        accountabilityEnabled = enabled
        track("accountability_enabled_updated", properties: ["enabled": .bool(enabled)])
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
            track("nudge_sent")
            saveSnapshot()
        } catch {
            socialStatusMessage = AppState.friendlyMessage(for: error, fallback: "Couldn't send that nudge. Try again in a moment.")
            track("nudge_failed")
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
        track("premium_status_refreshed", properties: [
            "is_premium": .bool(isPremium),
            "active_plan": .string(purchaseService.activePlanLabel ?? "unknown")
        ])
        saveSnapshot()
    }

    static func friendlyMessage(for error: Error, fallback: String) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? fallback
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "You appear to be offline. Check your connection and try again."
            case .timedOut:
                return "That took too long. Check your connection and try again."
            default:
                return fallback
            }
        }
        return fallback
    }

    private func track(_ event: String, properties: [String: AnalyticsValue] = [:]) {
        let session = authSession
        Task {
            await analytics.capture(
                event,
                distinctId: session?.userId,
                authToken: session?.accessToken,
                properties: properties
            )
        }
    }

    private func persist(_ proposal: ActionProposal, rawText: String?) async {
        do {
            let confirmation = try await apiClient.confirmAction(rawText: rawText ?? proposal.summary, proposal: proposal)
            lastSyncMessage = confirmation.persisted
                ? "Saved to Fitcountable."
                : "Saved. Sync will retry when the connection is available."
            track("proposal_persisted", properties: [
                "action_type": .string(proposal.actionType.rawValue),
                "persisted": .bool(confirmation.persisted)
            ])
        } catch {
            lastSyncMessage = "Saved on this device. Sync will retry when your connection is back."
            track("proposal_persist_failed", properties: [
                "action_type": .string(proposal.actionType.rawValue)
            ])
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

    private func clearLocalAccountState(message: String) {
        hasCompletedOnboarding = false
        selectedTab = .today
        profile = .sample
        profilePhotoData = nil
        goal = .sample
        workouts = []
        meals = []
        commands = []
        friends = []
        friendSearchResults = []
        incomingFriendRequests = []
        outgoingFriendRequests = []
        proofPosts = []
        proofMediaData = [:]
        selectedSocialProfile = nil
        socialStatusMessage = nil
        accountabilityEnabled = false
        authSession = nil
        apiClient.authToken = nil
        apiClient.refreshToken = nil
        isPremium = false
        Task {
            await purchaseService.logOut()
        }
        purchaseService.clearLocalEntitlementState()
        isProcessingCommand = false
        commandProcessingMessage = nil
        isVoicePromptActive = false
        authStatusMessage = message + " Sign in with Apple to start again."
        lastSyncMessage = nil
        UserDefaults.standard.removeObject(forKey: snapshotKey)
        saveSnapshot()
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
        apiClient.refreshToken = snapshot.authSession?.refreshToken
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
        apiClient.refreshToken = authSession?.refreshToken
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
