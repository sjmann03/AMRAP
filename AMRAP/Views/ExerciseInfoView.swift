import SwiftUI
import SwiftData

struct ExerciseInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let exercise: Exercise
    let allSets: [WorkoutSet]
    
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false
    
    // Computed stats
    private var exerciseSets: [WorkoutSet] {
        allSets.filter { $0.exerciseId == exercise.id }
    }
    
    private var personalRecord: (weight: Double, reps: Int)? {
        guard !exerciseSets.isEmpty else { return nil }
        if let best = exerciseSets.max(by: { $0.weight < $1.weight }) {
            return (best.weight, best.reps)
        }
        return nil
    }
    
    private var lastWorkout: (date: Date, summary: String)? {
        guard let lastSet = exerciseSets.first else { return nil }
        let lastWorkoutSets = exerciseSets.filter {
            Calendar.current.isDate($0.date, inSameDayAs: lastSet.date)
        }
        let maxWeight = lastWorkoutSets.map { $0.weight }.max() ?? 0
        let totalSets = lastWorkoutSets.count
        return (lastSet.date, "\(Int(maxWeight)) lbs × \(totalSets) sets")
    }
    
    private var totalSetsAllTime: Int {
        exerciseSets.count
    }
    
    private var hasHistory: Bool {
        !exerciseSets.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Exercise Header
                    headerSection
                    
                    // Your Stats
                    if !exerciseSets.isEmpty {
                        statsSection
                    }
                    
                    // Exercise Details
                    detailsSection
                    
                    // Actions
                    actionsSection
                    
                    // Edit/Delete for custom exercises
                    if exercise.isCustom {
                        customExerciseActions
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .background(Color.black.opacity(0.95))
            .navigationTitle("Exercise Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Exercise?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteExercise()
                }
            } message: {
                if hasHistory {
                    Text("This exercise has \(exerciseSets.count) logged sets. Deleting it will NOT delete your workout history, but you won't be able to select this exercise for future workouts.")
                } else {
                    Text("This will permanently delete this custom exercise. This cannot be undone.")
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditCustomExerciseView(exercise: exercise)
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 16) {
                Label(exercise.primaryMuscle.capitalized, systemImage: "figure.strengthtraining.traditional")
                Label(exercise.equipment.capitalized, systemImage: "dumbbell.fill")
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            Text(exercise.category.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Stats
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Your Stats")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let pr = personalRecord {
                    statRow(icon: "🏆", label: "Personal Record", value: "\(Int(pr.weight)) lbs × \(pr.reps)")
                }
                
                if let last = lastWorkout {
                    statRow(icon: "📅", label: "Last Workout", value: formatDate(last.date))
                    statRow(icon: "💪", label: "Best Set", value: last.summary)
                }
                
                statRow(icon: "📈", label: "Total Sets (All Time)", value: "\(totalSetsAllTime)")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Text(icon)
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Details
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ℹ️ Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                detailRow(label: "Category", value: exercise.category.capitalized)
                detailRow(label: "Primary Muscle", value: exercise.primaryMuscle.capitalized)
                detailRow(label: "Equipment", value: exercise.equipment.capitalized)
                detailRow(label: "Split", value: exercise.split.capitalized)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                openYouTube()
            } label: {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.red)
                    Text("Watch Tutorial on YouTube")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Custom Exercise Actions
    private var customExerciseActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚙️ Manage Exercise")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button {
                    showEditSheet = true
                } label: {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                        Text("Edit Exercise")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                        Text("Delete Exercise")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func openYouTube() {
        let query = exercise.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.youtube.com/results?search_query=\(query)+form+tutorial") {
            UIApplication.shared.open(url)
        }
    }
    
    private func deleteExercise() {
        modelContext.delete(exercise)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#Preview {
    ExerciseInfoView(
        exercise: Exercise(
            id: "bench_press",
            name: "Barbell Bench Press",
            category: "compound",
            primaryMuscle: "chest",
            equipment: "barbell",
            split: "push",
            isCustom: true
        ),
        allSets: []
    )
}
