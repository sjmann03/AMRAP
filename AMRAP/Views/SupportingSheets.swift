import SwiftUI
import SwiftData

// MARK: - Start Workout Sheet
struct StartWorkoutSheet: View {
    let gyms: [GymLocation]
    let onStartFree: (String?) -> Void
    let onStartTemplate: (String?) -> Void
    
    @State private var selectedGym: String = ""
    @State private var customGym: String = ""
    @State private var showCustomGym: Bool = false
    @State private var showGymPicker: Bool = false
    
    var currentGym: String? {
        if showCustomGym {
            return customGym.isEmpty ? nil : customGym
        }
        return selectedGym.isEmpty ? nil : selectedGym
    }
    
    var displayedGymName: String {
        if showCustomGym {
            return customGym.isEmpty ? "Other" : customGym
        }
        return selectedGym.isEmpty ? "Select Location" : selectedGym
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Gym Selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("Where are you training?", systemImage: "mappin.circle.fill")
                        .font(.headline)
                    
                    if gyms.isEmpty && !showCustomGym {
                        // First time - just show text field
                        TextField("Enter gym name (optional)", text: $customGym)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    } else {
                        // Dropdown button
                        Button {
                            showGymPicker.toggle()
                        } label: {
                            HStack {
                                Image(systemName: showCustomGym ? "plus.circle.fill" : "building.2.fill")
                                    .foregroundColor(.blue)
                                
                                Text(displayedGymName)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedGym.isEmpty && !showCustomGym ? .secondary : .primary)
                                
                                Spacer()
                                
                                Image(systemName: showGymPicker ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        // Dropdown options
                        if showGymPicker {
                            VStack(spacing: 0) {
                                ForEach(gyms) { gym in
                                    Button {
                                        selectedGym = gym.name
                                        showCustomGym = false
                                        showGymPicker = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "building.2")
                                                .foregroundColor(.blue)
                                                .frame(width: 24)
                                            
                                            Text(gym.name)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            if selectedGym == gym.name && !showCustomGym {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                                    .fontWeight(.semibold)
                                            }
                                            
                                            if gym.isDefault {
                                                Text("Default")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if gym.id != gyms.last?.id {
                                        Divider()
                                            .padding(.leading, 48)
                                    }
                                }
                                
                                Divider()
                                
                                // Other option
                                Button {
                                    showCustomGym = true
                                    selectedGym = ""
                                    showGymPicker = false
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.orange)
                                            .frame(width: 24)
                                        
                                        Text("Other")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if showCustomGym {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.orange)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Custom gym text field
                        if showCustomGym {
                            TextField("Enter gym name", text: $customGym)
                                .padding()
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(10)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showGymPicker)
                .animation(.easeInOut(duration: 0.2), value: showCustomGym)
                
                Divider()
                
                // Workout Type Buttons
                VStack(spacing: 12) {
                    Button {
                        onStartFree(currentGym)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            VStack(alignment: .leading) {
                                Text("Free Workout")
                                    .fontWeight(.bold)
                                Text("Add exercises as you go")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        onStartTemplate(currentGym)
                    } label: {
                        HStack {
                            Image(systemName: "list.clipboard")
                            VStack(alignment: .leading) {
                                Text("Use Template")
                                    .fontWeight(.bold)
                                Text("Follow a saved routine")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Set default gym on appear
                if let defaultGym = gyms.first(where: { $0.isDefault }) {
                    selectedGym = defaultGym.name
                } else if let firstGym = gyms.first {
                    selectedGym = firstGym.name
                }
            }
        }
    }
}

// MARK: - Gym Selection Button
struct GymSelectionButton: View {
    let name: String
    let isSelected: Bool
    var icon: String = "building.2"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(name)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Change Gym Sheet
struct ChangeGymSheet: View {
    let gyms: [GymLocation]
    let currentGym: String?
    let onSelectGym: (String?) -> Void
    
    @State private var selectedGym: String = ""
    @State private var customGym: String = ""
    @State private var showCustomGym: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if gyms.isEmpty {
                    TextField("Enter gym name", text: $customGym)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                    
                    Button {
                        onSelectGym(customGym.isEmpty ? nil : customGym)
                    } label: {
                        Text("Save")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    ForEach(gyms) { gym in
                        GymSelectionButton(
                            name: gym.name,
                            isSelected: selectedGym == gym.name && !showCustomGym
                        ) {
                            selectedGym = gym.name
                            showCustomGym = false
                            onSelectGym(gym.name)
                        }
                    }
                    
                    GymSelectionButton(
                        name: "Other",
                        isSelected: showCustomGym,
                        icon: "plus.circle"
                    ) {
                        showCustomGym = true
                        selectedGym = ""
                    }
                    
                    if showCustomGym {
                        HStack {
                            TextField("Enter gym name", text: $customGym)
                                .padding()
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(10)
                            
                            Button {
                                onSelectGym(customGym.isEmpty ? nil : customGym)
                            } label: {
                                Text("Save")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Change Gym")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedGym = currentGym ?? ""
            }
        }
    }
}

// MARK: - Exercise Note Sheet
struct ExerciseNoteSheet: View {
    let exerciseName: String
    @Binding var note: String
    let previousNote: String?
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Previous note hint
                if let previousNote = previousNote, !previousNote.isEmpty, note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                            Text("Previous Note")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)
                        
                        Text(previousNote)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button {
                            note = previousNote
                        } label: {
                            Text("Use this note")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                // Note input
                Text("Note for \(exerciseName)")
                    .font(.headline)
                
                TextEditor(text: $note)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)
                    .overlay(
                        Group {
                            if note.isEmpty {
                                Text("e.g., Seat height: 5, grip width: shoulder")
                                    .foregroundColor(.gray)
                                    .padding(12)
                            }
                        },
                        alignment: .topLeading
                    )
                
                Text("This note will be saved with all sets for this exercise")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    onSave()
                    dismiss()
                } label: {
                    Text("Save Note")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Exercise Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Edit Set Sheet
struct EditSetSheet: View {
    let set: WorkoutSet
    let onSave: (Double, Int, Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var toFailure: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Exercise name
                Text(set.exerciseName)
                    .font(.headline)
                    .foregroundColor(.green)
                
                // Weight & Reps
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (lbs)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("0", text: $reps)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }
                }
                
                // To Failure toggle
                Button {
                    toFailure.toggle()
                } label: {
                    HStack {
                        Image(systemName: toFailure ? "flame.fill" : "flame")
                            .foregroundColor(toFailure ? .orange : .gray)
                        Text("To Failure")
                            .fontWeight(.medium)
                            .foregroundColor(toFailure ? .orange : .primary)
                        Spacer()
                        Image(systemName: toFailure ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(toFailure ? .orange : .gray)
                    }
                    .padding()
                    .background(toFailure ? Color.orange.opacity(0.15) : Color.gray.opacity(0.15))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Save button
                Button {
                    if let w = Double(weight), let r = Int(reps) {
                        onSave(w, r, toFailure)
                        dismiss()
                    }
                } label: {
                    Text("Save Changes")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(Double(weight) == nil || Int(reps) == nil)
            }
            .padding()
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                weight = set.weight.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", set.weight)
                    : String(format: "%.1f", set.weight)
                reps = String(set.reps)
                toFailure = set.toFailure
            }
        }
    }
}

// MARK: - Filter Chip (moved here to share across views)
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .green
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Start Workout") {
    StartWorkoutSheet(
        gyms: [],
        onStartFree: { _ in },
        onStartTemplate: { _ in }
    )
}

#Preview("Edit Set") {
    let set = WorkoutSet(
        exerciseId: "bench",
        exerciseName: "Barbell Bench Press",
        primaryMuscle: "chest",
        equipment: "barbell",
        category: "compound",
        split: "push",
        weight: 185,
        reps: 8,
        workoutId: "123"
    )
    return EditSetSheet(set: set) { _, _, _ in }
}
