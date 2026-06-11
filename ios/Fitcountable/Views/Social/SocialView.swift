import PhotosUI
import SwiftUI
import UIKit

struct SocialView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var proofCaption = ""
    @State private var visibility: Visibility = .friends
    @State private var selectedProfile: FriendSearchResult?
    @State private var proofKind: AccountabilityProofKind = .workout
    @State private var selectedWorkoutId = "general"
    @State private var selectedMealId = "food-general"
    @State private var selectedProofPhoto: PhotosPickerItem?
    @State private var proofPhotoData: Data?
    @State private var showingCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    accountabilityCard
                    proofComposer
                    requestSections
                    feedSection
                    friendSearch
                    friendList
                }
                .padding()
                .padding(.bottom, 52)
            }
            .background(Color.fitSurface.ignoresSafeArea())
            .navigationTitle("Accountability")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await appState.refreshSocial() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .task {
                await appState.refreshSocial()
            }
            .sheet(item: $selectedProfile) { profile in
                SocialProfileSheet(profile: profile)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingCamera) {
                CameraCaptureView { image in
                    proofPhotoData = compressedProofImage(image)
                }
            }
        }
    }

    private var accountabilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    EyebrowText(text: "Your circle")
                    Text("Accountability mode")
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Text(appState.accountabilityEnabled ? "Friends can see proof you mark for friends." : "Private by default. Turn on sharing when ready.")
                        .font(.subheadline)
                        .foregroundStyle(Color.fitMuted)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.accountabilityEnabled },
                    set: { appState.setAccountabilityEnabled($0) }
                ))
                .labelsHidden()
                .tint(.fitGreen)
            }

            Picker("Visibility", selection: $visibility) {
                ForEach(Visibility.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(visibilityDescription(visibility))
                .font(.footnote)
                .foregroundStyle(Color.fitMuted)

            HStack(spacing: 12) {
                MetricCard(title: "Friends", value: "\(appState.friends.count)", detail: "approved", color: .fitBlue)
                MetricCard(title: "Proof", value: "\(appState.proofPosts.count)", detail: "posts", color: .fitGreen)
            }
        }
        .padding()
        .fitCardSurface()
    }

    private var proofComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Post proof", action: nil)
            Picker("Proof type", selection: $proofKind) {
                ForEach(AccountabilityProofKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if proofKind == .workout {
                Picker("Workout", selection: $selectedWorkoutId) {
                    Text("Gym proof").tag("general")
                    ForEach(appState.workouts.prefix(8)) { workout in
                        Text("\(workout.title) · \(shortDate(workout.startedAt))").tag(workout.id.uuidString)
                    }
                }
                .pickerStyle(.menu)

                if let workout = selectedWorkout {
                    proofSourceCard(title: workout.title, detail: "\(workout.durationMinutes)m · \(workoutSummary(workout))", lines: Array(workout.compactSetSummaries.prefix(3)))
                } else {
                    proofSourceCard(title: "Gym proof", detail: "Use a photo or caption without tying it to a workout log.", lines: [])
                }
            } else {
                Picker("Meal", selection: $selectedMealId) {
                    Text("Food proof").tag("food-general")
                    ForEach(appState.meals.prefix(8)) { meal in
                        Text("\(meal.mealType.rawValue) · \(meal.totalCalories) cal · \(shortDate(meal.loggedAt))").tag(meal.id.uuidString)
                    }
                }
                .pickerStyle(.menu)

                if let meal = selectedMeal {
                    proofSourceCard(title: "\(meal.mealType.rawValue) proof", detail: "\(meal.totalCalories) cal · \(meal.items.count) item\(meal.items.count == 1 ? "" : "s")", lines: meal.items.prefix(3).map { "\($0.name) · \($0.quantityText) · \($0.calories) cal" })
                } else {
                    proofSourceCard(title: "Food proof", detail: "Use a meal photo or caption without tying it to a saved meal.", lines: [])
                }
            }

            if let proofPhotoData, let image = UIImage(data: proofPhotoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            self.proofPhotoData = nil
                            selectedProofPhoto = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.fitInk.opacity(0.7))
                                .padding(10)
                        }
                    }
            }

            HStack(spacing: 10) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.fitBlue.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(FitPressableButtonStyle())
                .foregroundStyle(Color.fitBlue)
                .disabled(UIImagePickerController.isSourceTypeAvailable(.camera) == false)

                PhotosPicker(selection: $selectedProofPhoto, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.fitGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(FitPressableButtonStyle())
                .foregroundStyle(Color.fitGreen)
            }

            TextField(proofKind == .workout ? "Caption for today's lift or gym session" : "Caption for this meal or food choice", text: $proofCaption, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .onChange(of: selectedProofPhoto) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        guard let data = try? await newItem.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { return }
                        proofPhotoData = compressedProofImage(image)
                    }
                }
            Button {
                let caption = proofCaption
                let photoData = proofPhotoData
                let workout = proofKind == .workout ? selectedWorkout : nil
                let meal = proofKind == .food ? selectedMeal : nil
                let kind = proofKind.rawValue
                Task {
                    let didSave = await appState.createProofPost(caption: caption, visibility: visibility, workout: workout, meal: meal, proofKind: kind, photoData: photoData)
                    guard didSave else { return }
                    proofCaption = ""
                    proofPhotoData = nil
                    selectedProofPhoto = nil
                }
            } label: {
                HStack(spacing: 10) {
                    if appState.isSavingProof {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "camera.fill")
                    }
                    Text(appState.isSavingProof ? "Saving proof..." : "Save proof")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.fitBlue)
            .disabled(appState.isSavingProof)
            if appState.isSavingProof {
                Text(proofPhotoData == nil ? "Saving your proof post." : "Uploading your photo and saving your proof post.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitMuted)
            }
            Text("Private stays with you. Friends goes to approved friends. Public can appear on your profile.")
                .font(.footnote)
                .foregroundStyle(Color.fitMuted)
        }
        .padding()
        .fitCardSurface()
    }

    private var requestSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.incomingFriendRequests.isEmpty == false {
                SectionHeader(title: "Pending requests", action: nil)
                ForEach(appState.incomingFriendRequests) { request in
                    RequestRow(result: request, direction: .incoming) {
                        Task { await appState.respondToFollow(userId: request.id, action: "accept") }
                    } secondary: {
                        Task { await appState.respondToFollow(userId: request.id, action: "decline") }
                    }
                }
            }
            if appState.outgoingFriendRequests.isEmpty == false {
                SectionHeader(title: "Sent requests", action: nil)
                ForEach(appState.outgoingFriendRequests) { request in
                    RequestRow(result: request, direction: .outgoing) {
                        Task { await appState.respondToFollow(userId: request.id, action: "cancel") }
                    } secondary: {}
                }
            }
        }
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Friends' proof", action: nil)
            if appState.proofPosts.isEmpty {
                EmptyStateCard(
                    systemImage: "camera.metering.center.weighted",
                    title: "No proof posts yet",
                    subtitle: "Post proof after a workout or meal, or approve friends to see their updates here."
                )
            } else {
                ForEach(appState.proofPosts) { post in
                    ProofPostCard(
                        post: post,
                        profilePhotoData: appState.profilePhotoData,
                        proofPhotoData: appState.proofMediaData[post.id],
                        onRemovePhoto: {
                            Task { await appState.removeProofPhoto(post) }
                        },
                        onDelete: {
                            Task { await appState.deleteProofPost(post) }
                        }
                    )
                }
            }
        }
    }

    private var friendSearch: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Find friends", action: nil)
            HStack {
                TextField("Friend name", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { search() }
                Button(action: search) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .tint(.fitBlue)
            }
            if let message = appState.socialStatusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.fitMuted)
            }
            ForEach(appState.friendSearchResults) { result in
                SearchResultRow(result: result) {
                    Task { await appState.followUser(targetUserId: result.id) }
                    searchText = ""
                } open: {
                    selectedProfile = result
                }
            }
        }
        .padding()
        .fitCardSurface()
    }

    private var friendList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Friends", action: nil)
            if appState.friends.isEmpty {
                Text("Approved friends will appear here after they accept your request.")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitMuted)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fitCardSurface()
            } else {
                ForEach(appState.friends) { friend in
                    FriendAccountabilityRow(friend: friend) {
                        Task { await appState.sendNudge(to: friend) }
                    } remove: {
                        Task { await appState.removeFriend(friend) }
                    }
                }
            }
        }
    }

    private func search() {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return }
        Task { await appState.searchFriends(query: name) }
    }

    private func visibilityDescription(_ value: Visibility) -> String {
        switch value {
        case .privateOnly:
            "Only you can see this."
        case .friends:
            "Approved friends can see this."
        case .publicPost:
            "Anyone with your profile can see this."
        }
    }

    private var selectedWorkout: WorkoutLog? {
        appState.workouts.first { $0.id.uuidString == selectedWorkoutId }
    }

    private var selectedMeal: MealLog? {
        appState.meals.first { $0.id.uuidString == selectedMealId }
    }

    private func proofSourceCard(title: String, detail: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: proofKind == .workout ? "checkmark.seal.fill" : "fork.knife.circle.fill")
                    .foregroundStyle(proofKind == .workout ? Color.fitGreen : Color.fitBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.fitMuted)
                }
                Spacer()
            }
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(Color.fitMuted)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.fitMist, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func shortDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func workoutSummary(_ workout: WorkoutLog) -> String {
        let names = Array(Set(workout.sets.map(\.exerciseName))).sorted()
        guard names.isEmpty == false else { return "workout proof" }
        return names.prefix(2).joined(separator: ", ") + (names.count > 2 ? " +" : "")
    }
}

private enum AccountabilityProofKind: String, CaseIterable, Identifiable {
    case workout
    case food

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workout: "Gym"
        case .food: "Food"
        }
    }
}

private struct ProofPostCard: View {
    var post: SocialProofPost
    var profilePhotoData: Data? = nil
    var proofPhotoData: Data? = nil
    var onRemovePhoto: (() -> Void)?
    var onDelete: (() -> Void)?
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ProfilePhotoView(
                    imageData: post.relationship == "own" ? profilePhotoData : nil,
                    imageURL: post.avatarURL,
                    fallback: post.displayName,
                    size: 42,
                    color: post.relationship == "own" ? .fitInk : .fitBlue
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.displayName)
                        .font(.headline)
                    Text("\(relativeDate) · \(post.visibility.rawValue)")
                        .font(.caption)
                        .foregroundStyle(Color.fitMuted)
                }
                Spacer()
                HStack(spacing: 8) {
                    ShareLinkButton(post: post, proofPhotoData: proofPhotoData)
                    if post.relationship == "own" {
                        Menu {
                            if hasProofImage {
                                Button {
                                    onRemovePhoto?()
                                } label: {
                                    Label("Remove photo", systemImage: "photo.badge.minus")
                                }
                            }
                            Button(role: .destructive) {
                                isConfirmingDelete = true
                            } label: {
                                Label("Delete proof", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.fitMuted)
                    }
                }
            }

            Text(post.workoutTitle)
                .font(.system(.title3, design: .rounded, weight: .black))

            HStack(spacing: 8) {
                ProofChip(
                    icon: post.proofKind == "food" ? "fork.knife" : "stopwatch",
                    text: post.proofKind == "food" ? "Food" : (post.durationMinutes.map { "\($0)m" } ?? "Logged"),
                    tint: .fitBlue
                )
                ProofChip(
                    icon: "checkmark.seal.fill",
                    text: post.proofKind == "food" ? "Meal" : (post.workoutTitle == "Workout proof" ? "Logged" : "Workout"),
                    tint: .fitGreen
                )
                ProofChip(
                    icon: post.visibility == .privateOnly ? "lock.fill" : (post.visibility == .friends ? "person.2.fill" : "globe"),
                    text: post.visibility.rawValue,
                    tint: .orange
                )
                Spacer()
            }

            if let detailLines = post.detailLines, detailLines.isEmpty == false {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(detailLines.prefix(4), id: \.self) { line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(Color.fitMuted)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }

            ZStack(alignment: .leading) {
                if let imageData = proofPhotoData ?? post.mediaURL?.dataURLImageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let mediaURL = post.mediaURL {
                    AsyncImage(url: mediaURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            LinearGradient(colors: [Color.fitBlue.opacity(0.18), Color.fitGreen.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                } else {
                    LinearGradient(colors: [Color.fitBlue.opacity(0.18), Color.fitGreen.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(Color.fitGreen)
                    Text(post.caption?.isEmpty == false ? post.caption! : "Workout proof logged.")
                        .font(.headline)
                        .foregroundStyle(hasProofImage ? .white : Color.fitInk)
                        .shadow(color: hasProofImage ? .black.opacity(0.45) : .clear, radius: 8, x: 0, y: 2)
                        .lineLimit(3)
                }
                .padding()
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding()
        .fitCardSurface()
        .confirmationDialog("Delete this proof?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete proof", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the proof post from Fitcountable.")
        }
    }

    private var relativeDate: String {
        guard post.createdAt != nil else { return "Now" }
        return "Posted"
    }

    private var hasProofImage: Bool {
        proofPhotoData != nil || post.mediaURL != nil
    }
}

private struct ShareLinkButton: View {
    var post: SocialProofPost
    var proofPhotoData: Data?
    @State private var showingFallback = false
    @State private var fallbackImage: UIImage?

    var body: some View {
        Button {
            let image = InstagramStoryShareService.storyImage(for: post, proofPhotoData: proofPhotoData ?? post.mediaURL?.dataURLImageData)
            if InstagramStoryShareService.shareToInstagram(image: image) == false {
                fallbackImage = image
                showingFallback = true
            }
        } label: {
            Label("Story", systemImage: "square.and.arrow.up")
                .font(.caption.weight(.bold))
        }
        .buttonStyle(.bordered)
        .tint(.fitBlue)
        .sheet(isPresented: $showingFallback) {
            if let fallbackImage {
                ActivityView(items: [fallbackImage])
            }
        }
    }
}

private struct ProofChip: View {
    var icon: String
    var text: String
    var tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private enum RequestDirection {
    case incoming
    case outgoing
}

private struct RequestRow: View {
    var result: FriendSearchResult
    var direction: RequestDirection
    var primary: () -> Void
    var secondary: () -> Void

    var body: some View {
        HStack {
            AvatarInitial(name: result.displayName, color: .fitGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .font(.headline)
                Text(direction == .incoming ? "Wants to connect" : "Waiting for approval")
                    .font(.caption)
                    .foregroundStyle(Color.fitMuted)
            }
            Spacer()
            if direction == .incoming {
                Button("Accept", action: primary)
                    .buttonStyle(.borderedProminent)
                    .tint(.fitGreen)
                Button("Decline", action: secondary)
                    .buttonStyle(.bordered)
            } else {
                Button("Cancel", action: primary)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .fitCardSurface()
    }
}

private struct SearchResultRow: View {
    var result: FriendSearchResult
    var add: () -> Void
    var open: () -> Void

    var body: some View {
        HStack {
            Button(action: open) {
                HStack {
                    AvatarInitial(name: result.displayName, color: .fitGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.fitInk)
                        Text(result.relationshipStatusLabel)
                            .font(.caption)
                            .foregroundStyle(Color.fitMuted)
                    }
                }
            }
            Spacer()
            Button(action: add) {
                Image(systemName: result.relationshipStatus == "pending" ? "clock" : "person.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(result.relationshipStatus == "accepted" || result.relationshipStatus == "pending")
        }
    }
}

private struct FriendAccountabilityRow: View {
    var friend: FriendProfile
    var nudge: () -> Void
    var remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AvatarInitial(name: friend.name, color: .fitBlue)
                VStack(alignment: .leading) {
                    Text(friend.name)
                        .font(.headline)
                    Text(friend.status)
                        .foregroundStyle(Color.fitMuted)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.bold))
                    Text("\(friend.streak)d")
                        .font(.subheadline.weight(.black))
                }
                .foregroundStyle(Color.fitGreen)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.fitGreen.opacity(0.12), in: Capsule())
            }
            if let lastNudge = friend.lastNudge {
                Text("Last nudge: \(lastNudge)")
                    .font(.footnote)
                    .foregroundStyle(Color.fitMuted)
            }
            HStack {
                Button(action: nudge) {
                    Label("Nudge", systemImage: "bell.badge")
                }
                .buttonStyle(.bordered)
                Button(action: remove) {
                    Label("Remove", systemImage: "person.crop.circle.badge.minus")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .fitCardSurface()
    }
}

private struct AvatarInitial: View {
    var name: String
    var color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.14))
            .frame(width: 40, height: 40)
            .overlay(Text(String(name.prefix(1))).font(.headline.bold()).foregroundStyle(color))
    }
}

private struct SocialProfileSheet: View {
    @EnvironmentObject private var appState: AppState
    var profile: FriendSearchResult

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        AvatarInitial(name: profile.displayName, color: .fitBlue)
                        VStack(alignment: .leading) {
                            Text(profile.displayName)
                                .font(.title2.bold())
                            Text(profile.relationshipStatusLabel)
                                .foregroundStyle(Color.fitMuted)
                        }
                    }
                    if let loaded = appState.selectedSocialProfile, loaded.profile.id == profile.id {
                        HStack(spacing: 12) {
                            MetricCard(title: "Workouts", value: "\(loaded.stats.workouts)", detail: "logged", color: .fitBlue)
                            MetricCard(title: "Proof", value: "\(loaded.stats.proofPosts)", detail: "visible", color: .fitGreen)
                        }
                        ForEach(loaded.proofPosts) { post in
                            ProofPostCard(post: post, profilePhotoData: nil, proofPhotoData: nil)
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await appState.loadSocialProfile(userId: profile.id)
        }
    }
}

private enum InstagramStoryShareService {
    static func storyImage(for post: SocialProofPost, proofPhotoData: Data?) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor(red: 0.91, green: 0.97, blue: 0.95, alpha: 1).setFill()
            context.fill(rect)

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                UIColor(red: 0.25, green: 0.82, blue: 0.48, alpha: 1).cgColor,
                UIColor(red: 0.16, green: 0.46, blue: 0.95, alpha: 1).cgColor
            ] as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1080, y: 1920), options: [])

            let card = CGRect(x: 90, y: 220, width: 900, height: 1320)
            UIColor.white.withAlphaComponent(0.92).setFill()
            UIBezierPath(roundedRect: card, cornerRadius: 56).fill()

            if let mascot = UIImage(named: "MascotIcon") {
                mascot.draw(in: CGRect(x: 430, y: 290, width: 220, height: 220))
            }

            draw("FITCOUNTABLE PROOF", in: CGRect(x: 130, y: 555, width: 820, height: 60), size: 36, weight: .heavy, color: UIColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1), alignment: .center)
            draw(post.workoutTitle, in: CGRect(x: 140, y: 635, width: 800, height: 150), size: 66, weight: .black, color: .black, alignment: .center)

            let photoFrame = CGRect(x: 155, y: 820, width: 770, height: 470)
            if let proofPhotoData, let proofImage = UIImage(data: proofPhotoData) {
                UIColor(red: 0.92, green: 0.98, blue: 0.95, alpha: 1).setFill()
                UIBezierPath(roundedRect: photoFrame.insetBy(dx: -18, dy: -18), cornerRadius: 44).fill()
                drawImage(proofImage, in: photoFrame, cornerRadius: 34)
            } else {
                UIColor(red: 0.91, green: 0.97, blue: 0.94, alpha: 1).setFill()
                UIBezierPath(roundedRect: photoFrame, cornerRadius: 34).fill()
                draw("PROOF SAVED", in: photoFrame.insetBy(dx: 40, dy: 180), size: 48, weight: .heavy, color: UIColor(red: 0.25, green: 0.82, blue: 0.48, alpha: 1), alignment: .center)
            }

            draw(post.caption ?? "Workout proof logged.", in: CGRect(x: 160, y: 1330, width: 760, height: 120), size: 38, weight: .semibold, color: UIColor.darkGray, alignment: .center)

            if let lines = post.detailLines, lines.isEmpty == false {
                let joined = lines.prefix(2).joined(separator: "\n")
                draw(joined, in: CGRect(x: 170, y: 1435, width: 740, height: 95), size: 30, weight: .medium, color: UIColor.darkGray, alignment: .center)
            }

            let stats = [
                post.proofKind == "food" ? "Food" : (post.durationMinutes.map { "\($0)m" } ?? "Logged"),
                post.proofKind == "food" ? "Meal" : (post.workoutTitle == "Workout proof" ? "Proof" : "Workout"),
                post.visibility.rawValue
            ]
            for (index, stat) in stats.enumerated() {
                let box = CGRect(x: 150 + CGFloat(index) * 270, y: 1545, width: 240, height: 150)
                UIColor(red: 0.91, green: 0.97, blue: 0.94, alpha: 1).setFill()
                UIBezierPath(roundedRect: box, cornerRadius: 28).fill()
                draw(stat, in: box.insetBy(dx: 12, dy: 46), size: 34, weight: .bold, color: .black, alignment: .center)
            }

            draw("Built with Fitcountable", in: CGRect(x: 150, y: 1735, width: 780, height: 70), size: 44, weight: .heavy, color: .white, alignment: .center)
        }
    }

    @MainActor static func shareToInstagram(image: UIImage) -> Bool {
        guard let url = URL(string: "instagram-stories://share"),
              UIApplication.shared.canOpenURL(url),
              let imageData = image.pngData() else {
            return false
        }
        UIPasteboard.general.setItems([[
            "com.instagram.sharedSticker.backgroundImage": imageData
        ]], options: [.expirationDate: Date().addingTimeInterval(300)])
        UIApplication.shared.open(url)
        return true
    }

    private static func draw(_ text: String, in rect: CGRect, size: CGFloat, weight: UIFont.Weight, color: UIColor, alignment: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private static func drawImage(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        path.addClip()

        let imageRatio = image.size.width / max(image.size.height, 1)
        let rectRatio = rect.width / rect.height
        let drawSize: CGSize
        if imageRatio > rectRatio {
            drawSize = CGSize(width: rect.height * imageRatio, height: rect.height)
        } else {
            drawSize = CGSize(width: rect.width, height: rect.width / max(imageRatio, 0.01))
        }
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: drawRect)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImage: (UIImage) -> Void
        var dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

private func compressedProofImage(_ image: UIImage) -> Data? {
    let maxDimension: CGFloat = 1600
    let scale = min(1, maxDimension / max(image.size.width, image.size.height))
    let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let resized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return resized.jpegData(compressionQuality: 0.82)
}
