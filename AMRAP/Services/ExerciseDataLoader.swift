import SwiftUI
import SwiftData

struct ExerciseDataLoader: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                loadExercisesIfNeeded()
            }
    }
    
    private func loadExercisesIfNeeded() {
        // Only load if database is empty
        guard exercises.isEmpty else {
            print("✅ Exercises already loaded: \(exercises.count)")
            return
        }
        
        print("📦 Loading default exercises...")
        
        for ex in ExerciseData.allExercises {
            let exercise = Exercise(
                id: ex.id,
                name: ex.name,
                category: ex.category,
                primaryMuscle: ex.primaryMuscle,
                muscleGroups: [ex.primaryMuscle],
                equipment: ex.equipment,
                split: ex.split,
                isCustom: false
            )
            modelContext.insert(exercise)
        }
        
        do {
            try modelContext.save()
            print("✅ Loaded \(ExerciseData.allExercises.count) exercises")
        } catch {
            print("❌ Failed to save exercises: \(error)")
        }
    }
}

extension View {
    func loadExerciseData() -> some View {
        modifier(ExerciseDataLoader())
    }
}
