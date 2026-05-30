import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var displayName: String
    var goalType: GoalType
    var trainingExperience: String
    var activityLevel: String
    var privacyMode: PrivacyMode

    static let sample = UserProfile(
        displayName: "Barack",
        goalType: .recomp,
        trainingExperience: "Intermediate",
        activityLevel: "Lifts 4 days/week",
        privacyMode: .privateProfile
    )
}

struct AuthSession: Codable, Equatable {
    var userId: String
    var email: String
    var accessToken: String
    var refreshToken: String?
}

enum GoalType: String, CaseIterable, Codable, Identifiable {
    case loseFat = "Lose fat"
    case buildMuscle = "Build muscle"
    case maintain = "Maintain"
    case recomp = "Recomp"
    case consistency = "Consistency"

    var id: String { rawValue }
}

enum PrivacyMode: String, CaseIterable, Codable {
    case privateProfile = "Private"
    case friendsOnly = "Friends only"
    case publicProfile = "Public"

    var remoteValue: String {
        switch self {
        case .privateProfile: "private"
        case .friendsOnly: "friends"
        case .publicProfile: "public"
        }
    }
}

struct GoalPlan: Codable, Equatable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var weeklyWorkouts: Int
    var targetPace: String

    static let sample = GoalPlan(calories: 2450, protein: 185, carbs: 260, fat: 75, weeklyWorkouts: 4, targetPace: "Steady recomp")

    func updated(from proposal: ActionProposal) -> GoalPlan {
        GoalPlan(
            calories: proposal.calories ?? calories,
            protein: proposal.protein ?? protein,
            carbs: proposal.carbs ?? carbs,
            fat: proposal.fat ?? fat,
            weeklyWorkouts: proposal.weeklyWorkouts ?? weeklyWorkouts,
            targetPace: proposal.summary
        )
    }
}

struct WorkoutLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var startedAt: Date
    var durationMinutes: Int
    var source: LogSource
    var notes: String
    var visibility: Visibility
    var sets: [WorkoutSet]

    static let samples = [
        WorkoutLog(title: "Push Day", startedAt: .now, durationMinutes: 58, source: .ai, notes: "Felt strong.", visibility: .friends, sets: [
            WorkoutSet(exerciseName: "Bench Press", setIndex: 1, reps: 5, weight: 185, rpe: 8),
            WorkoutSet(exerciseName: "Incline Dumbbell Press", setIndex: 2, reps: 10, weight: 60, rpe: 7)
        ])
    ]

    static func fromProposal(_ proposal: ActionProposal) -> WorkoutLog {
        WorkoutLog(
            title: proposal.title ?? "Workout",
            startedAt: .now,
            durationMinutes: proposal.durationMinutes ?? 45,
            source: .ai,
            notes: proposal.summary,
            visibility: .friends,
            sets: proposal.workoutSets
        )
    }

    var compactSetSummaries: [String] {
        guard sets.isEmpty == false else { return [] }
        var groups: [WorkoutSetGroup] = []
        for set in sets.sorted(by: { $0.setIndex < $1.setIndex }) {
            if groups.last?.canAppend(set) == true {
                groups[groups.count - 1].append(set)
            } else {
                groups.append(WorkoutSetGroup(set: set))
            }
        }
        return groups.map(\.displayText)
    }
}

struct WorkoutSet: Identifiable, Codable, Equatable {
    var id = UUID()
    var exerciseName: String
    var setIndex: Int
    var reps: Int
    var weight: Double
    var rpe: Double?
}

private struct WorkoutSetGroup {
    var exerciseName: String
    var reps: Int
    var weight: Double
    var indexes: [Int]

    init(set: WorkoutSet) {
        exerciseName = set.exerciseName
        reps = set.reps
        weight = set.weight
        indexes = [set.setIndex]
    }

    mutating func append(_ set: WorkoutSet) {
        indexes.append(set.setIndex)
    }

    func canAppend(_ set: WorkoutSet) -> Bool {
        exerciseName.caseInsensitiveCompare(set.exerciseName) == .orderedSame
            && reps == set.reps
            && abs(weight - set.weight) < 0.01
    }

    var displayText: String {
        "\(setLabel) · \(exerciseName) · \(reps) reps\(weightText)"
    }

    private var setLabel: String {
        guard let first = indexes.first, let last = indexes.last else { return "Set" }
        if indexes.count == 1 { return "Set \(first)" }
        return indexesAreConsecutive ? "Sets \(first)-\(last)" : "Sets \(indexes.map(String.init).joined(separator: ", "))"
    }

    private var indexesAreConsecutive: Bool {
        guard indexes.count > 1 else { return true }
        return zip(indexes, indexes.dropFirst()).allSatisfy { current, next in
            next == current + 1
        }
    }

    private var weightText: String {
        guard weight > 0 else { return "" }
        let rounded = weight.rounded()
        let display = abs(weight - rounded) < 0.01 ? "\(Int(rounded))" : String(format: "%.1f", weight)
        return " · \(display) lb"
    }
}

struct MealLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var mealType: MealType
    var loggedAt: Date
    var source: LogSource
    var notes: String
    var items: [FoodItem]

    var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat } }

    static let samples = [
        MealLog(mealType: .breakfast, loggedAt: .now, source: .manual, notes: "Quick breakfast", items: [
            FoodItem(name: "Eggs", quantityText: "3 large", calories: 210, protein: 18, carbs: 2, fat: 15, confidence: 0.9),
            FoodItem(name: "Protein shake", quantityText: "1 serving", calories: 150, protein: 30, carbs: 4, fat: 2, confidence: 0.86)
        ])
    ]

    static func fromProposal(_ proposal: ActionProposal) -> MealLog {
        MealLog(
            mealType: proposal.mealType ?? .snack,
            loggedAt: .now,
            source: .ai,
            notes: proposal.summary,
            items: proposal.foodItems
        )
    }
}

struct FoodItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var quantityText: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: Double
}

enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }
}

enum LogSource: String, Codable {
    case manual
    case ai
}

enum Visibility: String, CaseIterable, Codable {
    case privateOnly = "Private"
    case friends = "Friends"
    case publicPost = "Public"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "private", "privateonly", "private_only":
            self = .privateOnly
        case "public", "publicpost", "public_post":
            self = .publicPost
        default:
            self = .friends
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .privateOnly:
            try container.encode("private")
        case .friends:
            try container.encode("friends")
        case .publicPost:
            try container.encode("public")
        }
    }

    var remoteValue: String {
        switch self {
        case .privateOnly: "private"
        case .friends: "friends"
        case .publicPost: "public"
        }
    }
}

struct FriendProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var remoteUserId: String?
    var name: String
    var streak: Int
    var status: String
    var lastNudge: String?

    static let samples = [
        FriendProfile(name: "Jordan", streak: 12, status: "Lifted yesterday", lastNudge: nil),
        FriendProfile(name: "Maya", streak: 5, status: "Needs a meal log", lastNudge: nil)
    ]

    func withNudge(_ message: String) -> FriendProfile {
        FriendProfile(id: id, remoteUserId: remoteUserId, name: name, streak: streak, status: status, lastNudge: message)
    }
}

struct FriendSearchResult: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var avatarURL: URL?
    var privacyMode: String
    var relationshipStatus: String?

    var friendProfile: FriendProfile {
        FriendProfile(remoteUserId: id, name: displayName, streak: 0, status: relationshipStatusLabel, lastNudge: nil)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case privacyMode = "privacy_mode"
        case relationshipStatus = "relationship_status"
    }

    var relationshipStatusLabel: String {
        switch relationshipStatus {
        case "accepted":
            "Approved friend"
        case "pending":
            "Request sent"
        case "requested_you":
            "Wants to follow you"
        default:
            "Not connected"
        }
    }
}

struct SocialProofPost: Identifiable, Codable, Equatable {
    var id: String
    var userId: String
    var displayName: String
    var avatarURL: URL?
    var workoutId: String?
    var mealId: String?
    var workoutTitle: String
    var durationMinutes: Int?
    var setCount: Int
    var caption: String?
    var visibility: Visibility
    var mediaURL: URL?
    var mediaType: String?
    var createdAt: String?
    var relationship: String
    var proofKind: String?
    var detailLines: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case workoutId = "workout_id"
        case mealId = "meal_id"
        case workoutTitle = "workout_title"
        case durationMinutes = "duration_minutes"
        case setCount = "set_count"
        case caption
        case visibility
        case mediaURL = "media_url"
        case mediaType = "media_type"
        case createdAt = "created_at"
        case relationship
        case proofKind = "proof_kind"
        case detailLines = "detail_lines"
    }

    init(
        id: String,
        userId: String,
        displayName: String,
        avatarURL: URL? = nil,
        workoutId: String? = nil,
        mealId: String? = nil,
        workoutTitle: String,
        durationMinutes: Int? = nil,
        setCount: Int = 0,
        caption: String? = nil,
        visibility: Visibility = .friends,
        mediaURL: URL? = nil,
        mediaType: String? = nil,
        createdAt: String? = nil,
        relationship: String = "own",
        proofKind: String? = nil,
        detailLines: [String]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.workoutId = workoutId
        self.mealId = mealId
        self.workoutTitle = workoutTitle
        self.durationMinutes = durationMinutes
        self.setCount = setCount
        self.caption = caption
        self.visibility = visibility
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.createdAt = createdAt
        self.relationship = relationship
        self.proofKind = proofKind
        self.detailLines = detailLines
    }
}

struct FriendsListResponse: Codable, Equatable {
    var friends: [FriendSearchResult]
    var incoming: [FriendSearchResult]
    var outgoing: [FriendSearchResult]
}

struct SocialProfileView: Codable, Equatable {
    var profile: FriendSearchResult
    var stats: SocialProfileStats
    var proofPosts: [SocialProofPost]

    enum CodingKeys: String, CodingKey {
        case profile
        case stats
        case proofPosts = "proof_posts"
    }
}

struct SocialProfileStats: Codable, Equatable {
    var workouts: Int
    var proofPosts: Int

    enum CodingKeys: String, CodingKey {
        case workouts
        case proofPosts = "proof_posts"
    }
}

struct AICommandContext: Codable {
    var profile: UserProfile
    var goal: GoalPlan
    var savedFoods: [FoodItem] = []
    var currentMealType: MealType?

    enum CodingKeys: String, CodingKey {
        case profile
        case goal
        case savedFoods = "saved_foods"
        case currentMealType = "current_meal_type"
    }
}

struct ActionConfirmation: Codable, Equatable {
    var persisted: Bool
    var recordType: String
    var recordId: String?
    var commandId: String?

    enum CodingKeys: String, CodingKey {
        case persisted
        case recordType = "record_type"
        case recordId = "record_id"
        case commandId = "command_id"
    }
}

struct AICommandRecord: Identifiable, Equatable {
    var id = UUID()
    var rawText: String
    var status: AICommandStatus
    var proposal: ActionProposal?
}

enum AICommandStatus: Equatable {
    case parsing
    case ready
    case confirmed
    case failed(String)
}

struct ActionProposal: Identifiable, Codable, Equatable {
    var id = UUID()
    var actionType: ActionType
    var confidence: Double
    var requiresConfirmation: Bool
    var summary: String
    var title: String?
    var mealType: MealType?
    var calories: Int?
    var protein: Int?
    var carbs: Int?
    var fat: Int?
    var weeklyWorkouts: Int?
    var durationMinutes: Int?
    var targetFriendId: UUID?
    var workoutSets: [WorkoutSet]
    var foodItems: [FoodItem]
    var assumptions: [String]
    var missingFields: [String]
}

enum ActionType: String, CaseIterable, Codable, Identifiable {
    case logWorkout = "log_workout"
    case logMeal = "log_meal"
    case estimateFood = "estimate_food"
    case updateGoal = "update_goal"
    case createWorkoutPlan = "create_workout_plan"
    case createNutritionPlan = "create_nutrition_plan"
    case createAccountabilityNudge = "create_accountability_nudge"
    case summarizeProgress = "summarize_progress"
    case correctLastLog = "correct_last_log"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .logWorkout: "Workout log"
        case .logMeal: "Meal log"
        case .estimateFood: "Food estimate"
        case .updateGoal: "Goal update"
        case .createWorkoutPlan: "Workout plan"
        case .createNutritionPlan: "Nutrition plan"
        case .createAccountabilityNudge: "Accountability nudge"
        case .summarizeProgress: "Progress summary"
        case .correctLastLog: "Log correction"
        }
    }
}
