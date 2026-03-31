import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.lastUsed, order: .reverse) private var templates: [WorkoutTemplate]
    
    @State private var showCreateTemplate = false
    @State private var editingTemplate: WorkoutTemplate? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else {
                    templatesList
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTemplate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreateTemplate) {
                TemplateEditorView(template: nil)
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Templates Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Create workout templates to quickly start your favorite routines")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showCreateTemplate = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Template")
                }
                .fontWeight(.semibold)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private var templatesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(templates) { template in
                    TemplateCardView(
                        template: template,
                        onEdit: { editingTemplate = template },
                        onDelete: { deleteTemplate(template) }
                    )
                }
            }
            .padding()
        }
    }
    
    private func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
    }
}

// MARK: - Template Card View
struct TemplateCardView: View {
    let template: WorkoutTemplate
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onStart: (() -> Void)? = nil
    
    @State private var isExpanded: Bool = false
    @State private var exerciseNames: [String] = []
    @State private var exerciseCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(template.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
            
            // Exercise count
            Text("\(exerciseCount) exercises")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            // Collapsed preview
            if !isExpanded && !exerciseNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(exerciseNames.prefix(3), id: \.self) { name in
                            Text(name)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "CBD5E1"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "334155"))
                                .cornerRadius(12)
                        }
                        
                        if exerciseCount > 3 {
                            Text("+\(exerciseCount - 3) more")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "64748B"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "1E293B"))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Expanded content
            if isExpanded {
                Divider()
                    .background(Color(hex: "334155"))
                
                ForEach(Array(exerciseNames.enumerated()), id: \.offset) { index, name in
                    Text("\(index + 1). \(name)")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.vertical, 2)
                }
                
                Divider()
                    .background(Color(hex: "334155"))
                
                // Buttons
                HStack(spacing: 16) {
                    Button {
                        onEdit()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                    }
                    
                    Button {
                        onDelete()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    if let onStart = onStart {
                        Button {
                            onStart()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Start")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onAppear {
            // Load exercise data on appear to avoid accessing during render
            loadExerciseData()
        }
    }
    
    private func loadExerciseData() {
        // Safely load exercise data
        let exercises = template.exercises
        exerciseCount = exercises.count
        exerciseNames = exercises.map { $0.exerciseName }
    }
}

#Preview {
    TemplateCardView(
        template: WorkoutTemplate(
            name: "Push Day",
            exercises: [
                TemplateExercise(exerciseId: "1", exerciseName: "Bench Press", equipment: "barbell", primaryMuscle: "chest", targetSets: 4, setType: "standard", order: 0),
                TemplateExercise(exerciseId: "2", exerciseName: "Incline Dumbbell Press", equipment: "dumbbell", primaryMuscle: "chest", targetSets: 3, setType: "standard", order: 1),
                TemplateExercise(exerciseId: "3", exerciseName: "Cable Flyes", equipment: "cable", primaryMuscle: "chest", targetSets: 3, setType: "standard", order: 2),
                TemplateExercise(exerciseId: "4", exerciseName: "Overhead Press", equipment: "barbell", primaryMuscle: "shoulders", targetSets: 4, setType: "standard", order: 3),
                TemplateExercise(exerciseId: "5", exerciseName: "Lateral Raises", equipment: "dumbbell", primaryMuscle: "shoulders", targetSets: 3, setType: "standard", order: 4)
            ]
        ),
        onEdit: { print("Edit tapped") },
        onDelete: { print("Delete tapped") },
        onStart: { print("Start tapped") }
    )
    .environmentObject(ThemeManager.shared)
    .padding()
    .background(Color(hex: "0F172A"))
}

// MARK: - Template Editor View
struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    
    let template: WorkoutTemplate?
    
    @State private var templateName: String = ""
    @State private var exerciseList: [TemplateExerciseData] = []
    
    // Picker states
    @State private var showMainPicker = false
    @State private var showSupersetPicker = false
    @State private var supersetTargetId: UUID? = nil
    
    var isEditing: Bool { template != nil }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section("Template Name") {
                        TextField("e.g., Push Day, Leg Day", text: $templateName)
                    }
                    
                    Section {
                        if exerciseList.isEmpty {
                            Text("No exercises added yet")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach($exerciseList) { $exercise in
                                ExerciseEditorRow(
                                    exercise: $exercise,
                                    onAddSuperset: {
                                        supersetTargetId = exercise.id
                                        showSupersetPicker = true
                                    },
                                    onRemoveSuperset: {
                                        exercise.supersetExerciseId = nil
                                        exercise.supersetExerciseName = nil
                                    },
                                    onDelete: {
                                        exerciseList.removeAll { $0.id == exercise.id }
                                    }
                                )
                            }
                            .onMove { from, to in
                                exerciseList.move(fromOffsets: from, toOffset: to)
                            }
                            .onDelete { indexSet in
                                exerciseList.remove(atOffsets: indexSet)
                            }
                        }
                        
                        Button {
                            showMainPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text("Add Exercise")
                                    .foregroundColor(.green)
                            }
                        }
                    } header: {
                        Text("Exercises")
                    }
                }
                .listStyle(.insetGrouped)
                
                // Save button
                Button {
                    saveTemplate()
                } label: {
                    Text(isEditing ? "Save Changes" : "Create Template")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.purple : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canSave)
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Template" : "New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .onAppear { loadTemplate() }
            .sheet(isPresented: $showMainPicker) {
                ExerciseSelectionSheet(exercises: allExercises) { exercise in
                    addExercise(exercise)
                    showMainPicker = false
                }
            }
            .sheet(isPresented: $showSupersetPicker) {
                ExerciseSelectionSheet(exercises: allExercises) { exercise in
                    addSupersetExercise(exercise)
                    showSupersetPicker = false
                }
            }
        }
    }
    
    private var canSave: Bool {
        !templateName.isEmpty && !exerciseList.isEmpty
    }
    
    private func loadTemplate() {
        if let template = template {
            templateName = template.name
            exerciseList = template.exercises.enumerated().map { index, ex in
                TemplateExerciseData(
                    exerciseId: ex.exerciseId,
                    exerciseName: ex.exerciseName,
                    equipment: ex.equipment,
                    primaryMuscle: ex.primaryMuscle,
                    targetSets: ex.targetSets,
                    setType: ex.setType,
                    supersetExerciseId: ex.supersetExerciseId,
                    supersetExerciseName: ex.supersetExerciseName
                )
            }
        }
    }
    
    private func addExercise(_ exercise: Exercise) {
        let newExercise = TemplateExerciseData(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            equipment: exercise.equipment,
            primaryMuscle: exercise.primaryMuscle,
            targetSets: 3,
            setType: "standard",
            supersetExerciseId: nil,
            supersetExerciseName: nil
        )
        exerciseList.append(newExercise)
    }
    
    private func addSupersetExercise(_ exercise: Exercise) {
        guard let targetId = supersetTargetId,
              let index = exerciseList.firstIndex(where: { $0.id == targetId }) else {
            return
        }
        
        exerciseList[index].supersetExerciseId = exercise.id
        exerciseList[index].supersetExerciseName = exercise.name
        supersetTargetId = nil
    }
    
    private func saveTemplate() {
        let templateExercises = exerciseList.enumerated().map { index, data in
            TemplateExercise(
                exerciseId: data.exerciseId,
                exerciseName: data.exerciseName,
                equipment: data.equipment,
                primaryMuscle: data.primaryMuscle,
                targetSets: data.targetSets,
                setType: data.setType,
                order: index,
                warmupSets: 0,
                supersetExerciseId: data.supersetExerciseId,
                supersetExerciseName: data.supersetExerciseName,
                supersetPrimaryMuscle: nil,
                supersetEquipment: nil
            )
        }
        
        if let existingTemplate = template {
            existingTemplate.name = templateName
            existingTemplate.exercises = templateExercises
        } else {
            let newTemplate = WorkoutTemplate(
                name: templateName,
                exercises: templateExercises
            )
            modelContext.insert(newTemplate)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Template Exercise Data (simple struct for editing)
struct TemplateExerciseData: Identifiable {
    let id = UUID()
    var exerciseId: String
    var exerciseName: String
    var equipment: String
    var primaryMuscle: String
    var targetSets: Int
    var setType: String
    var supersetExerciseId: String?
    var supersetExerciseName: String?
}

// MARK: - Exercise Editor Row
struct ExerciseEditorRow: View {
    @Binding var exercise: TemplateExerciseData
    let onAddSuperset: () -> Void
    let onRemoveSuperset: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise name and info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    // Show both exercises for superset
                    if exercise.setType == "super", let supersetName = exercise.supersetExerciseName {
                        HStack(spacing: 4) {
                            Text(exercise.exerciseName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("+")
                                .foregroundColor(.purple)
                                .fontWeight(.bold)
                            Text(supersetName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                        }
                        .lineLimit(1)
                    } else {
                        Text(exercise.exerciseName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("\(exercise.primaryMuscle.capitalized) • \(exercise.equipment.capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Set type and sets config
            HStack(spacing: 12) {
                // Set type picker
                Picker("Type", selection: $exercise.setType) {
                    Text("Standard").tag("standard")
                    Text("Super Set").tag("super")
                    Text("Drop Set").tag("drop")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(setTypeColor.opacity(0.2))
                .cornerRadius(6)
                .onChange(of: exercise.setType) { oldValue, newValue in
                    if newValue != "super" {
                        exercise.supersetExerciseId = nil
                        exercise.supersetExerciseName = nil
                    }
                }
                
                // Sets picker
                Picker("Sets", selection: $exercise.targetSets) {
                    ForEach(1...8, id: \.self) { num in
                        Text("\(num) sets").tag(num)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            
            // Superset section - only show add button if not yet paired
            if exercise.setType == "super" && exercise.supersetExerciseName == nil {
                Button {
                    onAddSuperset()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Second Exercise")
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.purple.opacity(0.5))
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else if exercise.setType == "super" && exercise.supersetExerciseName != nil {
                // Show remove button for superset
                HStack {
                    Spacer()
                    Button {
                        onRemoveSuperset()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Remove Pair")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var setTypeColor: Color {
        switch exercise.setType {
        case "super": return .purple
        case "drop": return .orange
        default: return .green
        }
    }
}

// MARK: - Exercise Selection Sheet
struct ExerciseSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    
    @State private var searchText = ""
    @State private var selectedMuscle: String? = nil
    
    private let muscles = ["Chest", "Back", "Lats", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves", "Core"]
    
    private var filteredExercises: [Exercise] {
        var result = exercises
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let muscle = selectedMuscle {
            result = result.filter { $0.primaryMuscle.localizedCaseInsensitiveContains(muscle) }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                TextField("Search exercises...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                // Muscle filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        muscleFilterButton(nil, title: "All")
                        ForEach(muscles, id: \.self) { muscle in
                            muscleFilterButton(muscle, title: muscle)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                // List
                List(filteredExercises) { exercise in
                    Button {
                        onSelect(exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("\(exercise.primaryMuscle.capitalized) • \(exercise.equipment.capitalized)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func muscleFilterButton(_ muscle: String?, title: String) -> some View {
        Button {
            selectedMuscle = muscle
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedMuscle == muscle ? Color.purple : Color.gray.opacity(0.2))
                .foregroundColor(selectedMuscle == muscle ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

#Preview {
    TemplatesView()
        .modelContainer(for: [WorkoutTemplate.self, Exercise.self], inMemory: true)
}
