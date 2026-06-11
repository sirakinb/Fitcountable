import CryptoKit
import Foundation

@MainActor
protocol FitcountableAPI {
    func parseCommand(text: String, context: AICommandContext) async throws -> ActionProposal
    func createVoiceSession() async throws -> VoiceSession
    func transcribeVoiceRecording(audioData: Data, mimeType: String) async throws -> VoiceTranscription
    func signIn(email: String, password: String) async throws -> AuthSession
    func signInWithApple(userIdentifier: String, email: String?, displayName: String, identityToken: String?, authorizationCode: String?) async throws -> AuthSession
    func confirmAction(rawText: String, proposal: ActionProposal) async throws -> ActionConfirmation
    func searchUsers(query: String) async throws -> [FriendSearchResult]
    func bootstrapProfile(displayName: String, goalType: GoalType, privacyMode: PrivacyMode, avatarData: Data?) async throws -> FriendSearchResult
    func friendsList() async throws -> FriendsListResponse
    func followUser(targetUserId: String) async throws -> SocialActionResult
    func respondFollow(userId: String, action: String) async throws -> SocialActionResult
    func createProofPost(workoutId: String?, mealId: String?, caption: String, visibility: Visibility, proofKind: String, detailLines: [String], photoData: Data?) async throws -> SocialProofPost
    func removeProofMedia(postId: String) async throws -> SocialActionResult
    func deleteProofPost(postId: String) async throws -> SocialActionResult
    func proofMediaData(from mediaURL: String) async throws -> Data
    func proofFeed(targetUserId: String?) async throws -> [SocialProofPost]
    func profileView(targetUserId: String) async throws -> SocialProfileView
    func sendNudge(to friend: FriendProfile, message: String) async throws -> NudgeResult
    func setAccountabilitySettings(enabled: Bool, visibility: Visibility) async throws -> SocialActionResult
    func deleteAccount() async throws -> SocialActionResult
}

enum APIError: LocalizedError {
    case unavailable
    case unauthenticated
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Fitcountable AI is temporarily unavailable. Your command was not lost."
        case .unauthenticated:
            "Your account session expired. Sign in with Apple again."
        case .serverMessage(let message):
            message
        }
    }
}

struct LocalMockAPI: FitcountableAPI {
    func createVoiceSession() async throws -> VoiceSession {
        throw APIError.unavailable
    }

    func transcribeVoiceRecording(audioData: Data, mimeType: String) async throws -> VoiceTranscription {
        throw APIError.unavailable
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        throw APIError.unauthenticated
    }

    func signInWithApple(userIdentifier: String, email: String?, displayName: String, identityToken: String?, authorizationCode: String?) async throws -> AuthSession {
        throw APIError.unauthenticated
    }

    func confirmAction(rawText: String, proposal: ActionProposal) async throws -> ActionConfirmation {
        throw APIError.unauthenticated
    }

    func searchUsers(query: String) async throws -> [FriendSearchResult] {
        throw APIError.unauthenticated
    }

    func bootstrapProfile(displayName: String, goalType: GoalType, privacyMode: PrivacyMode, avatarData: Data?) async throws -> FriendSearchResult {
        throw APIError.unauthenticated
    }

    func friendsList() async throws -> FriendsListResponse {
        throw APIError.unauthenticated
    }

    func followUser(targetUserId: String) async throws -> SocialActionResult {
        throw APIError.unauthenticated
    }

    func respondFollow(userId: String, action: String) async throws -> SocialActionResult {
        throw APIError.unauthenticated
    }

    func createProofPost(workoutId: String?, mealId: String?, caption: String, visibility: Visibility, proofKind: String, detailLines: [String], photoData: Data?) async throws -> SocialProofPost {
        throw APIError.unauthenticated
    }

    func removeProofMedia(postId: String) async throws -> SocialActionResult {
        throw APIError.unauthenticated
    }

    func deleteProofPost(postId: String) async throws -> SocialActionResult {
        throw APIError.unauthenticated
    }

    func proofMediaData(from mediaURL: String) async throws -> Data {
        throw APIError.unauthenticated
    }

    func proofFeed(targetUserId: String?) async throws -> [SocialProofPost] {
        []
    }

    func profileView(targetUserId: String) async throws -> SocialProfileView {
        throw APIError.unauthenticated
    }

    func sendNudge(to friend: FriendProfile, message: String) async throws -> NudgeResult {
        throw APIError.unauthenticated
    }

    func setAccountabilitySettings(enabled: Bool, visibility: Visibility) async throws -> SocialActionResult {
        throw APIError.unauthenticated
    }

    func deleteAccount() async throws -> SocialActionResult {
        throw APIError.unauthenticated
    }

    func parseCommand(text: String, context: AICommandContext) async throws -> ActionProposal {
        try await Task.sleep(for: .milliseconds(350))
        let lower = text.lowercased()

        if lower.contains("bench") || lower.contains("workout") || lower.contains("push") || lower.contains("pull") || lower.contains("squat") {
            return ActionProposal(
                actionType: .logWorkout,
                confidence: 0.88,
                requiresConfirmation: true,
                summary: "Parsed a strength workout from your command. Review the sets before saving.",
                title: lower.contains("push") ? "Push Day" : "Workout",
                mealType: nil,
                calories: nil,
                protein: nil,
                carbs: nil,
                fat: nil,
                weeklyWorkouts: nil,
                durationMinutes: 55,
                targetFriendId: nil,
                workoutSets: [
                    WorkoutSet(exerciseName: "Bench Press", setIndex: 1, reps: 5, weight: 185, rpe: 8),
                    WorkoutSet(exerciseName: "Incline Dumbbell Press", setIndex: 2, reps: 10, weight: 60, rpe: 7),
                    WorkoutSet(exerciseName: "Triceps Pushdown", setIndex: 3, reps: 12, weight: 70, rpe: nil)
                ],
                foodItems: [],
                assumptions: ["Grouped similar exercise phrases into one workout."],
                missingFields: []
            )
        }

        if lower.contains("nudge") || lower.contains("accountable") {
            return ActionProposal(
                actionType: .createAccountabilityNudge,
                confidence: 0.82,
                requiresConfirmation: true,
                summary: "Created an accountability nudge draft for your selected partner.",
                title: nil,
                mealType: nil,
                calories: nil,
                protein: nil,
                carbs: nil,
                fat: nil,
                weeklyWorkouts: nil,
                durationMinutes: nil,
                targetFriendId: FriendProfile.samples.first?.id,
                workoutSets: [],
                foodItems: [],
                assumptions: ["Defaulted to your first accountability partner."],
                missingFields: []
            )
        }

        return ActionProposal(
            actionType: .logMeal,
            confidence: 0.78,
            requiresConfirmation: true,
            summary: "Estimated this meal from description. Edit portions if needed before saving.",
            title: "Estimated meal",
            mealType: .lunch,
            calories: nil,
            protein: nil,
            carbs: nil,
            fat: nil,
            weeklyWorkouts: nil,
            durationMinutes: nil,
            targetFriendId: nil,
            workoutSets: [],
            foodItems: [
                FoodItem(name: text, quantityText: "1 described serving", calories: 0, protein: 0, carbs: 0, fat: 0, confidence: 0.45)
            ],
            assumptions: ["Connection fallback used. Add calories/macros manually or retry the AI estimate."],
            missingFields: []
        )
    }
}

final class RemoteFitcountableAPI: FitcountableAPI {
    var functionBaseURL: URL
    var apiBaseURL: URL
    var fallback: FitcountableAPI
    var authToken: String?
    var refreshToken: String?
    var onSessionRefreshed: ((AuthSession) -> Void)?

    init(functionBaseURL: URL, apiBaseURL: URL, fallback: FitcountableAPI) {
        self.functionBaseURL = functionBaseURL
        self.apiBaseURL = apiBaseURL
        self.fallback = fallback
    }

    func parseCommand(text: String, context: AICommandContext) async throws -> ActionProposal {
        var request = URLRequest(url: functionBaseURL.appending(path: "parse-command"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder.fitcountable.encode(RemoteParseRequest(text: text, context: context))

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return try await fallback.parseCommand(text: text, context: context)
            }
            return try JSONDecoder.fitcountable.decode(RemoteActionProposal.self, from: data).actionProposal
        } catch {
            return try await fallback.parseCommand(text: text, context: context)
        }
    }

    func createVoiceSession() async throws -> VoiceSession {
        var request = URLRequest(url: functionBaseURL.appending(path: "deepgram-token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.unavailable
        }
        return try JSONDecoder.fitcountable.decode(VoiceSession.self, from: data)
    }

    func transcribeVoiceRecording(audioData: Data, mimeType: String) async throws -> VoiceTranscription {
        var request = URLRequest(url: functionBaseURL.appending(path: "transcribe-audio"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder.fitcountable.encode(VoiceTranscriptionRequest(
            audioBase64: audioData.base64EncodedString(),
            mimeType: mimeType
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw decodedError(from: data) ?? APIError.unavailable
        }
        return try JSONDecoder.fitcountable.decode(VoiceTranscription.self, from: data)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        var components = URLComponents(url: apiBaseURL.appending(path: "auth/sessions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "client_type", value: "mobile")]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.fitcountable.encode(SignInRequest(email: email, password: password))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw decodedError(from: data) ?? APIError.unavailable
        }
        let result = try JSONDecoder.fitcountable.decode(SignInResponse.self, from: data)
        guard let accessToken = result.accessToken else {
            throw APIError.unauthenticated
        }
        authToken = accessToken
        refreshToken = result.refreshToken
        return AuthSession(
            userId: result.user.id,
            email: result.user.email,
            accessToken: accessToken,
            refreshToken: result.refreshToken
        )
    }

    func signInWithApple(userIdentifier: String, email: String?, displayName: String, identityToken: String?, authorizationCode: String?) async throws -> AuthSession {
        let accounts = appleAccountCandidates(userIdentifier: userIdentifier)
        for account in accounts {
            if var session = try? await signIn(email: account.email, password: account.password) {
                if let email {
                    session.email = email
                }
                return session
            }
        }

        let primary = accounts[0]
        let registerResponse = try await register(email: primary.email, password: primary.password, name: displayName)
        guard let accessToken = registerResponse.accessToken else {
            throw APIError.unauthenticated
        }
        authToken = accessToken
        refreshToken = registerResponse.refreshToken
        return AuthSession(
            userId: registerResponse.user.id,
            email: email ?? registerResponse.user.email,
            accessToken: accessToken,
            refreshToken: registerResponse.refreshToken
        )
    }

    private func register(email: String, password: String, name: String) async throws -> SignInResponse {
        var components = URLComponents(url: apiBaseURL.appending(path: "auth/users"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "client_type", value: "mobile")]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.fitcountable.encode(RegisterUserRequest(email: email, password: password, name: name))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw decodedError(from: data) ?? APIError.unavailable
        }
        return try JSONDecoder.fitcountable.decode(SignInResponse.self, from: data)
    }

    private func appleAccountCandidates(userIdentifier: String) -> [(email: String, password: String)] {
        let digest = SHA256.hash(data: Data(userIdentifier.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let password = "FitcountableApple-\(hex)"
        return [
            ("apple-\(hex.prefix(24))@users.fitcountable.app", password),
            ("apple-\(hex.prefix(24))@fitcountable.local", password)
        ]
    }

    func confirmAction(rawText: String, proposal: ActionProposal) async throws -> ActionConfirmation {
        guard let authToken else {
            return try await fallback.confirmAction(rawText: rawText, proposal: proposal)
        }

        var request = URLRequest(url: functionBaseURL.appending(path: "confirm-action"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.fitcountable.encode(ConfirmActionRequest(rawText: rawText, proposal: proposal))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.unavailable
        }
        return try JSONDecoder.fitcountable.decode(ActionConfirmation.self, from: data)
    }

    func searchUsers(query: String) async throws -> [FriendSearchResult] {
        guard let authToken else {
            return try await fallback.searchUsers(query: query)
        }

        var request = URLRequest(url: functionBaseURL.appending(path: "search-users"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.fitcountable.encode(SearchUsersRequest(query: query))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return try await fallback.searchUsers(query: query)
        }
        return try JSONDecoder.fitcountable.decode(SearchUsersResponse.self, from: data).users
    }

    func bootstrapProfile(displayName: String, goalType: GoalType, privacyMode: PrivacyMode, avatarData: Data? = nil) async throws -> FriendSearchResult {
        guard let authToken else {
            return try await fallback.bootstrapProfile(displayName: displayName, goalType: goalType, privacyMode: privacyMode, avatarData: avatarData)
        }
        let response: BootstrapProfileResponse = try await postFunction(
            "bootstrap-profile",
            token: authToken,
            body: BootstrapProfileRequest(displayName: displayName, goalType: goalType.rawValue, privacyMode: privacyMode.remoteValue, avatarURL: avatarData?.jpegDataURLString)
        )
        return response.profile
    }

    func friendsList() async throws -> FriendsListResponse {
        guard let authToken else {
            return try await fallback.friendsList()
        }
        return try await postFunction("friends-list", token: authToken, body: EmptyRequest())
    }

    func followUser(targetUserId: String) async throws -> SocialActionResult {
        guard let authToken else {
            return try await fallback.followUser(targetUserId: targetUserId)
        }
        let response: SocialResultResponse = try await postFunction("follow-user", token: authToken, body: TargetUserRequest(targetUserId: targetUserId))
        return response.result
    }

    func respondFollow(userId: String, action: String) async throws -> SocialActionResult {
        guard let authToken else {
            return try await fallback.respondFollow(userId: userId, action: action)
        }
        let response: SocialResultResponse = try await postFunction("respond-follow", token: authToken, body: RespondFollowRequest(followerId: userId, action: action))
        return response.result
    }

    func createProofPost(workoutId: String?, mealId: String?, caption: String, visibility: Visibility, proofKind: String, detailLines: [String], photoData: Data?) async throws -> SocialProofPost {
        guard let authToken else {
            return try await fallback.createProofPost(workoutId: workoutId, mealId: mealId, caption: caption, visibility: visibility, proofKind: proofKind, detailLines: detailLines, photoData: photoData)
        }
        let media = try await uploadProofMedia(photoData, token: authToken)
        let mediaURL = media.flatMap { resolvedURL(from: $0.url)?.absoluteString } ?? media?.url
        let response: CreateProofPostResponse = try await postFunction(
            "create-proof-post",
            token: authToken,
            body: CreateProofPostRequest(
                workoutId: workoutId,
                mealId: mealId,
                caption: caption,
                visibility: visibility.remoteValue,
                proofKind: proofKind,
                detailLines: detailLines,
                mediaURL: mediaURL,
                mediaType: media?.mimeType
            )
        )
        return response.proofPost
    }

    func removeProofMedia(postId: String) async throws -> SocialActionResult {
        guard let authToken else {
            return try await fallback.removeProofMedia(postId: postId)
        }
        let response: SocialResultResponse = try await postFunction("remove-proof-media", token: authToken, body: ProofPostIdRequest(postId: postId))
        return response.result
    }

    func deleteProofPost(postId: String) async throws -> SocialActionResult {
        guard let authToken else {
            return try await fallback.deleteProofPost(postId: postId)
        }
        let response: SocialResultResponse = try await postFunction("delete-proof-post", token: authToken, body: ProofPostIdRequest(postId: postId))
        return response.result
    }

    func proofMediaData(from mediaURL: String) async throws -> Data {
        guard let authToken else {
            throw APIError.unauthenticated
        }
        if let data = URL(string: mediaURL)?.dataURLImageData {
            return data
        }

        let objectKey = storageObjectKey(from: mediaURL)
        let strategyURL = apiBaseURL.appending(path: "storage/buckets/proof-media/objects/\(objectKey)/download-strategy")
        var strategyRequest = URLRequest(url: strategyURL)
        strategyRequest.httpMethod = "POST"
        strategyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        strategyRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        strategyRequest.httpBody = try JSONEncoder.fitcountable.encode(StorageDownloadStrategyRequest(expiresIn: 3600))

        var activeToken = authToken
        var (strategyData, strategyResponse) = try await URLSession.shared.data(for: strategyRequest)
        if isUnauthorized(strategyResponse, data: strategyData) {
            activeToken = try await refreshAuthToken()
            strategyRequest.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
            (strategyData, strategyResponse) = try await URLSession.shared.data(for: strategyRequest)
        }
        guard let strategyHTTP = strategyResponse as? HTTPURLResponse, (200..<300).contains(strategyHTTP.statusCode) else {
            throw decodedError(from: strategyData) ?? APIError.unavailable
        }
        let strategy = try JSONDecoder.fitcountable.decode(StorageDownloadStrategy.self, from: strategyData)
        guard let downloadURL = resolvedURL(from: strategy.url) else {
            throw APIError.unavailable
        }

        var downloadRequest = URLRequest(url: downloadURL)
        if downloadURL.host == apiBaseURL.host {
            downloadRequest.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: downloadRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.unavailable
        }
        return data
    }

    func proofFeed(targetUserId: String? = nil) async throws -> [SocialProofPost] {
        guard let authToken else {
            return try await fallback.proofFeed(targetUserId: targetUserId)
        }
        let response: ProofFeedResponse = try await postFunction("proof-feed", token: authToken, body: ProofFeedRequest(targetUserId: targetUserId))
        return response.proofPosts
    }

    func profileView(targetUserId: String) async throws -> SocialProfileView {
        guard let authToken else {
            return try await fallback.profileView(targetUserId: targetUserId)
        }
        return try await postFunction("profile-view", token: authToken, body: TargetUserRequest(targetUserId: targetUserId))
    }

    func sendNudge(to friend: FriendProfile, message: String) async throws -> NudgeResult {
        guard let authToken, let targetId = friend.remoteUserId else {
            return try await fallback.sendNudge(to: friend, message: message)
        }

        var request = URLRequest(url: functionBaseURL.appending(path: "send-nudge"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.fitcountable.encode(SendNudgeRequest(targetUserId: targetId, message: message))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return try await fallback.sendNudge(to: friend, message: message)
        }
        return try JSONDecoder.fitcountable.decode(NudgeResult.self, from: data)
    }

    func setAccountabilitySettings(enabled: Bool, visibility: Visibility) async throws -> SocialActionResult {
        guard let authToken else {
            return try await fallback.setAccountabilitySettings(enabled: enabled, visibility: visibility)
        }
        let response: AccountabilitySettingsResponse = try await postFunction(
            "set-accountability-settings",
            token: authToken,
            body: AccountabilitySettingsRequest(enabled: enabled, visibilityScope: visibility.remoteValue, proofRequired: false)
        )
        return SocialActionResult(ok: response.settings.ok, status: response.settings.enabled ? "enabled" : "disabled")
    }

    func deleteAccount() async throws -> SocialActionResult {
        guard let authToken else {
            return try await fallback.deleteAccount()
        }
        let response: SocialResultResponse = try await postFunction("delete-account", token: authToken, body: EmptyRequest())
        return response.result
    }

    private func postFunction<RequestBody: Encodable, ResponseBody: Decodable>(_ slug: String, token: String, body: RequestBody) async throws -> ResponseBody {
        var request = URLRequest(url: functionBaseURL.appending(path: slug))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.fitcountable.encode(body)

        var (data, response) = try await URLSession.shared.data(for: request)
        if isUnauthorized(response, data: data) {
            let refreshedToken = try await refreshAuthToken()
            request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: request)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw decodedError(from: data) ?? APIError.unavailable
        }
        return try JSONDecoder.fitcountable.decode(ResponseBody.self, from: data)
    }

    private func uploadProofMedia(_ photoData: Data?, token: String) async throws -> StorageUploadResult? {
        guard let photoData else { return nil }

        let filename = "proof-\(UUID().uuidString).jpg"
        var strategyRequest = URLRequest(url: apiBaseURL.appending(path: "storage/buckets/proof-media/upload-strategy"))
        strategyRequest.httpMethod = "POST"
        strategyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        strategyRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        strategyRequest.httpBody = try JSONEncoder.fitcountable.encode(StorageUploadStrategyRequest(filename: filename, contentType: "image/jpeg", size: photoData.count))

        var activeToken = token
        var (strategyData, strategyResponse) = try await URLSession.shared.data(for: strategyRequest)
        if isUnauthorized(strategyResponse, data: strategyData) {
            activeToken = try await refreshAuthToken()
            strategyRequest.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
            (strategyData, strategyResponse) = try await URLSession.shared.data(for: strategyRequest)
        }
        guard let strategyHTTP = strategyResponse as? HTTPURLResponse, (200..<300).contains(strategyHTTP.statusCode) else {
            throw decodedError(from: strategyData) ?? APIError.unavailable
        }
        let strategy = try JSONDecoder.fitcountable.decode(StorageUploadStrategy.self, from: strategyData)
        let uploadResponse = try await uploadMultipartImage(photoData, strategy: strategy, token: activeToken, filename: filename)

        if strategy.confirmRequired, let confirmURL = strategy.confirmUrl {
            var confirmRequest = URLRequest(url: resolvedURL(from: confirmURL) ?? apiBaseURL.appending(path: "storage/buckets/proof-media/objects/\(strategy.key)/confirm-upload"))
            confirmRequest.httpMethod = "POST"
            confirmRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            confirmRequest.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
            confirmRequest.httpBody = try JSONEncoder.fitcountable.encode(StorageConfirmUploadRequest(size: photoData.count, contentType: "image/jpeg"))
            var (confirmData, confirmResponse) = try await URLSession.shared.data(for: confirmRequest)
            if isUnauthorized(confirmResponse, data: confirmData) {
                activeToken = try await refreshAuthToken()
                confirmRequest.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
                (confirmData, confirmResponse) = try await URLSession.shared.data(for: confirmRequest)
            }
            guard let confirmHTTP = confirmResponse as? HTTPURLResponse, (200..<300).contains(confirmHTTP.statusCode) else {
                throw decodedError(from: confirmData) ?? APIError.unavailable
            }
            return try JSONDecoder.fitcountable.decode(StorageUploadResult.self, from: confirmData)
        }

        return uploadResponse ?? StorageUploadResult(bucket: "proof-media", key: strategy.key, size: photoData.count, mimeType: "image/jpeg", uploadedAt: nil, url: "/api/storage/buckets/proof-media/objects/\(strategy.key)")
    }

    private func refreshAuthToken() async throws -> String {
        guard let refreshToken, refreshToken.isEmpty == false else {
            throw APIError.unauthenticated
        }
        var components = URLComponents(url: apiBaseURL.appending(path: "auth/refresh"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "client_type", value: "mobile")]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.fitcountable.encode(RefreshSessionRequest(refreshToken: refreshToken))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw decodedError(from: data) ?? APIError.unauthenticated
        }
        let result = try JSONDecoder.fitcountable.decode(SignInResponse.self, from: data)
        guard let accessToken = result.accessToken else {
            throw APIError.unauthenticated
        }
        let nextRefreshToken = result.refreshToken ?? refreshToken
        authToken = accessToken
        self.refreshToken = nextRefreshToken
        let session = AuthSession(
            userId: result.user.id,
            email: result.user.email,
            accessToken: accessToken,
            refreshToken: nextRefreshToken
        )
        onSessionRefreshed?(session)
        return accessToken
    }

    private func isUnauthorized(_ response: URLResponse, data: Data) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        if http.statusCode == 401 { return true }
        guard let remote = try? JSONDecoder.fitcountable.decode(RemoteErrorResponse.self, from: data) else {
            return false
        }
        return remote.statusCode == 401 || remote.error == "AUTH_UNAUTHORIZED"
    }

    private func uploadMultipartImage(_ data: Data, strategy: StorageUploadStrategy, token: String, filename: String) async throws -> StorageUploadResult? {
        guard let uploadURL = resolvedURL(from: strategy.uploadUrl) else {
            throw APIError.unavailable
        }
        let boundary = "FitcountableBoundary-\(UUID().uuidString)"
        let multipart = multipartFormData(
            boundary: boundary,
            fields: strategy.fields ?? [:],
            fileFieldName: "file",
            filename: filename,
            mimeType: "image/jpeg",
            fileData: data
        )

        var request = URLRequest(url: uploadURL)
        request.httpMethod = strategy.method == "presigned" ? "POST" : "PUT"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if strategy.method != "presigned" {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = multipart

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw decodedError(from: responseData) ?? APIError.unavailable
        }
        if responseData.isEmpty {
            return nil
        }
        return try? JSONDecoder.fitcountable.decode(StorageUploadResult.self, from: responseData)
    }

    private func resolvedURL(from value: String) -> URL? {
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        guard let root = URL(string: "\(apiBaseURL.scheme ?? "https")://\(apiBaseURL.host ?? "")") else {
            return nil
        }
        return URL(string: value, relativeTo: root)?.absoluteURL
    }

    private func storageObjectKey(from mediaURL: String) -> String {
        if let url = URL(string: mediaURL), let range = url.path.range(of: "/api/storage/buckets/proof-media/objects/") {
            return String(url.path[range.upperBound...])
        }
        let marker = "/api/storage/buckets/proof-media/objects/"
        if let range = mediaURL.range(of: marker) {
            return String(mediaURL[range.upperBound...])
        }
        return mediaURL
    }
}

private func decodedError(from data: Data) -> APIError? {
    guard let response = try? JSONDecoder.fitcountable.decode(RemoteErrorResponse.self, from: data) else {
        return nil
    }
    if response.statusCode == 401 || response.error == "AUTH_UNAUTHORIZED" {
        return .unauthenticated
    }
    if let message = response.message, message.isEmpty == false {
        return .serverMessage(message)
    }
    if let detail = response.detail, detail.isEmpty == false {
        return .serverMessage("\(response.error): \(detail)")
    }
    return .serverMessage(response.error)
}

struct VoiceSession: Codable, Equatable {
    var accessToken: String
    var expiresIn: Int
}

struct VoiceTranscription: Codable, Equatable {
    var transcript: String
}

private struct VoiceTranscriptionRequest: Encodable {
    var audioBase64: String
    var mimeType: String
}

private struct RemoteErrorResponse: Decodable {
    var error: String
    var message: String?
    var detail: String?
    var statusCode: Int?
}

private struct RemoteParseRequest: Encodable {
    var text: String
    var context: AICommandContext
}

private struct SignInRequest: Encodable {
    var email: String
    var password: String
}

private struct RefreshSessionRequest: Encodable {
    var refreshToken: String
}

private struct RegisterUserRequest: Encodable {
    var email: String
    var password: String
    var name: String
}

private struct SignInResponse: Decodable {
    var user: SignInUser
    var accessToken: String?
    var refreshToken: String?
}

private struct SignInUser: Decodable {
    var id: String
    var email: String
}

private struct ConfirmActionRequest: Encodable {
    var rawText: String
    var proposal: ActionProposal
}

private struct SearchUsersRequest: Encodable {
    var query: String
}

private struct SearchUsersResponse: Decodable {
    var users: [FriendSearchResult]
}

private struct SendNudgeRequest: Encodable {
    var targetUserId: String
    var message: String
}

private struct EmptyRequest: Encodable {}

private struct BootstrapProfileRequest: Encodable {
    var displayName: String
    var goalType: String
    var privacyMode: String
    var avatarURL: String?
}

private struct BootstrapProfileResponse: Decodable {
    var profile: FriendSearchResult
}

private struct TargetUserRequest: Encodable {
    var targetUserId: String
}

private struct RespondFollowRequest: Encodable {
    var followerId: String
    var action: String
}

private struct ProofPostIdRequest: Encodable {
    var postId: String
}

struct SocialActionResult: Codable, Equatable {
    var ok: Bool
    var status: String
}

private struct SocialResultResponse: Decodable {
    var result: SocialActionResult
}

private struct CreateProofPostRequest: Encodable {
    var workoutId: String?
    var mealId: String?
    var caption: String
    var visibility: String
    var proofKind: String
    var detailLines: [String]
    var mediaURL: String?
    var mediaType: String?
}

private struct CreateProofPostResponse: Decodable {
    var proofPost: SocialProofPost

    enum CodingKeys: String, CodingKey {
        case proofPost = "proof_post"
    }
}

private struct ProofFeedRequest: Encodable {
    var targetUserId: String?
}

private struct ProofFeedResponse: Decodable {
    var proofPosts: [SocialProofPost]

    enum CodingKeys: String, CodingKey {
        case proofPosts = "proof_posts"
    }
}

private struct StorageUploadStrategyRequest: Encodable {
    var filename: String
    var contentType: String
    var size: Int
}

private struct StorageUploadStrategy: Decodable {
    var method: String
    var uploadUrl: String
    var fields: [String: String]?
    var key: String
    var confirmRequired: Bool
    var confirmUrl: String?
}

private struct StorageConfirmUploadRequest: Encodable {
    var size: Int
    var contentType: String
}

private struct StorageUploadResult: Decodable {
    var bucket: String?
    var key: String
    var size: Int?
    var mimeType: String?
    var uploadedAt: String?
    var url: String
}

private struct StorageDownloadStrategyRequest: Encodable {
    var expiresIn: Int
}

private struct StorageDownloadStrategy: Decodable {
    var method: String
    var url: String
    var expiresAt: String?
}

struct NudgeResult: Codable, Equatable {
    var ok: Bool
    var status: String
}

private struct AccountabilitySettingsRequest: Encodable {
    var enabled: Bool
    var visibilityScope: String
    var proofRequired: Bool
}

private struct AccountabilitySettingsResponse: Decodable {
    var settings: AccountabilitySettingsResult
}

private struct AccountabilitySettingsResult: Decodable {
    var ok: Bool
    var enabled: Bool
    var visibilityScope: String
    var proofRequired: Bool
}

private struct RemoteActionProposal: Decodable {
    var actionType: ActionType
    var confidence: Double
    var requiresConfirmation: Bool
    var summary: String
    var title: String?
    var mealTypeRaw: String?
    var calories: Int?
    var protein: Int?
    var carbs: Int?
    var fat: Int?
    var weeklyWorkouts: Int?
    var durationMinutes: Int?
    var targetFriendIdRaw: String?
    var workoutSets: [RemoteWorkoutSet]
    var foodItems: [RemoteFoodItem]
    var assumptions: [String]
    var missingFields: [String]

    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case confidence
        case requiresConfirmation = "requires_confirmation"
        case summary
        case title
        case mealTypeRaw = "meal_type"
        case calories
        case protein
        case carbs
        case fat
        case weeklyWorkouts = "weekly_workouts"
        case durationMinutes = "duration_minutes"
        case targetFriendIdRaw = "target_friend_id"
        case workoutSets = "workout_sets"
        case foodItems = "food_items"
        case assumptions
        case missingFields = "missing_fields"
    }

    var actionProposal: ActionProposal {
        ActionProposal(
            actionType: actionType,
            confidence: confidence,
            requiresConfirmation: requiresConfirmation,
            summary: summary,
            title: title,
            mealType: mealTypeRaw.flatMap(MealType.remoteValue),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            weeklyWorkouts: weeklyWorkouts,
            durationMinutes: durationMinutes,
            targetFriendId: targetFriendIdRaw.flatMap(UUID.init(uuidString:)),
            workoutSets: workoutSets.map(\.workoutSet),
            foodItems: foodItems.map(\.foodItem),
            assumptions: assumptions,
            missingFields: missingFields
        )
    }
}

private extension MealType {
    static func remoteValue(_ value: String) -> MealType? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "breakfast":
            .breakfast
        case "lunch":
            .lunch
        case "dinner":
            .dinner
        case "snack", "snacks":
            .snack
        default:
            nil
        }
    }
}

private struct RemoteWorkoutSet: Decodable {
    var exerciseName: String
    var setIndex: Int
    var reps: Int
    var weight: Double
    var rpe: Double?

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case setIndex = "set_index"
        case reps
        case weight
        case rpe
    }

    var workoutSet: WorkoutSet {
        WorkoutSet(exerciseName: exerciseName, setIndex: setIndex, reps: reps, weight: weight, rpe: rpe)
    }
}

private struct RemoteFoodItem: Decodable {
    var name: String
    var quantityText: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case name
        case quantityText = "quantity_text"
        case calories
        case protein = "protein_g"
        case carbs = "carbs_g"
        case fat = "fat_g"
        case confidence
    }

    var foodItem: FoodItem {
        FoodItem(name: name, quantityText: quantityText, calories: calories, protein: protein, carbs: carbs, fat: fat, confidence: confidence)
    }
}

private func multipartFormData(
    boundary: String,
    fields: [String: String],
    fileFieldName: String,
    filename: String,
    mimeType: String,
    fileData: Data
) -> Data {
    var data = Data()

    for (name, value) in fields {
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        data.appendString("\(value)\r\n")
    }

    data.appendString("--\(boundary)\r\n")
    data.appendString("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(filename)\"\r\n")
    data.appendString("Content-Type: \(mimeType)\r\n\r\n")
    data.append(fileData)
    data.appendString("\r\n")
    data.appendString("--\(boundary)--\r\n")

    return data
}

extension JSONEncoder {
    static var fitcountable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var fitcountable: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension Data {
    var jpegDataURLString: String {
        "data:image/jpeg;base64,\(base64EncodedString())"
    }

    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
