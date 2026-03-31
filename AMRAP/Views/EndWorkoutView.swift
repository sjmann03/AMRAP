import SwiftUI

struct EndWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    
    let totalSets: Int
    let exerciseCount: Int
    let duration: Int
    let templateWasModified: Bool
    let onSave: (String?, Int?, Bool) -> Void
    let onCancel: () -> Void
    
    @State private var workoutNote: String = ""
    @State private var selectedRPE: Int? = nil
    @State private var saveTemplateChanges: Bool = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Workout Summary
                        summarySection
                        
                        // Workout Note
                        noteSection
                        
                        // RPE Selector
                        rpeSection
                        
                        // Template changes option
                        if templateWasModified {
                            templateChangesSection
                        }
                    }
                    .padding()
                }
                
                // Action Buttons
                actionButtons
            }
            .navigationTitle("Save Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(spacing: 16) {
            // Celebration
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                
                Text("Great Workout! 💪")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Stats
            HStack(spacing: 0) {
                SummaryStat(value: "\(totalSets)", label: "Sets", icon: "number.circle.fill", color: .green)
                
                Divider()
                    .frame(height: 40)
                
                SummaryStat(value: "\(exerciseCount)", label: "Exercises", icon: "list.bullet.circle.fill", color: .blue)
                
                Divider()
                    .frame(height: 40)
                
                SummaryStat(value: "\(duration)", label: "Minutes", icon: "clock.fill", color: .orange)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Note Section
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Workout Notes", systemImage: "note.text")
                .font(.headline)
            
            TextField("How did the workout feel? Any PRs?", text: $workoutNote, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
    }
    
    // MARK: - RPE Section
    private var rpeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Perceived Effort (RPE)", systemImage: "flame.fill")
                .font(.headline)
            
            // RPE Buttons
            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { value in
                    RPEButton(
                        value: value,
                        isSelected: selectedRPE == value,
                        isInRange: selectedRPE != nil && value < selectedRPE!
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedRPE = value
                        }
                    }
                }
            }
            
            // RPE Labels
            HStack {
                Text("Easy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Maximum")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Selected RPE Description
            if let rpe = selectedRPE {
                HStack {
                    Spacer()
                    Text(rpeDescription(rpe))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Template Changes Section
    private var templateChangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Template Changes", systemImage: "doc.badge.gearshape")
                .font(.headline)
            
            Text("You made changes to your template during this workout. Would you like to save these changes?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Toggle(isOn: $saveTemplateChanges) {
                HStack {
                    Image(systemName: saveTemplateChanges ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(saveTemplateChanges ? .purple : .gray)
                    Text("Save template changes")
                        .fontWeight(.medium)
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(saveTemplateChanges ? Color.purple.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                onSave(workoutNote.isEmpty ? nil : workoutNote, selectedRPE, saveTemplateChanges)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Workout")
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button {
                onCancel()
                dismiss()
            } label: {
                Text("Continue Workout")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helpers
    private func rpeDescription(_ rpe: Int) -> String {
        let descriptions = [
            1: "😴 Very Easy - Could do this all day",
            2: "😌 Easy - Barely broke a sweat",
            3: "🙂 Light - Comfortable effort",
            4: "😊 Moderate - Getting warmed up",
            5: "😐 Challenging - Working now",
            6: "😤 Hard - Feeling it",
            7: "💪 Very Hard - Pushing limits",
            8: "🔥 Intense - Really tough",
            9: "😰 Near Max - Almost everything",
            10: "🤯 Max Effort - Left it all out there"
        ]
        return descriptions[rpe] ?? "\(rpe)/10"
    }
}

// MARK: - Summary Stat
struct SummaryStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RPE Button
struct RPEButton: View {
    let value: Int
    let isSelected: Bool
    let isInRange: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .cornerRadius(8)
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return rpeColor
        } else if isInRange {
            return rpeColor.opacity(0.3)
        }
        return Color.gray.opacity(0.2)
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if isInRange {
            return rpeColor
        }
        return .secondary
    }
    
    private var rpeColor: Color {
        switch value {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .green
        }
    }
}

#Preview {
    EndWorkoutView(
        totalSets: 24,
        exerciseCount: 6,
        duration: 45,
        templateWasModified: true,
        onSave: { _, _, _ in },
        onCancel: { }
    )
}
