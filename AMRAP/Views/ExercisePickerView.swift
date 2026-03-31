import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    
    @Binding var selectedExercise: Exercise?
    var allSets: [WorkoutSet] = []
    var currentGym: String? = nil
    
    @State private var searchText = ""
    @State private var expandedMuscle: String? = nil
    @State private var selectedEquipment: String? = nil
    @State private var expandedExerciseId: String? = nil
    @State private var showExerciseInfo: Exercise? = nil
    @State private var showAddExercise = false
    @State private var hasLoadedExercises = false
    
    let muscles = ["Chest", "Back", "Lats", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves", "Core", "Forearms", "Traps"]
    let equipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Kettlebell", "Bands", "Other"]
    
    var filteredExercises: [Exercise] {
        var result = exercises
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let muscle = expandedMuscle {
            result = result.filter { $0.primaryMuscle.localizedCaseInsensitiveContains(muscle) }
        }
        
        if let equipment = selectedEquipment {
            result = result.filter { $0.equipment.localizedCaseInsensitiveContains(equipment) }
        }
        
        return result
    }
    
    // Group exercises by muscle
    private func exercisesForMuscle(_ muscle: String) -> [Exercise] {
        var result = exercises.filter { $0.primaryMuscle.localizedCaseInsensitiveContains(muscle) }
        
        if let equipment = selectedEquipment {
            result = result.filter { $0.equipment.localizedCaseInsensitiveContains(equipment) }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Equipment filter pills
                equipmentFilter
                
                // Main content
                if !searchText.isEmpty {
                    // Search results mode
                    searchResultsList
                } else {
                    // Muscle group sections mode
                    muscleGroupList
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddExercise = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                if !hasLoadedExercises {
                    loadDefaultExercisesIfNeeded()
                    hasLoadedExercises = true
                }
            }
            .sheet(item: $showExerciseInfo) { exercise in
                ExerciseInfoView(exercise: exercise, allSets: allSets)
            }
            .sheet(isPresented: $showAddExercise) {
                AddCustomExerciseView()
            }
        }
    }
    
    // MARK: - Equipment Filter
    private var equipmentFilter: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All button
                    Button {
                        withAnimation { selectedEquipment = nil }
                    } label: {
                        Text("All")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedEquipment == nil ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedEquipment == nil ? .white : .primary)
                            .cornerRadius(8)
                    }
                    
                    ForEach(equipmentTypes, id: \.self) { equipment in
                        Button {
                            withAnimation {
                                selectedEquipment = selectedEquipment == equipment ? nil : equipment
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: equipmentIcon(equipment))
                                    .font(.caption)
                                Text(equipment)
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedEquipment == equipment ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedEquipment == equipment ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    private func equipmentIcon(_ equipment: String) -> String {
        switch equipment.lowercased() {
        case "barbell": return "figure.strengthtraining.traditional"
        case "dumbbell": return "dumbbell.fill"
        case "cable": return "cable.connector"
        case "machine": return "gearshape.fill"
        case "bodyweight": return "figure.walk"
        case "kettlebell": return "figure.highintensity.intervaltraining"
        case "bands": return "circle.dotted"
        default: return "questionmark.circle"
        }
    }
    
    // MARK: - Search Results List
    private var searchResultsList: some View {
        Group {
            if filteredExercises.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("\(filteredExercises.count) results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        ForEach(filteredExercises) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Muscle Group List
    private var muscleGroupList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(muscles, id: \.self) { muscle in
                    let exerciseCount = exercisesForMuscle(muscle).count
                    
                    if exerciseCount > 0 || selectedEquipment == nil {
                        muscleGroupSection(muscle: muscle, count: exerciseCount)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Muscle Group Section
    private func muscleGroupSection(muscle: String, count: Int) -> some View {
        VStack(spacing: 0) {
            // Section Header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedMuscle == muscle {
                        expandedMuscle = nil
                    } else {
                        expandedMuscle = muscle
                        expandedExerciseId = nil
                    }
                }
            } label: {
                HStack {
                    Image(systemName: muscleIcon(muscle))
                        .font(.title3)
                        .foregroundColor(muscleColor(muscle))
                        .frame(width: 32)
                    
                    Text(muscle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                    
                    Image(systemName: expandedMuscle == muscle ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(expandedMuscle == muscle ? muscleColor(muscle).opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded Exercises
            if expandedMuscle == muscle {
                let muscleExercises = exercisesForMuscle(muscle)
                
                if muscleExercises.isEmpty {
                    HStack {
                        Text("No exercises match your filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                } else {
                    ForEach(muscleExercises) { exercise in
                        exerciseRow(exercise, indented: true)
                    }
                }
            }
            
            Divider()
        }
    }
    
    private func muscleIcon(_ muscle: String) -> String {
        switch muscle.lowercased() {
        case "chest": return "heart.fill"
        case "back", "lats": return "figure.rowing"
        case "shoulders": return "figure.arms.open"
        case "biceps": return "figure.arms.open"
        case "triceps": return "figure.arms.open"
        case "quads", "hamstrings", "glutes": return "figure.walk"
        case "calves": return "figure.stand"
        case "core": return "figure.core.training"
        case "forearms": return "hand.raised.fill"
        case "traps": return "figure.walk"
        default: return "figure.strengthtraining.traditional"
        }
    }
    
    private func muscleColor(_ muscle: String) -> Color {
        switch muscle.lowercased() {
        case "chest": return .red
        case "back", "lats": return .blue
        case "shoulders": return .orange
        case "biceps": return .purple
        case "triceps": return .pink
        case "quads": return .green
        case "hamstrings": return .teal
        case "glutes": return .mint
        case "calves": return .cyan
        case "core": return .yellow
        case "forearms": return .indigo
        case "traps": return .brown
        default: return .gray
        }
    }
    
    // MARK: - Exercise Row
    private func exerciseRow(_ exercise: Exercise, indented: Bool = false) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedExerciseId = expandedExerciseId == exercise.id ? nil : exercise.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(exercise.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if exercise.isCustom {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Label(exercise.equipment.capitalized, systemImage: "dumbbell.fill")
                            Text("•")
                            Text(exercise.category.capitalized)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Show last weight if available
                    if let lastWeight = getLastWeight(for: exercise) {
                        Text("\(Int(lastWeight)) lbs")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(6)
                    }
                    
                    Image(systemName: expandedExerciseId == exercise.id ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .padding(.leading, indented ? 32 : 0)
                .background(expandedExerciseId == exercise.id ? Color.green.opacity(0.1) : Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded Actions
            if expandedExerciseId == exercise.id {
                HStack(spacing: 12) {
                    Button {
                        selectedExercise = exercise
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Select")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    
                    Button {
                        showExerciseInfo = exercise
                    } label: {
                        HStack {
                            Image(systemName: "info.circle.fill")
                            Text("Info")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.leading, indented ? 32 : 0)
                .padding(.bottom, 12)
                .background(Color.green.opacity(0.1))
            }
            
            if indented {
                Divider()
                    .padding(.leading, indented ? 48 : 16)
            }
        }
    }
    
    private func getLastWeight(for exercise: Exercise) -> Double? {
        let sets = allSets.filter { $0.exerciseId == exercise.id }
        
        // Prefer current gym
        if let gym = currentGym {
            if let gymSet = sets.first(where: { $0.gym == gym }) {
                return gymSet.weight
            }
        }
        
        return sets.first?.weight
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No exercises found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Try adjusting your filters or add a custom exercise")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showAddExercise = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Exercise")
                }
                .fontWeight(.semibold)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Load Exercises
    private func loadDefaultExercisesIfNeeded() {
        guard exercises.isEmpty else { return }
        
        for ex in ExerciseData.allExercises {
            let exercise = Exercise(
                id: ex.id,
                name: ex.name,
                category: ex.category,
                primaryMuscle: ex.primaryMuscle,
                equipment: ex.equipment,
                split: ex.split
            )
            modelContext.insert(exercise)
        }
        
        try? modelContext.save()
        print("✅ Loaded \(ExerciseData.allExercises.count) exercises")
    }
}

#Preview {
    ExercisePickerView(selectedExercise: .constant(nil))
        .modelContainer(for: Exercise.self, inMemory: true)
}
