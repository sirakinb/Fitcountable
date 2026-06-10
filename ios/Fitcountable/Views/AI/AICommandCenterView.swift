import SwiftUI
import UIKit

struct AICommandCenterView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CommandBar()
                    if appState.commands.isEmpty {
                        explainer
                    }
                    ForEach(appState.commands) { command in
                        CommandReviewCard(command: command)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding()
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.commands)
            }
            .background(Color.fitSurface.ignoresSafeArea())
            .navigationTitle("AI")
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if appState.isVoicePromptActive || appState.commandProcessingMessage != nil {
                    Button {
                        dismissKeyboard()
                    } label: {
                        Label("Back to app", systemImage: "keyboard.chevron.compact.down")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.fitGreen)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(LinearGradient.fitAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tell Fitcountable what happened.")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Speak or type it. You review the draft before anything is saved.")
                        .font(.subheadline)
                        .foregroundStyle(Color.fitMuted)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ExampleCommandRow(icon: "fork.knife", tint: .fitBlue, text: "\u{201C}Jollof rice with goat meat for dinner\u{201D}")
                ExampleCommandRow(icon: "dumbbell.fill", tint: .fitGreen, text: "\u{201C}Bench press 3 sets of 10 at 185\u{201D}")
                ExampleCommandRow(icon: "target", tint: .orange, text: "\u{201C}Set my protein target to 190\u{201D}")
            }
        }
        .padding(18)
        .fitCardSurface()
    }

    private func dismissKeyboard() {
        appState.isVoicePromptActive = false
        appState.commandProcessingMessage = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct ExampleCommandRow: View {
    var icon: String
    var tint: Color
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.fitMuted)
        }
    }
}

struct CommandReviewCard: View {
    @EnvironmentObject private var appState: AppState
    var command: AICommandRecord
    @State private var contextText = ""
    @FocusState private var isContextFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayTitle)
                .font(.headline)
            if command.rawText != displayTitle {
                Text(command.rawText)
                    .font(.caption)
                    .foregroundStyle(Color.fitMuted)
                    .lineLimit(2)
            }

            switch command.status {
            case .parsing:
                ProgressView("Building your editable log...")
            case .failed(let message):
                Text(message)
                    .foregroundStyle(.red)
            case .confirmed:
                if let proposal = command.proposal {
                    proposalView(proposal, isConfirmed: true)
                }
            case .ready:
                if let proposal = command.proposal {
                    proposalView(proposal, isConfirmed: false)
                }
            }
        }
        .padding()
        .fitCardSurface()
    }

    private func proposalView(_ proposal: ActionProposal, isConfirmed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(proposal.actionType.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.fitBlue)
                Spacer()
                Text("\(Int(proposal.confidence * 100))%")
                    .font(.caption.weight(.semibold))
            }
            Text(proposal.summary)
                .foregroundStyle(Color.fitMuted)
            if let title = proposal.title {
                ProposalRow(label: "Title", value: title)
            }
            if let mealType = proposal.mealType {
                ProposalRow(label: "Meal", value: mealType.rawValue)
            }
            if let duration = proposal.durationMinutes {
                ProposalRow(label: "Duration", value: "\(duration) minutes")
            }
            goalChanges(proposal)
            if proposal.foodItems.isEmpty == false {
                ForEach(proposal.foodItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(item.calories) cal")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("\(item.quantityText) · \(Int(item.protein))g protein · \(Int(item.carbs))g carbs · \(Int(item.fat))g fat")
                            .font(.caption)
                            .foregroundStyle(Color.fitMuted)
                    }
                }
            }
            if let calories = proposal.calories, proposal.foodItems.isEmpty == false {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Your meal estimate")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(calories) cal")
                            .font(.subheadline.weight(.bold))
                    }
                    if let protein = proposal.protein, let carbs = proposal.carbs, let fat = proposal.fat {
                        Text("\(protein)g protein · \(carbs)g carbs · \(fat)g fat")
                            .font(.caption)
                            .foregroundStyle(Color.fitMuted)
                    }
                }
                .foregroundStyle(Color.fitInk)
            }
            if proposal.workoutSets.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(WorkoutLog.groupedSetSummaries(proposal.workoutSets), id: \.self) { summary in
                        HStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.caption)
                                .foregroundStyle(Color.fitGreen)
                            Text(summary)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            if let estimateNote = estimateNote(for: proposal) {
                Text(estimateNote)
                    .font(.footnote)
                    .foregroundStyle(Color.fitMuted)
            }
            if proposalNeedsMoreInfo(proposal) {
                Label("I need more info before this can become a reliable food log.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(12)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if isConfirmed == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add context")
                        .font(.subheadline.weight(.semibold))
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Example: black coffee, no cream, large fries, 1 sauce packet", text: $contextText, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.roundedBorder)
                            .focused($isContextFocused)
                        Button {
                            let detail = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard detail.isEmpty == false else { return }
                            dismissKeyboard()
                            Task {
                                await appState.refineCommand(command, detail: detail)
                                contextText = ""
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                        .disabled(contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isProcessingCommand)
                    }
                }
                .padding(12)
                .background(Color.fitSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if isConfirmed {
                Label("Saved", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Color.fitGreen)
            } else {
                HStack(spacing: 10) {
                    Button {
                        dismissKeyboard()
                        appState.redo(command)
                    } label: {
                        Label("Redo", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.fitGreen)

                    PrimaryButton(title: "Confirm and save", systemImage: "checkmark.circle.fill") {
                        dismissKeyboard()
                        appState.confirm(command)
                    }
                    .disabled(proposalNeedsMoreInfo(proposal))
                }
            }
            if let message = appState.lastSyncMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.fitMuted)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isContextFocused {
                    Spacer()
                    Button("Done") {
                        isContextFocused = false
                        dismissKeyboard()
                    }
                }
            }
        }
    }

    private func dismissKeyboard() {
        isContextFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func proposalNeedsMoreInfo(_ proposal: ActionProposal) -> Bool {
        guard proposal.actionType == .logMeal || proposal.actionType == .estimateFood else { return false }
        if proposal.missingFields.isEmpty == false { return true }
        return proposal.foodItems.contains { item in
            item.calories <= 0 && item.protein <= 0 && item.carbs <= 0 && item.fat <= 0
        }
    }

    private func estimateNote(for proposal: ActionProposal) -> String? {
        guard proposal.actionType == .logMeal || proposal.actionType == .estimateFood else {
            return proposal.assumptions.isEmpty ? nil : proposal.assumptions.joined(separator: " ")
        }

        if proposalNeedsMoreInfo(proposal) {
            return "This needs a little more detail before it can be saved confidently."
        }

        let hasAiReview = proposal.assumptions.contains { $0.localizedCaseInsensitiveContains("AI reviewed") }
        let hasSpecificServing = proposal.assumptions.contains { $0.localizedCaseInsensitiveContains("Adjusted nutrition") }

        if hasAiReview && hasSpecificServing {
            return "Fitcountable checked the foods against nutrition data and adjusted the estimate for the serving details you gave."
        }
        if hasAiReview {
            return "Fitcountable checked the foods against nutrition data and reviewed the estimate before saving."
        }
        if hasSpecificServing {
            return "Fitcountable adjusted this estimate for the serving details you gave."
        }
        return "Nutrition is an editable estimate. Review the foods and serving sizes before saving."
    }

    private var displayTitle: String {
        guard let proposal = command.proposal else { return command.rawText }
        if let item = proposal.foodItems.first {
            return item.quantityText == "1 typical serving"
                ? item.name
                : "\(item.quantityText) \(item.name)"
        }
        if proposal.workoutSets.isEmpty == false {
            return proposal.title ?? "Workout draft"
        }
        return proposal.title ?? command.rawText
    }

    @ViewBuilder
    private func goalChanges(_ proposal: ActionProposal) -> some View {
        let changes = [
            proposal.calories.map { ProposalMetric(label: "Calories", value: "\($0)") },
            proposal.protein.map { ProposalMetric(label: "Protein", value: "\($0)g") },
            proposal.carbs.map { ProposalMetric(label: "Carbs", value: "\($0)g") },
            proposal.fat.map { ProposalMetric(label: "Fat", value: "\($0)g") },
            proposal.weeklyWorkouts.map { ProposalMetric(label: "Workouts", value: "\($0)x/week") }
        ].compactMap { $0 }

        if changes.isEmpty == false {
            VStack(spacing: 6) {
                ForEach(changes) { change in
                    ProposalRow(label: change.label, value: change.value)
                }
            }
        }
    }
}

private struct ProposalMetric: Identifiable {
    var id: String { label }
    var label: String
    var value: String
}

private struct ProposalRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.fitMuted)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
