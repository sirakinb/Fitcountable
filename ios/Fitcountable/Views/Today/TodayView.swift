import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState

    private var macroSegments: [MacroSegment] {
        [
            MacroSegment(title: "Carbs", consumed: appState.carbsConsumed, goal: appState.goal.carbs, color: .teal),
            MacroSegment(title: "Fat", consumed: appState.fatConsumed, goal: appState.goal.fat, color: .purple),
            MacroSegment(title: "Protein", consumed: appState.proteinConsumed, goal: appState.goal.protein, color: .orange)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroHeader
                    WeekConsistencyStrip(completedIndexes: completedDayIndexes)
                    CommandBar()
                    caloriesCard
                    macrosCard
                    quickActions
                    if appState.shouldShowUpgradePrompt {
                        upgradePrompt
                    }
                    diarySection
                    workoutSection
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [Color.fitMist, Color.fitSurface], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 6)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.fitGreen)
                    .tracking(1.1)
                Text("Today")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                Text("\(appState.goal.weeklyWorkouts)x workouts weekly target")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.fitMuted)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("\(appState.workouts.count)")
                    .font(.headline.bold())
                Image(systemName: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitGreen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.fitCard.opacity(0.85), in: Capsule())
            .overlay(Capsule().stroke(Color.fitBorder, lineWidth: 1))
        }
    }

    private var caloriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calories")
                    .font(.headline)
                Spacer()
                Text("\(appState.caloriesRemaining) left")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.fitMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(appState.caloriesConsumed)")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                Text("cal / \(appState.goal.calories)")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.fitMuted)
            }
            ProgressView(value: Double(appState.caloriesConsumed), total: Double(max(appState.goal.calories, 1)))
                .tint(.fitBlue)
                .scaleEffect(x: 1, y: 1.8, anchor: .center)
        }
        .padding(22)
        .fitCardSurface()
    }

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Macros")
                    .font(.headline)
                Spacer()
                Button {
                    appState.selectedTab = .profile
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
            }

            HStack(spacing: 18) {
                ForEach(macroSegments) { macro in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Text(macro.title)
                                .font(.subheadline.weight(.semibold))
                            Circle()
                                .fill(macro.color)
                                .frame(width: 6, height: 6)
                        }
                        Text("\(macro.consumed) g")
                            .font(.title3.bold())
                        Text("/ \(macro.goal)")
                            .font(.caption)
                            .foregroundStyle(Color.fitMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(macroSegments) { macro in
                        Rectangle()
                            .fill(macro.color)
                            .frame(width: segmentWidth(macro, in: proxy.size.width))
                    }
                    Spacer(minLength: 0)
                }
                .background(Color.fitMuted.opacity(0.15))
                .clipShape(Capsule())
            }
            .frame(height: 10)
        }
        .padding(22)
        .fitCardSurface()
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickActionButton(title: "Log Food", systemImage: "magnifyingglass", color: .fitBlue) {
                appState.openFoodLog(mealType: .lunch)
            }
            QuickActionButton(title: "Voice Log", systemImage: "mic.fill", color: .purple) {
                appState.selectedTab = .ai
            }
            QuickActionButton(title: "Workout", systemImage: "figure.strengthtraining.traditional", color: .orange) {
                appState.openWorkoutLog()
            }
            QuickActionButton(title: "Proof", systemImage: "camera.fill", color: .teal) {
                appState.selectedTab = .social
            }
        }
    }

    private var diarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Diary", action: "View all")
            ForEach(MealType.allCases) { mealType in
                MealDiaryRow(mealType: mealType, meal: latestMeal(for: mealType)) {
                    appState.openFoodLog(mealType: mealType)
                }
            }
        }
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Training", action: "Log")
            if appState.workouts.isEmpty {
                EmptyTodayRow(systemImage: "figure.run", title: "No workout yet", subtitle: "Log by typing, speaking, or using the workout form.")
            } else {
                ForEach(appState.workouts.prefix(2)) { workout in
                    WorkoutTodayRow(workout: workout)
                }
            }
        }
    }

    private var upgradePrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Premium is optional", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Color.fitGreen)
            Text("Keep logging for free. Upgrade when you want higher AI limits, advanced plans, deeper history, and stronger accountability nudges.")
                .font(.subheadline)
                .foregroundStyle(Color.fitMuted)
            Button {
                appState.selectedTab = .profile
            } label: {
                Label("View premium", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .fitCardSurface()
    }

    private var completedDayIndexes: Set<Int> {
        let calendar = Calendar.current
        let today = Date()
        return Set(appState.workouts.compactMap { workout in
            guard
                calendar.isDate(workout.startedAt, equalTo: today, toGranularity: .weekOfYear),
                calendar.isDate(workout.startedAt, equalTo: today, toGranularity: .yearForWeekOfYear)
            else {
                return nil
            }
            return calendar.component(.weekday, from: workout.startedAt) - 1
        })
    }

    private func latestMeal(for type: MealType) -> MealLog? {
        appState.meals.first { $0.mealType == type }
    }

    private func segmentWidth(_ macro: MacroSegment, in totalWidth: CGFloat) -> CGFloat {
        let totalConsumed = max(macroSegments.reduce(0) { $0 + $1.consumed }, 1)
        let share = CGFloat(macro.consumed) / CGFloat(totalConsumed)
        let progress = min(CGFloat(macro.consumed) / CGFloat(max(macro.goal, 1)), 1)
        return max(8, totalWidth * share * progress)
    }
}

private struct MacroSegment: Identifiable {
    let id = UUID()
    var title: String
    var consumed: Int
    var goal: Int
    var color: Color
}

private struct WeekConsistencyStrip: View {
    var completedIndexes: Set<Int>

    private var calendar: Calendar { Calendar.current }

    private var orderedWeekdayIndexes: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }
    }

    private var todayIndex: Int {
        calendar.component(.weekday, from: .now) - 1
    }

    var body: some View {
        HStack {
            ForEach(orderedWeekdayIndexes, id: \.self) { weekdayIndex in
                let isToday = weekdayIndex == todayIndex
                let isComplete = completedIndexes.contains(weekdayIndex)
                VStack(spacing: 8) {
                    Text(calendar.veryShortWeekdaySymbols[weekdayIndex])
                        .font(.caption.weight(isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? Color.fitGreen : Color.fitMuted)
                    ZStack {
                        Circle()
                            .stroke(isToday ? Color.fitGreen : Color.fitMuted.opacity(0.35), lineWidth: isToday ? 2.5 : 2)
                        if isComplete {
                            Circle()
                                .fill(Color.fitGreen)
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isComplete)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct QuickActionButton: View {
    var title: String
    var systemImage: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(color, in: Circle())
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.fitInk)
            }
            .frame(maxWidth: .infinity, minHeight: 116)
            .fitCardSurface()
        }
        .buttonStyle(.plain)
    }
}

private struct MealDiaryRow: View {
    var mealType: MealType
    var meal: MealLog?
    var action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(Color.fitBlue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(mealType.rawValue)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.fitMuted)
                    .lineLimit(1)
            }
            Spacer()
            Button("Log", action: action)
                .font(.subheadline.weight(.bold))
                .buttonStyle(.bordered)
                .tint(.fitBlue)
        }
        .padding()
        .fitCardSurface()
    }

    private var subtitle: String {
        guard let meal else { return "No food logged" }
        let names = meal.items.map(\.name).joined(separator: ", ")
        return "\(names) · \(meal.totalCalories) cal"
    }

    private var iconName: String {
        switch mealType {
        case .breakfast: "cup.and.saucer"
        case .lunch: "takeoutbag.and.cup.and.straw"
        case .dinner: "fork.knife"
        case .snack: "leaf"
        }
    }
}

private struct WorkoutTodayRow: View {
    var workout: WorkoutLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline)
                    Text("\(workout.durationMinutes)m · \(workout.visibility.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(Color.fitMuted)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(Color.fitGreen)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                ForEach(workout.compactSetSummaries.prefix(3), id: \.self) { summary in
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.fitMuted)
                        .lineLimit(1)
                }
                if workout.compactSetSummaries.count > 3 {
                    Text("+ \(workout.compactSetSummaries.count - 3) more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fitBlue)
                }
            }
        }
        .padding()
        .fitCardSurface()
    }
}

private struct EmptyTodayRow: View {
    var systemImage: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.fitMuted)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.fitMuted)
            }
        }
        .padding()
        .fitCardSurface()
    }
}
