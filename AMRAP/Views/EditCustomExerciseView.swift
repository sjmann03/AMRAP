import SwiftUI
import SwiftData

struct EditCustomExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let exercise: Exercise
    
    @State private var name = ""
    @State private var primaryMuscle = "chest"
    @State private var equipment = "barbell"
    @State private var category = "compound"
    @State private var split = "push"
    
    let muscleOptions = [
        ("chest", "Chest"),
        ("back", "Back"),
        ("lats", "Lats"),
        ("shoulders", "Shoulders"),
        ("biceps", "Biceps"),
        ("triceps", "Triceps"),
        ("quads", "Quads"),
        ("hamstrings", "Hamstrings"),
        ("glutes", "Glutes"),
        ("calves", "Calves"),
        ("core", "Core"),
        ("forearms", "Forearms"),
        ("traps", "Traps"),
        ("rear delts", "Rear Delts")
    ]
    
    let equipmentOptions = [
        ("barbell", "Barbell"),
        ("dumbbell", "Dumbbell"),
        ("cable", "Cable"),
        ("machine", "Machine"),
        ("bodyweight", "Bodyweight"),
        ("bands", "Bands"),
        ("kettlebell", "Kettlebell"),
        ("ez bar", "EZ Bar"),
        ("trap bar", "Trap Bar"),
        ("smith machine", "Smith Machine"),
        ("other", "Other")
    ]
    
    let categoryOptions = [
        ("compound", "Compound"),
        ("isolation", "Isolation")
    ]
    
    let splitOptions = [
        ("push", "Push"),
        ("pull", "Pull"),
        ("legs", "Legs"),
        ("upper", "Upper"),
        ("lower", "Lower"),
        ("full", "Full Body"),
        ("arms", "Arms"),
        ("core", "Core")
    ]
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var hasChanges: Bool {
        name != exercise.name ||
        primaryMuscle != exercise.primaryMuscle ||
        equipment != exercise.equipment ||
        category != exercise.category ||
        split != exercise.split
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("e.g., Single Arm Cable Row", text: $name)
                        .autocorrectionDisabled()
                }
                
                Section("Primary Muscle") {
                    Picker("Muscle Group", selection: $primaryMuscle) {
                        ForEach(muscleOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Equipment") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipmentOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Split") {
                    Picker("Split", selection: $split) {
                        ForEach(splitOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Preview
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(name.isEmpty ? "Exercise Name" : name)
                                .font(.headline)
                                .foregroundColor(name.isEmpty ? .secondary : .green)
                            
                            Text("Custom")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        
                        HStack(spacing: 16) {
                            Label(primaryMuscle.capitalized, systemImage: "figure.strengthtraining.traditional")
                            Label(equipment.capitalized, systemImage: "dumbbell.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        HStack {
                            Text(category.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text(split.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Text("Note: Editing this exercise will not change your existing workout history. Previously logged sets will keep their original exercise name.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!canSave || !hasChanges)
                }
            }
            .onAppear {
                // Load current values
                name = exercise.name
                primaryMuscle = exercise.primaryMuscle
                equipment = exercise.equipment
                category = exercise.category
                split = exercise.split
            }
        }
    }
    
    private func saveChanges() {
        exercise.name = name.trimmingCharacters(in: .whitespaces)
        exercise.primaryMuscle = primaryMuscle
        exercise.muscleGroups = [primaryMuscle]
        exercise.equipment = equipment
        exercise.category = category
        exercise.split = split
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#Preview {
    EditCustomExerciseView(
        exercise: Exercise(
            id: "custom_123",
            name: "My Custom Exercise",
            category: "compound",
            primaryMuscle: "chest",
            equipment: "cable",
            split: "push",
            isCustom: true
        )
    )
}
