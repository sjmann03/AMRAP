import SwiftUI
import SwiftData

struct AddCustomExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
                        Text(name.isEmpty ? "Exercise Name" : name)
                            .font(.headline)
                            .foregroundColor(name.isEmpty ? .secondary : .green)
                        
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
                            
                            Text("Custom")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Generate unique ID
        let exerciseId = "custom_\(Date().timeIntervalSince1970)"
        
        let exercise = Exercise(
            id: exerciseId,
            name: trimmedName,
            category: category,
            primaryMuscle: primaryMuscle,
            muscleGroups: [primaryMuscle],
            equipment: equipment,
            split: split,
            isCustom: true
        )
        
        modelContext.insert(exercise)
        
        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        dismiss()
    }
}

#Preview {
    AddCustomExerciseView()
        .modelContainer(for: Exercise.self, inMemory: true)
}
