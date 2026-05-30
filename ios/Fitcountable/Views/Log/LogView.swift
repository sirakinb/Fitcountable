import SwiftUI

struct LogView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedMode: LogMode = .workout
    @State private var workoutTitle = ""
    @State private var exerciseName = ""
    @State private var setCount = 3
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var duration = 45
    @State private var workoutNotes = ""
    @State private var draftSets: [WorkoutSet] = []
    @State private var mealType: MealType = .lunch
    @State private var foodName = ""
    @State private var quantity = ""
    @State private var calories = 0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var mealNotes = ""
    @State private var isEstimatingMeal = false
    @State private var draftFoods: [FoodItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Log type", selection: $selectedMode) {
                        Text("Workout").tag(LogMode.workout)
                        Text("Food").tag(LogMode.food)
                    }
                    .pickerStyle(.segmented)

                    if selectedMode == .workout {
                        workoutForm
                    } else {
                        foodForm
                    }
                }
                .padding()
            }
            .background(Color.fitSurface.ignoresSafeArea())
            .navigationTitle("Log")
        }
        .onAppear {
            selectedMode = appState.preferredLogMode
            mealType = appState.preferredMealType
        }
        .onChange(of: appState.preferredLogMode) { _, mode in
            selectedMode = mode
        }
        .onChange(of: appState.preferredMealType) { _, type in
            mealType = type
        }
    }

    private var workoutForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            formCard {
                Text("Workout journal")
                    .font(.title2.bold())
                TextField("Workout title", text: $workoutTitle)
                    .textFieldStyle(.roundedBorder)
                Stepper("Duration: \(duration) min", value: $duration, in: 5...240, step: 5)
                TextField("Notes", text: $workoutNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                Divider()
                Text("Add exercise")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exercise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fitMuted)
                    TextField("Bench Press", text: $exerciseName)
                        .textFieldStyle(.roundedBorder)
                }
                WorkoutStepperRow(label: "Sets", value: $setCount, range: 1...20)
                WorkoutStepperRow(label: "Reps per set", value: $reps, range: 1...100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fitMuted)
                    HStack {
                        TextField("0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("lb")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.fitMuted)
                    }
                }
                Button {
                    addDraftSets()
                } label: {
                    Label("Add to workout", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reps <= 0)
            }

            draftWorkoutCard

            PrimaryButton(title: "Save workout", systemImage: "dumbbell.fill") {
                let workout = WorkoutLog(
                    title: workoutTitle.isEmpty ? "Workout" : workoutTitle,
                    startedAt: .now,
                    durationMinutes: duration,
                    source: .manual,
                    notes: workoutNotes,
                    visibility: appState.accountabilityEnabled ? .friends : .privateOnly,
                    sets: draftSets
                )
                appState.saveManualWorkout(workout)
                workoutTitle = ""
                exerciseName = ""
                setCount = 3
                reps = 10
                weight = 0
                workoutNotes = ""
                draftSets = []
            }
            .disabled(draftSets.isEmpty)

            logHistory
        }
    }

    private var draftWorkoutCard: some View {
        formCard {
            SectionHeader(title: "Draft workout", action: nil)
            if draftSets.isEmpty {
                Text("Add at least one set before saving.")
                    .foregroundStyle(Color.fitMuted)
            } else {
                ForEach(draftSets) { set in
                    EditableSetRow(set: set) { updated in
                        updateDraftSet(updated)
                    } onDelete: {
                        removeDraftSet(set)
                    }
                }
            }
        }
    }

    private var foodForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            formCard {
                Text("Food and macros")
                    .font(.title2.bold())
                Picker("Meal", selection: $mealType) {
                    ForEach(MealType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                TextField("Food", text: $foodName)
                    .textFieldStyle(.roundedBorder)
                TextField("Quantity", text: $quantity)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Calories", value: $calories, format: .number)
                    TextField("Protein", value: $protein, format: .number)
                }
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Carbs", value: $carbs, format: .number)
                    TextField("Fat", value: $fat, format: .number)
                }
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                TextField("Notes", text: $mealNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                Button {
                    addDraftFood()
                } label: {
                    Label("Add food item", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            draftMealCard
            savedFoodsCard

            PrimaryButton(title: "Save meal", systemImage: "fork.knife") {
                let meal = MealLog(
                    mealType: mealType,
                    loggedAt: .now,
                    source: .manual,
                    notes: mealNotes,
                    items: draftFoods
                )
                appState.saveManualMeal(meal)
                foodName = ""
                quantity = ""
                calories = 0
                protein = 0
                carbs = 0
                fat = 0
                mealNotes = ""
                draftFoods = []
            }
            .disabled(draftFoods.isEmpty)

            PrimaryButton(title: "Estimate current meal with AI", systemImage: "sparkles") {
                Task {
                    isEstimatingMeal = true
                    let typedFood = [quantity, foodName]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { $0.isEmpty == false }
                        .joined(separator: " ")
                    let description = draftFoods.isEmpty
                        ? typedFood
                        : draftFoods.map { "\($0.quantityText) \($0.name)" }.joined(separator: ", ")
                    let selectedMeal = mealType.rawValue.lowercased()
                    appState.selectedTab = .ai
                    await appState.submitCommand(
                        "Estimate calories and macros for \(description) as \(selectedMeal)",
                        currentMealType: mealType
                    )
                    isEstimatingMeal = false
                }
            }
            .disabled(isEstimatingMeal || appState.isProcessingCommand || (draftFoods.isEmpty && foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            if isEstimatingMeal || appState.isProcessingCommand {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Creating an editable AI estimate...")
                        .font(.footnote.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(Color.fitGreen)
                .padding(.horizontal, 4)
            }

            mealHistory
        }
    }

    private func addDraftSets() {
        let cleanExercise = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanExercise.isEmpty == false, reps > 0 else { return }
        for _ in 0..<setCount {
            draftSets.append(
                WorkoutSet(
                    exerciseName: cleanExercise,
                    setIndex: draftSets.count + 1,
                    reps: reps,
                    weight: max(weight, 0),
                    rpe: nil
                )
            )
        }
    }

    private func updateDraftSet(_ set: WorkoutSet) {
        guard let index = draftSets.firstIndex(where: { $0.id == set.id }) else { return }
        draftSets[index] = set
    }

    private func removeDraftSet(_ set: WorkoutSet) {
        draftSets.removeAll { $0.id == set.id }
        draftSets = draftSets.enumerated().map { index, value in
            WorkoutSet(
                id: value.id,
                exerciseName: value.exerciseName,
                setIndex: index + 1,
                reps: value.reps,
                weight: value.weight,
                rpe: value.rpe
            )
        }
    }

    private func addDraftFood() {
        let cleanFood = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanFood.isEmpty == false else { return }
        draftFoods.append(
            FoodItem(
                name: cleanFood,
                quantityText: quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1 serving" : quantity,
                calories: max(calories, 0),
                protein: max(protein, 0),
                carbs: max(carbs, 0),
                fat: max(fat, 0),
                confidence: calories > 0 ? 0.95 : 0.55
            )
        )
        foodName = ""
        quantity = ""
        calories = 0
        protein = 0
        carbs = 0
        fat = 0
    }

    private var draftMealCard: some View {
        formCard {
            SectionHeader(title: "Draft meal", action: nil)
            if draftFoods.isEmpty {
                Text("Add at least one item before saving.")
                    .foregroundStyle(Color.fitMuted)
            } else {
                ForEach(draftFoods) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            Text("\(item.quantityText) • \(item.calories) cal • \(Int(item.protein))g protein")
                                .foregroundStyle(Color.fitMuted)
                        }
                        Spacer()
                        Button {
                            draftFoods.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
                Divider()
                Text("\(draftFoods.reduce(0) { $0 + $1.calories }) calories total")
                    .font(.headline)
            }
        }
    }

    private var savedFoodsCard: some View {
        let savedFoods = Array(appState.savedFoodItems.prefix(8))
        return Group {
            if savedFoods.isEmpty == false {
                formCard {
                    SectionHeader(title: "Saved foods", action: nil)
                    Text("Tap a previous food to reuse it in this meal.")
                        .font(.footnote)
                        .foregroundStyle(Color.fitMuted)
                    VStack(spacing: 8) {
                        ForEach(savedFoods) { item in
                            Button {
                                draftFoods.append(
                                    FoodItem(
                                        name: item.name,
                                        quantityText: item.quantityText,
                                        calories: item.calories,
                                        protein: item.protein,
                                        carbs: item.carbs,
                                        fat: item.fat,
                                        confidence: item.confidence
                                    )
                                )
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.fitInk)
                                        Text("\(item.quantityText) • \(item.calories) cal • \(Int(item.protein))g protein")
                                            .font(.caption)
                                            .foregroundStyle(Color.fitMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.fitGreen)
                                }
                                .padding(10)
                                .background(Color.fitSurface, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var logHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent workouts", action: nil)
            ForEach(appState.workouts) { workout in
                formCard {
                    HStack {
                        Text(workout.title).font(.headline)
                        Spacer()
                        Text("\(workout.durationMinutes)m")
                        .foregroundStyle(Color.fitMuted)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(workout.compactSetSummaries, id: \.self) { summary in
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(Color.fitMuted)
                        }
                    }
                }
            }
        }
    }

    private var mealHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent meals", action: nil)
            ForEach(appState.meals) { meal in
                formCard {
                    Text(meal.mealType.rawValue).font(.headline)
                    Text("\(meal.totalCalories) cal • \(Int(meal.totalProtein))g protein • \(Int(meal.totalCarbs))g carbs • \(Int(meal.totalFat))g fat")
                        .foregroundStyle(Color.fitMuted)
                    Text(meal.items.map(\.name).joined(separator: ", "))
                        .font(.footnote)
                }
            }
        }
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding()
        .background(Color.fitCard, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EditableSetRow: View {
    @State private var exerciseName: String
    @State private var reps: Int
    @State private var weight: Double
    private let set: WorkoutSet
    private let onUpdate: (WorkoutSet) -> Void
    private let onDelete: () -> Void

    init(set: WorkoutSet, onUpdate: @escaping (WorkoutSet) -> Void, onDelete: @escaping () -> Void) {
        self.set = set
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _exerciseName = State(initialValue: set.exerciseName)
        _reps = State(initialValue: set.reps)
        _weight = State(initialValue: set.weight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Set \(set.setIndex)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.fitMuted)
                TextField("Exercise", text: $exerciseName)
                    .textFieldStyle(.roundedBorder)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fitMuted)
                    TextField("Reps", value: $reps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fitMuted)
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .onChange(of: exerciseName) { _, _ in pushUpdate() }
        .onChange(of: reps) { _, _ in pushUpdate() }
        .onChange(of: weight) { _, _ in pushUpdate() }
    }

    private func pushUpdate() {
        onUpdate(
            WorkoutSet(
                id: set.id,
                exerciseName: exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Exercise" : exerciseName,
                setIndex: set.setIndex,
                reps: max(reps, 0),
                weight: max(weight, 0),
                rpe: set.rpe
            )
        )
    }
}

private struct WorkoutStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                value = max(range.lowerBound, value - 1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .frame(width: 44)
            Button {
                value = min(range.upperBound, value + 1)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
        }
    }
}
