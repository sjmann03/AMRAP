import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutSet.timestamp, order: .reverse) private var allSets: [WorkoutSet]
    @Query private var gyms: [GymLocation]
    @Query private var templates: [WorkoutTemplate]
    
    // Workout state
    @State private var isWorkoutActive = false
    @State private var workoutStartTime: Date? = nil
    @State private var currentWorkoutId: String? = nil
    @State private var currentGym: String? = nil
    @State private var workoutMode: WorkoutMode = .free
    @State private var activeTemplate: WorkoutTemplate? = nil
    @State private var templateProgress: TemplateProgress? = nil
    @State private var templateWasModified = false
    @State private var exerciseNotes: [String: String] = [:] // exerciseId -> note
    @State private var showConfetti = false
    // Selected exercises
    @State private var selectedExercise: Exercise? = nil
    @State private var selectedExercise2: Exercise? = nil
    
    // Sheet states
    @State private var showStartWorkoutSheet = false
    @State private var showExercisePicker = false
    @State private var showExercise2Picker = false
    @State private var showChangeGymSheet = false
    @State private var showEndWorkoutSheet = false
    @State private var showTemplateSelector = false
    @State private var showCancelConfirmation = false
    @State private var showExerciseNoteModal = false
    @State private var editingSet: WorkoutSet? = nil
    
    // Input states
    @State private var weightInput: String = ""
    @State private var repsInput: String = ""
    @State private var toFailure: Bool = false
    @State private var currentSetType: SetType = .standard
    @State private var showSetTypePicker = false
    
    // Superset inputs
    @State private var weight2Input: String = ""
    @State private var reps2Input: String = ""
    @State private var toFailure2: Bool = false
    
    // Exercise note
    @State private var currentExerciseNote: String = ""
    
    // Timer for duration display
    @State private var workoutDuration: Int = 0
    @State private var durationTimer: Timer? = nil
    
    private var settings: AppSettings {
        if let existing = try? modelContext.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        return newSettings
    }
    
    // Focus state
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case weight, reps, weight2, reps2
    }
    
    enum WorkoutMode {
        case free
        case template
    }
    
    struct TemplateProgress {
        var currentExerciseIndex: Int = 0
        var completedSets: [Int: Int] = [:] // exerciseIndex -> completed count
    }
    
    // Current workout sets
    private var currentWorkoutSets: [WorkoutSet] {
        guard let workoutId = currentWorkoutId else { return [] }
        return allSets.filter { $0.workoutId == workoutId }
    }
    
    // Grouped sets for display
    private var groupedSets: [ExerciseGroup] {
        var groups: [ExerciseGroup] = []
        var processedSuperSetIds: Set<String> = []
        
        let sortedSets = currentWorkoutSets.sorted { $0.timestamp < $1.timestamp }
        
        for set in sortedSets {
            if set.setType == .superSet, let superSetId = set.superSetId {
                if !processedSuperSetIds.contains(superSetId) {
                    let pairedSets = sortedSets.filter { $0.superSetId == superSetId }
                    let exercise1Sets = pairedSets.filter { $0.superSetOrder == 1 }
                    let exercise2Sets = pairedSets.filter { $0.superSetOrder == 2 }
                    
                    if let first = exercise1Sets.first, let second = exercise2Sets.first {
                        // Check if group already exists for this exercise pair
                        if let existingIndex = groups.firstIndex(where: {
                            $0.type == .superset &&
                            $0.exerciseId == first.exerciseId &&
                            $0.exercise2Id == second.exerciseId
                        }) {
                            groups[existingIndex].sets.append(contentsOf: pairedSets)
                        } else {
                            groups.append(ExerciseGroup(
                                type: .superset,
                                exerciseId: first.exerciseId,
                                exerciseName: first.exerciseName,
                                exercise2Id: second.exerciseId,
                                exercise2Name: second.exerciseName,
                                sets: pairedSets
                            ))
                        }
                    }
                    processedSuperSetIds.insert(superSetId)
                }
            } else {
                if let existingIndex = groups.firstIndex(where: {
                    $0.type == .single && $0.exerciseId == set.exerciseId
                }) {
                    groups[existingIndex].sets.append(set)
                } else {
                    groups.append(ExerciseGroup(
                        type: .single,
                        exerciseId: set.exerciseId,
                        exerciseName: set.exerciseName,
                        sets: [set]
                    ))
                }
            }
        }
        
        return groups
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()
                
                if isWorkoutActive {
                    activeWorkoutView
                } else {
                    startWorkoutView
                }
                SimpleConfettiView(isShowing: $showConfetti)

            }
            .navigationTitle("💪 AMRAP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isWorkoutActive {
                    ToolbarItem(placement: .primaryAction) {
                        workoutMenu
                    }
                }
            }
            .sheet(isPresented: $showStartWorkoutSheet) {
                StartWorkoutSheet(
                    gyms: gyms,
                    onStartFree: { gym in startFreeWorkout(gym: gym) },
                    onStartTemplate: { gym in
                        currentGym = gym
                        showStartWorkoutSheet = false
                        showTemplateSelector = true
                    }
                )
                .presentationDetents([.medium])
            }
            .onChange(of: selectedExercise2) { oldValue, newValue in
                if let exercise = newValue {
                    prefillExercise2(exercise: exercise)
                }
            }
            
            .onChange(of: selectedExercise) { oldValue, newValue in
                if let exercise = newValue {
                    prefillFromHistory(exercise: exercise)
                    loadExerciseNote(for: exercise.id)
                    // Reset to standard set type when changing exercises
                   currentSetType = .standard
                   showSetTypePicker = false
                }
            }
            
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(
                    selectedExercise: $selectedExercise,
                    allSets: Array(allSets),
                    currentGym: currentGym
                )
                
            }
            .sheet(isPresented: $showExercise2Picker) {
                ExercisePickerView(
                    selectedExercise: $selectedExercise2,
                    allSets: Array(allSets),
                    currentGym: currentGym
                )

            }
            .sheet(isPresented: $showChangeGymSheet) {
                ChangeGymSheet(
                    gyms: gyms,
                    currentGym: currentGym,
                    onSelectGym: { gym in
                        currentGym = gym
                        saveGymIfNeeded(gym)
                        showChangeGymSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showEndWorkoutSheet) {
                EndWorkoutView(
                    totalSets: currentWorkoutSets.count,
                    exerciseCount: Set(currentWorkoutSets.map { $0.exerciseId }).count,
                    duration: workoutDuration,
                    templateWasModified: templateWasModified,
                    onSave: { note, rpe, saveTemplateChanges in
                        saveWorkout(note: note, rpe: rpe, saveTemplateChanges: saveTemplateChanges)
                    },
                    onCancel: { }
                )
            }
            .sheet(isPresented: $showTemplateSelector) {
                TemplateSelectionView { template in
                    startTemplateWorkout(template: template)
                }
            }
            .sheet(isPresented: $showExerciseNoteModal) {
                ExerciseNoteSheet(
                    exerciseName: selectedExercise?.name ?? "",
                    note: $currentExerciseNote,
                    previousNote: getPreviousNote(for: selectedExercise?.id ?? ""),
                    onSave: {
                        if let exerciseId = selectedExercise?.id {
                            if currentExerciseNote.isEmpty {
                                exerciseNotes.removeValue(forKey: exerciseId)
                            } else {
                                exerciseNotes[exerciseId] = currentExerciseNote
                            }
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $editingSet) { set in
                EditSetSheet(set: set) { newWeight, newReps, newToFailure in
                    updateSet(set, weight: newWeight, reps: newReps, toFailure: newToFailure)
                }
                .presentationDetents([.medium])
            }
            .alert("Cancel Workout?", isPresented: $showCancelConfirmation) {
                Button("Keep Working Out", role: .cancel) { }
                Button("Cancel Workout", role: .destructive) {
                    cancelWorkout()
                }
            } message: {
                Text("Your logged sets will be deleted.")
            }
        }
    }
    
    // MARK: - Workout Menu
    private var workoutMenu: some View {
        Menu {
            if workoutMode == .template {
                Button {
                    switchToFreeWorkout()
                } label: {
                    Label("Switch to Free Workout", systemImage: "sparkles")
                }
                
                Button {
                    showTemplateSelector = true
                } label: {
                    Label("Switch Template", systemImage: "arrow.triangle.2.circlepath")
                }
            } else {
                Button {
                    showTemplateSelector = true
                } label: {
                    Label("Use Template", systemImage: "list.clipboard")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                showCancelConfirmation = true
            } label: {
                Label("Cancel Workout", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    // MARK: - Start Workout View
    private var startWorkoutView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 60))
                    .foregroundColor(.green.opacity(0.8))
                
                Text("Ready to train?")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Button {
                    showStartWorkoutSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                        Text("START WORKOUT")
                            .fontWeight(.black)
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Active Workout View
    private var activeWorkoutView: some View {
        ScrollView {
            VStack(spacing: 16) {
                workoutHeaderCard
                
                if let gym = currentGym, !gym.isEmpty {
                    gymBanner(gym)
                }
                
                // Template Progress
                if workoutMode == .template, let template = activeTemplate {
                    templateProgressSection(template)
                }
                
                exerciseSelectionCard
                
                if selectedExercise != nil {
                    weightRecommendationCard
                    setTypeSelector
                    
                    if currentSetType == .superSet {
                        superSetInputSection
                    } else {
                        standardInputSection
                    }
                    
                    logSetButton
                }
                
                if !currentWorkoutSets.isEmpty {
                    currentWorkoutSummary
                    endWorkoutButton
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Clear") {
                    clearCurrentField()
                }
                
                Spacer()
                
                if focusedField == .weight {
                    Button("Next →") { focusedField = .reps }
                        .fontWeight(.semibold)
                } else if focusedField == .reps && currentSetType == .superSet {
                    Button("Next →") { focusedField = .weight2 }
                        .fontWeight(.semibold)
                } else if focusedField == .weight2 {
                    Button("Next →") { focusedField = .reps2 }
                        .fontWeight(.semibold)
                } else {
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func clearCurrentField() {
        switch focusedField {
        case .weight: weightInput = ""
        case .reps: repsInput = ""
        case .weight2: weight2Input = ""
        case .reps2: reps2Input = ""
        case .none: break
        }
    }
    
    // MARK: - Workout Header
    private var workoutHeaderCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Session")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(workoutMode == .template ?
                     (activeTemplate?.name ?? "Template") : "Free Workout")
                    .font(.headline)
                    .foregroundColor(workoutMode == .template ? .purple : .green)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("\(workoutDuration) min")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    // MARK: - Template Progress Section
    private func templateProgressSection(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let currentIndex = templateProgress?.currentExerciseIndex ?? 0
            let total = template.exercises.count
            let progress = total > 0 ? Double(currentIndex) / Double(total) : 0
            
            HStack {
                Text("Exercise \(min(currentIndex + 1, total)) of \(total)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                
                let completedSets = templateProgress?.completedSets[currentIndex] ?? 0
                let targetSets = template.exercises[safe: currentIndex]?.targetSets ?? 3
                Text("Set \(min(completedSets + 1, targetSets)) of \(targetSets)")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geo.size.width * progress, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            // Control buttons
            HStack(spacing: 12) {
                Button {
                    addSetToTemplate()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("+1 Set")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button {
                    skipToNextExercise()
                } label: {
                    HStack {
                        Image(systemName: "forward.fill")
                        Text("Next Exercise")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.3))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // Next up preview
            if currentIndex < template.exercises.count - 1 {
                let nextEx = template.exercises[currentIndex + 1]
                HStack {
                    Text("Next up:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(nextEx.exerciseName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(nextEx.targetSets) sets")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Gym Banner
    private func gymBanner(_ gym: String) -> some View {
        Button {
            showChangeGymSheet = true
        } label: {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                Text(gym)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Text("tap to change")
                    .font(.caption)
                    .foregroundColor(.gray)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.blue.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Exercise Selection Card
    private var exerciseSelectionCard: some View {
        VStack(spacing: 8) {
            Button {
                showExercisePicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXERCISE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        if let exercise = selectedExercise {
                            Text(exercise.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .lineLimit(1)
                            
                            HStack(spacing: 12) {
                                Label(exercise.primaryMuscle.capitalized, systemImage: "figure.strengthtraining.traditional")
                                Label(exercise.equipment.capitalized, systemImage: "dumbbell.fill")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        } else {
                            Text("Tap to Select Exercise")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Note button
            if let exercise = selectedExercise {
                HStack {
                    Spacer()
                    
                    Button {
                        currentExerciseNote = exerciseNotes[exercise.id] ?? ""
                        showExerciseNoteModal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: exerciseNotes[exercise.id] != nil ? "note.text" : "note.text.badge.plus")
                            Text(exerciseNotes[exercise.id] != nil ? "Edit Note" : "Add Note")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Weight Recommendation Card
    @ViewBuilder
    private var weightRecommendationCard: some View {
        if let exercise = selectedExercise,
           let rec = getWeightRecommendation(for: exercise) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if rec.isFromDifferentLocation {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                    }
                    
                    Text(rec.isFromDifferentLocation ? "Last Workout @ \(rec.locationName)" : "Last Workout")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(rec.isFromDifferentLocation ? .orange : .blue)
                    
                    Spacer()
                    
                    if let date = rec.lastDate {
                        Text(formatRelativeDate(date))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                if !rec.lastSets.isEmpty {
                    let currentSetNum = getCurrentSetNumber(for: exercise.id)
                    
                    HStack(spacing: 8) {
                        ForEach(Array(rec.lastSets.enumerated()), id: \.offset) { index, setInfo in
                            let isCurrentSet = index + 1 == currentSetNum
                            
                            VStack(spacing: 2) {
                                Text("Set \(index + 1)")
                                    .font(.caption2)
                                    .foregroundColor(isCurrentSet ? .white : .gray)
                                Text("\(Int(setInfo.weight))")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(isCurrentSet ? .white : .primary)
                                Text("× \(setInfo.reps)")
                                    .font(.caption)
                                    .foregroundColor(isCurrentSet ? .white.opacity(0.8) : .gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isCurrentSet ? themeColor : Color.gray.opacity(0.15))
                            .cornerRadius(6)
                        }
                    }
                }
                
                if let message = rec.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(rec.isFromDifferentLocation ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Set Type Selector
    private var setTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSetTypePicker.toggle()
                }
                focusedField = nil
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set Type")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(currentSetType.displayName)
                            .fontWeight(.semibold)
                            .foregroundColor(setTypeColor(currentSetType))
                    }
                    Spacer()
                    Image(systemName: showSetTypePicker ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            if showSetTypePicker {
                HStack(spacing: 8) {
                    ForEach(SetType.allCases, id: \.self) { type in
                        Button {
                            currentSetType = type
                            if type == .superSet {
                                selectedExercise2 = nil
                                weight2Input = ""
                                reps2Input = ""
                            }
                            withAnimation { showSetTypePicker = false }
                        } label: {
                            Text(type.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(currentSetType == type ? setTypeColor(type) : Color.gray.opacity(0.2))
                                .foregroundColor(currentSetType == type ? .white : .gray)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private func setTypeColor(_ type: SetType) -> Color {
        switch type {
        case .standard: return .green
        case .warmup: return .orange
        case .drop: return .purple
        case .superSet: return .blue
        }
    }
    
    // MARK: - Standard Input Section
    private var standardInputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEIGHT (LBS)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    TextField("0", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .weight)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    TextField("0", text: $repsInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .reps)
                }
            }
            
            // Quick weight buttons
            HStack(spacing: 8) {
                ForEach([-10, -5, 5, 10], id: \.self) { delta in
                    Button {
                        adjustWeight(by: delta, input: &weightInput)
                    } label: {
                        Text(delta > 0 ? "+\(delta)" : "\(delta)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(delta > 0 ? .green : .red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            
            toFailureButton(isOn: $toFailure)
        }
    }
    
    // MARK: - Super Set Input Section
    private var superSetInputSection: some View {
        VStack(spacing: 16) {
            // Exercise 1
            VStack(alignment: .leading, spacing: 8) {
                Text("Exercise 1: \(selectedExercise?.name ?? "-")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                HStack(spacing: 12) {
                    TextField("Weight", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .weight)
                    
                    TextField("Reps", text: $repsInput)
                        .keyboardType(.numberPad)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .reps)
                }
                
                toFailureButton(isOn: $toFailure)
            }
            
            Divider().background(Color.gray)
            
            // Exercise 2
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let ex2 = selectedExercise2 {
                        Text("Exercise 2: \(ex2.name)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    } else {
                        Text("Exercise 2: Not selected")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button {
                        showExercise2Picker = true
                    } label: {
                        Text(selectedExercise2 == nil ? "Select" : "Change")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                if selectedExercise2 != nil {
                    HStack(spacing: 12) {
                        TextField("Weight", text: $weight2Input)
                            .keyboardType(.decimalPad)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                            .focused($focusedField, equals: .weight2)
                        
                        TextField("Reps", text: $reps2Input)
                            .keyboardType(.numberPad)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                            .focused($focusedField, equals: .reps2)
                    }
                    
                    toFailureButton(isOn: $toFailure2)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - To Failure Button
    private func toFailureButton(isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack {
                Image(systemName: isOn.wrappedValue ? "flame.fill" : "flame")
                    .foregroundColor(isOn.wrappedValue ? .orange : .gray)
                Text("To Failure")
                    .fontWeight(.medium)
                    .foregroundColor(isOn.wrappedValue ? .orange : .white)
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn.wrappedValue ? .orange : .gray)
            }
            .padding()
            .background(isOn.wrappedValue ? Color.orange.opacity(0.15) : Color.gray.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Log Set Button
    private var logSetButton: some View {
        Button {
            if currentSetType == .superSet {
                logSuperSet()
            } else {
                logSingleSet()
            }
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("LOG SET")
                    .fontWeight(.black)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: canLogSet ? [.green, .green.opacity(0.7)] : [.gray.opacity(0.5), .gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: canLogSet ? .green.opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .disabled(!canLogSet)
    }
    
    private var canLogSet: Bool {
        // Weight can be empty (bodyweight exercises) or valid number
        let weightValid = weightInput.isEmpty || Double(weightInput) != nil
        
        // Reps required
        guard !repsInput.isEmpty, Int(repsInput) != nil, weightValid else {
            return false
        }
        
        if currentSetType == .superSet {
            let weight2Valid = weight2Input.isEmpty || Double(weight2Input) != nil
            guard selectedExercise2 != nil,
                  !reps2Input.isEmpty, Int(reps2Input) != nil,
                  weight2Valid else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Current Workout Summary
    private var currentWorkoutSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Workout")
                    .font(.headline)
                Spacer()
                Text("\(currentWorkoutSets.count) sets")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            ForEach(groupedSets) { group in
                if group.type == .superset {
                    SuperSetGroupCard(
                        group: group,
                        isCurrentExercise: selectedExercise?.id == group.exerciseId ||
                                          selectedExercise?.id == group.exercise2Id,
                        onTap: {
                            if let ex = exercises.first(where: { $0.id == group.exerciseId }) {
                                selectedExercise = ex
                                prefillFromHistory(exercise: ex)
                            }
                            if let ex2 = exercises.first(where: { $0.id == group.exercise2Id }) {
                                selectedExercise2 = ex2
                                prefillExercise2(exercise: ex2)
                            }
                            currentSetType = .superSet
                        },
                        onEditSet: { set in editingSet = set },
                        onDeleteSet: { set in deleteSet(set) }
                    )
                } else {
                    SingleExerciseGroupCard(
                        group: group,
                        isCurrentExercise: selectedExercise?.id == group.exerciseId,
                        note: exerciseNotes[group.exerciseId],
                        onTap: {
                            if let ex = exercises.first(where: { $0.id == group.exerciseId }) {
                                selectedExercise = ex
                                prefillFromHistory(exercise: ex)
                                loadExerciseNote(for: group.exerciseId)
                            }
                            if currentSetType == .superSet {
                                currentSetType = .standard
                            }
                        },
                        onEditSet: { set in editingSet = set },
                        onDeleteSet: { set in deleteSet(set) }
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - End Workout Button
    private var endWorkoutButton: some View {
        Button {
            showEndWorkoutSheet = true
        } label: {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                Text("SAVE & END WORKOUT")
                    .fontWeight(.bold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Functions
    
    private func adjustWeight(by delta: Int, input: inout String) {
        let current = Double(input) ?? 0
        let newWeight = max(0, current + Double(delta))
        input = newWeight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", newWeight)
            : String(format: "%.1f", newWeight)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days)d ago"
        }
    }
    
    // MARK: - Weight Recommendation

    struct WeightRecommendation {
        let weight: Double
        let reps: Int
        let lastSets: [(weight: Double, reps: Int)]
        let isFromDifferentLocation: Bool
        let locationName: String
        let lastDate: Date?
        let message: String?
    }

    private func getWeightRecommendation(for exercise: Exercise) -> WeightRecommendation? {
        let currentGymName = currentGym ?? "default"
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        
        // Get all sets for this exercise (excluding current workout)
        let exerciseSets = allSets.filter {
            $0.exerciseId == exercise.id && $0.workoutId != currentWorkoutId
        }
        
        guard !exerciseSets.isEmpty else { return nil }
        
        func normalizeGym(_ gym: String?) -> String {
                return (gym ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        
           // Get sets from current location (normalized comparison)
           let setsFromCurrentLocation = exerciseSets.filter {
               normalizeGym($0.gym) == currentGymName ||
               (currentGymName.isEmpty && normalizeGym($0.gym).isEmpty)
           }
           
           // Check if we have recent data at current location (within last 2 months)
           let recentSetsFromCurrentLocation = setsFromCurrentLocation.filter { $0.timestamp >= twoMonthsAgo }
           
           let recentSets: [WorkoutSet]
           let isFromDifferentLocation: Bool
           let locationName: String
           
           if !recentSetsFromCurrentLocation.isEmpty {
               // Use recent data from current location
               let mostRecentWorkoutId = recentSetsFromCurrentLocation.first!.workoutId
               recentSets = recentSetsFromCurrentLocation.filter { $0.workoutId == mostRecentWorkoutId }
               isFromDifferentLocation = false
               locationName = currentGym ?? "Unknown"
           } else if !setsFromCurrentLocation.isEmpty {
               // Use older data from current location (beyond 2 months but same gym)
               let mostRecentWorkoutId = setsFromCurrentLocation.first!.workoutId
               recentSets = setsFromCurrentLocation.filter { $0.workoutId == mostRecentWorkoutId }
               isFromDifferentLocation = false
               locationName = currentGym ?? "Unknown"
           } else {
               // No data at current location - fall back to most recent from ANY location
               let mostRecentWorkoutId = exerciseSets.first!.workoutId
               recentSets = exerciseSets.filter { $0.workoutId == mostRecentWorkoutId }
               isFromDifferentLocation = true
               locationName = recentSets.first?.gym ?? "Unknown"
           }
        
        // Get working sets (no warmups, no drop set portions)
        let workingSets = recentSets
            .filter { $0.setType != .warmup && $0.dropIndex == 0 }
            .sorted { $0.timestamp < $1.timestamp }
        
        guard !workingSets.isEmpty else { return nil }
        
        let lastSetsInfo = workingSets.map { (weight: $0.weight, reps: $0.reps) }
        let lastDate = workingSets.first?.timestamp
        
        // Get current set number for this exercise in this workout
        let currentSetNumber = getCurrentSetNumber(for: exercise.id)
        
        // Get the weight/reps for the corresponding set (or last set if we've done more)
        let setIndex = min(currentSetNumber, lastSetsInfo.count) - 1
        let prefillSet = setIndex >= 0 ? lastSetsInfo[max(0, setIndex)] : lastSetsInfo[0]
        
        // Build appropriate message
        var message: String? = nil
        if isFromDifferentLocation {
            if let date = lastDate {
                let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                if daysSince > 30 {
                    message = "⚠️ From \(locationName) (\(daysSince)d ago) - no recent data at current gym"
                } else {
                    message = "⚠️ From \(locationName) - equipment may vary"
                }
            } else {
                message = "⚠️ From \(locationName) - equipment may vary"
            }
        }
        
        return WeightRecommendation(
            weight: prefillSet.weight,
            reps: prefillSet.reps,
            lastSets: lastSetsInfo,
            isFromDifferentLocation: isFromDifferentLocation,
            locationName: locationName,
            lastDate: lastDate,
            message: message
        )
    }

    // Helper function to get current set number for an exercise
    private func getCurrentSetNumber(for exerciseId: String) -> Int {
        let exerciseSets = currentWorkoutSets
            .filter { $0.exerciseId == exerciseId && $0.setType != .warmup && $0.dropIndex == 0 }
        return exerciseSets.count + 1
    }
    // MARK: - PR Detection
    private func checkForPRAndCelebrate(exercise: Exercise, weight: Double, reps: Int) {
        // Check if confetti is enabled in settings
        guard settings.showConfetti else { return }
        
        // Skip if weight is 0 (bodyweight)
        guard weight > 0 else { return }
        
        // Find the previous best for this exercise (from previous workouts only)
        let previousSets = allSets.filter {
            $0.exerciseId == exercise.id && $0.workoutId != currentWorkoutId
        }
        
        // No history = can't be a PR (it's their first time)
        guard !previousSets.isEmpty else { return }
        
        let previousMaxWeight = previousSets.map { $0.weight }.max() ?? 0
        
        // Check if this is a new PR (higher weight)
        if weight > previousMaxWeight {
            // It's a PR! 🎉
            withAnimation {
                showConfetti = true
            }
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    private func prefillFromHistory(exercise: Exercise) {
        if let rec = getWeightRecommendation(for: exercise) {
            weightInput = rec.weight.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", rec.weight)
                : String(format: "%.1f", rec.weight)
            repsInput = String(rec.reps)
            toFailure = false
        }
        // If no recommendation found, don't clear - keep current values
    }
    
    private func prefillExercise2(exercise: Exercise) {
        if let rec = getWeightRecommendation(for: exercise) {
            weight2Input = rec.weight.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", rec.weight)
                : String(format: "%.1f", rec.weight)
            reps2Input = String(rec.reps)
        } else {
            weight2Input = ""
            reps2Input = ""
        }
        toFailure2 = false
    }
    
    private func loadExerciseNote(for exerciseId: String) {
        currentExerciseNote = exerciseNotes[exerciseId] ?? ""
    }
    
    private func getPreviousNote(for exerciseId: String) -> String? {
        let previousSets = allSets.filter { $0.exerciseId == exerciseId && $0.exerciseNote != nil }
        return previousSets.first?.exerciseNote
    }
    
    private func saveGymIfNeeded(_ gym: String?) {
        guard let gymName = gym, !gymName.isEmpty else { return }
        if !gyms.contains(where: { $0.name == gymName }) {
            let newGym = GymLocation(name: gymName)
            modelContext.insert(newGym)
        }
    }
    
    // MARK: - Workout Lifecycle
    
    private func startFreeWorkout(gym: String?) {
        saveGymIfNeeded(gym)
        currentGym = gym
        currentWorkoutId = Foundation.UUID().uuidString
        workoutStartTime = Date()
        workoutMode = .free
        isWorkoutActive = true
        startDurationTimer()
        showStartWorkoutSheet = false
    }
    
    private func startTemplateWorkout(template: WorkoutTemplate) {
        saveGymIfNeeded(currentGym)
        currentWorkoutId = Foundation.UUID().uuidString
        workoutStartTime = Date()
        workoutMode = .template
        activeTemplate = template
        templateProgress = TemplateProgress()
        templateWasModified = false
        isWorkoutActive = true
        startDurationTimer()
        
        // Select first exercise
        if let firstEx = template.exercises.first,
           let exercise = exercises.first(where: { $0.id == firstEx.exerciseId }) {
            selectedExercise = exercise
            prefillFromHistory(exercise: exercise)
            currentSetType = SetType(rawValue: firstEx.setType) ?? .standard
            
            // Load superset exercise if applicable
            if firstEx.setType == "super",
               let supersetId = firstEx.supersetExerciseId,
               let exercise2 = exercises.first(where: { $0.id == supersetId }) {
                selectedExercise2 = exercise2
                prefillExercise2(exercise: exercise2)
            }
        }
        
        showTemplateSelector = false
    }
    
    private func switchToFreeWorkout() {
        workoutMode = .free
        activeTemplate = nil
        templateProgress = nil
    }
    
    private func addSetToTemplate() {
        guard var progress = templateProgress else { return }
        let currentIndex = progress.currentExerciseIndex
        activeTemplate?.exercises[currentIndex].targetSets += 1
        templateWasModified = true
    }
    
    private func skipToNextExercise() {
        guard let template = activeTemplate,
              var progress = templateProgress else { return }
        
        let nextIndex = progress.currentExerciseIndex + 1
        
        if nextIndex >= template.exercises.count {
            showEndWorkoutSheet = true
            return
        }
        
        progress.currentExerciseIndex = nextIndex
        templateProgress = progress
        
        let nextEx = template.exercises[nextIndex]
        if let exercise = exercises.first(where: { $0.id == nextEx.exerciseId }) {
            selectedExercise = exercise
            prefillFromHistory(exercise: exercise)
            currentSetType = SetType(rawValue: nextEx.setType) ?? .standard
            
            // Load superset exercise if applicable
            if nextEx.setType == "super",
               let supersetId = nextEx.supersetExerciseId,
               let exercise2 = exercises.first(where: { $0.id == supersetId }) {
                selectedExercise2 = exercise2
                prefillExercise2(exercise: exercise2)
            } else {
                selectedExercise2 = nil
                weight2Input = ""
                reps2Input = ""
            }
        }
    }
    
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            if let start = workoutStartTime {
                workoutDuration = Int(Date().timeIntervalSince(start) / 60)
            }
        }
    }
    
    // MARK: - Logging Functions
    
    private func calculateSetGrouping(exerciseId: String, newWeight: Double) -> (setGroup: Int, dropIndex: Int, isDropSet: Bool) {
        let exerciseSets = currentWorkoutSets
            .filter { $0.exerciseId == exerciseId }
            .sorted { $0.timestamp < $1.timestamp }
        
        if exerciseSets.isEmpty {
            return (1, 0, false)
        }
        
        let lastSet = exerciseSets.last!
        let lastSetGroup = lastSet.setGroup
        let lastDropIndex = lastSet.dropIndex
        let lastWeight = lastSet.weight
        
        let isInDropMode = currentSetType == .drop || lastSet.setType == .drop || lastDropIndex > 0
        
        if isInDropMode && newWeight < lastWeight && newWeight > 0 && lastWeight > 0 {
            return (lastSetGroup, lastDropIndex + 1, true)
        }
        
        return (lastSetGroup + 1, 0, false)
    }
    
    private func logSingleSet() {
        guard let exercise = selectedExercise,
              let reps = Int(repsInput),
              let workoutId = currentWorkoutId else { return }
        
        let weight = Double(weightInput) ?? 0
        
        let (setGroup, dropIndex, isDropSet) = calculateSetGrouping(exerciseId: exercise.id, newWeight: weight)
        
        let newSet = WorkoutSet(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
            muscleGroups: exercise.muscleGroups,
            equipment: exercise.equipment,
            category: exercise.category,
            split: exercise.split,
            weight: weight,
            reps: reps,
            setType: isDropSet ? .drop : currentSetType,
            toFailure: toFailure,
            setGroup: setGroup,
            dropIndex: dropIndex,
            workoutId: workoutId,
            gym: currentGym,
            exerciseNote: exerciseNotes[exercise.id]
        )
        
        modelContext.insert(newSet)
        checkForPRAndCelebrate(exercise: exercise, weight: weight, reps: reps)
        // Start rest timer if enabled
        if let settings = try? modelContext.fetch(FetchDescriptor<AppSettings>()).first {
            if settings.autoStartTimer {
                NotificationCenter.default.post(
                    name: NSNotification.Name("StartRestTimer"),
                    object: settings.restTime
                )
            }
        } else {
            if TimerManager.shared.autoStartTimer {
                NotificationCenter.default.post(
                    name: NSNotification.Name("StartRestTimer"),
                    object: nil
                )
            }
        }
        
        if workoutMode == .template {
            updateTemplateProgress()
        }
        
        toFailure = false
        focusedField = nil
        
        // Smart prefill - only if there's history from PREVIOUS workouts
        // If no history, keep current values so user doesn't have to retype
        let hasHistoryFromPreviousWorkouts = allSets.contains {
            $0.exerciseId == exercise.id && $0.workoutId != workoutId
        }
        
        if hasHistoryFromPreviousWorkouts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                prefillFromHistory(exercise: exercise)
            }
        }
        // If no history, weight and reps stay as they are for convenience
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func logSuperSet() {
        guard let exercise1 = selectedExercise,
              let exercise2 = selectedExercise2,
              let reps1 = Int(repsInput),
              let reps2 = Int(reps2Input),
              let workoutId = currentWorkoutId else { return }
        
        let weight1 = Double(weightInput) ?? 0
        let weight2 = Double(weight2Input) ?? 0
        
        let superSetId = Foundation.UUID().uuidString
        let timestamp = Date()
        
        let existingSuperSets = currentWorkoutSets.filter {
            $0.setType == .superSet &&
            $0.exerciseId == exercise1.id &&
            $0.superSetOrder == 1
        }
        let pairNumber = existingSuperSets.count + 1
        
        let set1 = WorkoutSet(
            exerciseId: exercise1.id,
            exerciseName: exercise1.name,
            primaryMuscle: exercise1.primaryMuscle,
            muscleGroups: exercise1.muscleGroups,
            equipment: exercise1.equipment,
            category: exercise1.category,
            split: exercise1.split,
            weight: weight1,
            reps: reps1,
            setType: .superSet,
            toFailure: toFailure,
            setGroup: pairNumber,
            superSetId: superSetId,
            superSetOrder: 1,
            workoutId: workoutId,
            gym: currentGym,
            exerciseNote: exerciseNotes[exercise1.id]
        )
        set1.timestamp = timestamp
        
        let set2 = WorkoutSet(
            exerciseId: exercise2.id,
            exerciseName: exercise2.name,
            primaryMuscle: exercise2.primaryMuscle,
            muscleGroups: exercise2.muscleGroups,
            equipment: exercise2.equipment,
            category: exercise2.category,
            split: exercise2.split,
            weight: weight2,
            reps: reps2,
            setType: .superSet,
            toFailure: toFailure2,
            setGroup: pairNumber,
            superSetId: superSetId,
            superSetOrder: 2,
            workoutId: workoutId,
            gym: currentGym,
            exerciseNote: exerciseNotes[exercise2.id]
        )
        set2.timestamp = timestamp.addingTimeInterval(0.001)
        
        modelContext.insert(set1)
        modelContext.insert(set2)
        checkForPRAndCelebrate(exercise: exercise1, weight: weight1, reps: reps1)
        checkForPRAndCelebrate(exercise: exercise2, weight: weight2, reps: reps2)

        // Update template progress ONCE for the pair
        if workoutMode == .template {
            updateTemplateProgress()
        }
        
        toFailure = false
        toFailure2 = false
        focusedField = nil
        
        // Prefill for next set
           DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
               if let ex1 = selectedExercise {
                   prefillFromHistory(exercise: ex1)
               }
               if let ex2 = selectedExercise2 {
                   prefillExercise2(exercise: ex2)
               }
           }
           
           UIImpactFeedbackGenerator(style: .medium).impactOccurred()
       }
    
    private func updateTemplateProgress() {
        guard let template = activeTemplate,
              var progress = templateProgress else { return }
        
        let currentIndex = progress.currentExerciseIndex
        let newCompletedSets = (progress.completedSets[currentIndex] ?? 0) + 1
        progress.completedSets[currentIndex] = newCompletedSets
        templateProgress = progress
        
        let targetSets = template.exercises[safe: currentIndex]?.targetSets ?? 3
        
        if newCompletedSets >= targetSets {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.skipToNextExercise()
            }
        }
    }
    
    private func updateSet(_ set: WorkoutSet, weight: Double, reps: Int, toFailure: Bool) {
        set.weight = weight
        set.reps = reps
        set.toFailure = toFailure
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func deleteSet(_ set: WorkoutSet) {
        if set.setType == .superSet, let superSetId = set.superSetId {
            let pairedSets = currentWorkoutSets.filter { $0.superSetId == superSetId }
            for pairedSet in pairedSets {
                modelContext.delete(pairedSet)
            }
        } else {
            modelContext.delete(set)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func saveWorkout(note: String?, rpe: Int?, saveTemplateChanges: Bool) {
        guard let workoutId = currentWorkoutId,
              let startTime = workoutStartTime else { return }
        
        let duration = Int(Date().timeIntervalSince(startTime) / 60)
        
        // Apply exercise notes to ALL sets for each exercise
        for (exerciseId, exerciseNote) in exerciseNotes {
            let setsForExercise = currentWorkoutSets.filter { $0.exerciseId == exerciseId }
            for set in setsForExercise {
                set.exerciseNote = exerciseNote
            }
        }
        
        let workout = Workout(
            id: workoutId,
            date: Date(),
            startedAt: startTime,
            endedAt: Date(),
            gym: currentGym,
            duration: duration,
            exerciseNames: Array(Set(currentWorkoutSets.map { $0.exerciseName })),
            totalSets: currentWorkoutSets.count,
            totalVolume: currentWorkoutSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) },
            notes: note,
            rpe: rpe
        )
        
        modelContext.insert(workout)
        
        if saveTemplateChanges, let template = activeTemplate {
            template.lastUsed = Date()
        }
        
        endWorkoutCleanup()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func cancelWorkout() {
        // Stop the rest timer
       TimerManager.shared.stopTimer()
        for set in currentWorkoutSets {
            modelContext.delete(set)
        }
        endWorkoutCleanup()
    }
    
    private func endWorkoutCleanup() {
        // Stop the rest timer
        TimerManager.shared.stopTimer()
        
        durationTimer?.invalidate()
        durationTimer = nil
        isWorkoutActive = false
        currentWorkoutId = nil
        workoutStartTime = nil
        workoutDuration = 0
        currentGym = nil
        workoutMode = .free
        activeTemplate = nil
        templateProgress = nil
        templateWasModified = false
        selectedExercise = nil
        selectedExercise2 = nil
        exerciseNotes = [:]
        resetInputs()
    }
    
    private func resetInputs() {
        weightInput = ""
        repsInput = ""
        weight2Input = ""
        reps2Input = ""
        toFailure = false
        toFailure2 = false
        currentSetType = .standard
        currentExerciseNote = ""
    }
}

// MARK: - Exercise Group Models

enum GroupType {
    case single
    case superset
}

struct ExerciseGroup: Identifiable {
    let id = UUID()
    let type: GroupType
    let exerciseId: String
    let exerciseName: String
    var exercise2Id: String?
    var exercise2Name: String?
    var sets: [WorkoutSet]
}

// MARK: - Array Safe Subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - SuperSet Group Card
struct SuperSetGroupCard: View {
    let group: ExerciseGroup
    let isCurrentExercise: Bool
    let onTap: () -> Void
    let onEditSet: (WorkoutSet) -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    
    private var superSetPairs: [[(set: WorkoutSet, order: Int)]] {
        var pairs: [[(set: WorkoutSet, order: Int)]] = []
        
        let ex1Sets = group.sets.filter { $0.superSetOrder == 1 }.sorted { $0.timestamp < $1.timestamp }
        let ex2Sets = group.sets.filter { $0.superSetOrder == 2 }.sorted { $0.timestamp < $1.timestamp }
        
        let pairCount = max(ex1Sets.count, ex2Sets.count)
        
        for i in 0..<pairCount {
            var pair: [(set: WorkoutSet, order: Int)] = []
            if i < ex1Sets.count {
                pair.append((set: ex1Sets[i], order: 1))
            }
            if i < ex2Sets.count {
                pair.append((set: ex2Sets[i], order: 2))
            }
            if !pair.isEmpty {
                pairs.append(pair)
            }
        }
        
        return pairs
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text("SUPER SET")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        
                        Text("\(group.exerciseName) + \(group.exercise2Name ?? "")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isCurrentExercise ? .purple : .white)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Text("\(superSetPairs.count) \(superSetPairs.count == 1 ? "set" : "sets")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            
            ForEach(Array(superSetPairs.enumerated()), id: \.offset) { pairIndex, pair in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set \(pairIndex + 1)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    
                    if let set1 = pair.first(where: { $0.order == 1 })?.set {
                        HStack {
                            Text("\(Int(set1.weight)) lbs × \(set1.reps)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            if set1.toFailure {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let set2 = pair.first(where: { $0.order == 2 })?.set {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.purple.opacity(0.5))
                                .frame(width: 2)
                                .padding(.leading, 12)
                            
                            HStack {
                                Text("\(Int(set2.weight)) lbs × \(set2.reps)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                if set2.toFailure {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(isCurrentExercise ? Color.purple.opacity(0.15) : Color.purple.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

// MARK: - Single Exercise Group Card
struct SingleExerciseGroupCard: View {
    let group: ExerciseGroup
    let isCurrentExercise: Bool
    let note: String?
    let onTap: () -> Void
    let onEditSet: (WorkoutSet) -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    
    @State private var expandedSetId: UUID? = nil
    
    private var workingSetCount: Int {
        group.sets.filter { $0.dropIndex == 0 }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack {
                    Text(group.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentExercise ? .green : .white)
                    
                    if isCurrentExercise {
                        Text("(current)")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Text("\(workingSetCount) \(workingSetCount == 1 ? "set" : "sets")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if let note = note, !note.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption2)
                    Text(note)
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            
            ForEach(group.sets) { set in
                SetRowView(
                    set: set,
                    isExpanded: expandedSetId == set.id,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedSetId = expandedSetId == set.id ? nil : set.id
                        }
                    },
                    onEdit: { onEditSet(set) },
                    onDelete: { onDeleteSet(set) }
                )
            }
        }
        .padding()
        .background(isCurrentExercise ? Color.green.opacity(0.1) : Color.gray.opacity(0.15))
        .cornerRadius(10)
    }
}

// MARK: - Set Row View
struct SetRowView: View {
    let set: WorkoutSet
    let isExpanded: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var isDropPortion: Bool {
        return set.dropIndex > 0
    }
    private var setLabel: String {
        if set.dropIndex > 0 {
            let letterCode = 97 + set.dropIndex
            if let scalar = UnicodeScalar(letterCode) {
                return "\(set.setGroup)\(Character(scalar))"
            }
        }
        return "\(set.setGroup)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack {
                    if isDropPortion {
                        Rectangle()
                            .fill(Color.purple.opacity(0.5))
                            .frame(width: 2, height: 20)
                            .padding(.leading, 8)
                    }
                    
                    Text(setLabel)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: isDropPortion ? 30 : 35, alignment: .leading)
                    
                    if set.setType == .warmup {
                        Text("W")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    } else if set.setType == .drop || isDropPortion {
                        Text("D")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.3))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                    
                    Text("\(Int(set.weight)) lbs × \(set.reps)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if set.toFailure {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 6)
                .padding(.leading, isDropPortion ? 12 : 0)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                HStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button {
                        onDelete()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
                .padding(.leading, isDropPortion ? 24 : 0)
            }
        }
    }
}

// MARK: - Template Selection View
struct TemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.lastUsed, order: .reverse) private var templates: [WorkoutTemplate]
    
    let onSelect: (WorkoutTemplate) -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Templates")
                            .font(.headline)
                        Text("Create templates in the Templates tab first")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(templates) { template in
                                Button {
                                    onSelect(template)
                                    dismiss()
                                } label: {
                                    TemplateSelectionCard(template: template)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Template Selection Card
struct TemplateSelectionCard: View {
    let template: WorkoutTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            Text("\(template.exercises.count) exercises")
                .font(.caption)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(template.exercises.prefix(3).enumerated()), id: \.offset) { index, exercise in
                    HStack(spacing: 6) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 18, alignment: .leading)
                        
                        if exercise.setType == "super", let supersetName = exercise.supersetExerciseName {
                            HStack(spacing: 4) {
                                Text(exercise.exerciseName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text("+")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                                Text(supersetName)
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .lineLimit(1)
                            }
                        } else {
                            Text(exercise.exerciseName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text("\(exercise.targetSets)×")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if template.exercises.count > 3 {
                    Text("+ \(template.exercises.count - 3) more exercises")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 24)
                }
            }
            
            if let lastUsed = template.lastUsed {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Last: \(lastUsed.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                }
                .foregroundColor(.gray)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}


#Preview {
    WorkoutView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, Workout.self, GymLocation.self, WorkoutTemplate.self], inMemory: true)
}
