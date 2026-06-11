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
                VStack(alignment: .leading, spacing: 22) {
                    heroHeader
                    CommandBar()
                    dailyRingCard
                    weekCard
                    quickActions
                    if appState.shouldShowUpgradePrompt {
                        upgradePrompt
                    }
                    diarySection
                    workoutSection
                }
                .padding()
                .padding(.bottom, 52)
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

    private var dailyRingCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                EyebrowText(text: "Daily fuel")
                Spacer()
                Button {
                    appState.selectedTab = .profile
                } label: {
                    Label("Edit targets", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.fitBlue)
            }

            HStack(spacing: 22) {
                CaloriesRing(consumed: appState.caloriesConsumed, goal: appState.goal.calories)
                    .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(appState.caloriesConsumed)")
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .contentTransition(.numericText())
                        Text("eaten")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.fitMuted)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(appState.goal.calories)")
                            .font(.system(.title2, design: .rounded, weight: .black))
                        Text("daily goal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.fitMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 14) {
                ForEach(macroSegments) { macro in
                    MacroBar(title: macro.title, consumed: macro.consumed, goal: macro.goal, color: macro.color)
                }
            }
        }
        .padding(22)
        .fitCardSurface()
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                EyebrowText(text: "This week")
                Spacer()
                Text("\(completedDayIndexes.count) of \(appState.goal.weeklyWorkouts) workouts")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(completedDayIndexes.count >= appState.goal.weeklyWorkouts ? Color.fitGreen : Color.fitMuted)
            }
            WeekConsistencyStrip(completedIndexes: completedDayIndexes)
        }
        .padding(18)
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
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.bold())
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.fitInk)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .fitCardSurface()
        }
        .buttonStyle(FitPressableButtonStyle())
    }
}

private struct MealDiaryRow: View {
    var mealType: MealType
    var meal: MealLog?
    var action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.subheadline.bold())
                .foregroundStyle(Color.fitBlue)
                .frame(width: 38, height: 38)
                .background(Color.fitBlue.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
