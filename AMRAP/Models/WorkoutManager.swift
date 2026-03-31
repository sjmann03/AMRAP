import SwiftUI
import SwiftData

enum WorkoutMode: String, Codable {
    case free
    case template
}

struct TemplateProgress: Codable {
    var currentExerciseIndex: Int = 0
    var completedSets: [Int: Int] = [:] // exerciseIndex -> completed sets count
}

@Observable
class WorkoutManager {
    static let shared = WorkoutManager()
    
    // Workout State
    var isWorkoutActive: Bool = false
    var currentWorkoutId: String?
    var workoutStartTime: Date?
    var currentGym: String?
    var workoutMode: WorkoutMode = .free
    
    // Template State
    var activeTemplate: WorkoutTemplate?
    var templateProgress: TemplateProgress?
    var templateWasModified: Bool = false
    
    // Exercise State
    var selectedExercise: Exercise?
    var selectedExercise2: Exercise? // For supersets
    
    // Exercise Notes (temporary, for current workout)
    private var exerciseNotes: [String: String] = [:] // exerciseId -> note
    
    // Sets completed per exercise (for template tracking)
    private var setsCompletedPerExercise: [String: Int] = [:]
    
    private init() {
        loadState()
    }
    
    // MARK: - Computed Properties
    
    var workoutDuration: Int {
        guard let startTime = workoutStartTime else { return 0 }
        return Int(Date().timeIntervalSince(startTime) / 60)
    }
    
    // MARK: - Workout Lifecycle
    
    func startWorkout(mode: WorkoutMode, gym: String?, template: WorkoutTemplate? = nil) {
        isWorkoutActive = true
        currentWorkoutId = Foundation.UUID().uuidString
        workoutStartTime = Date()
        currentGym = gym
        workoutMode = mode
        selectedExercise = nil
        selectedExercise2 = nil
        exerciseNotes = [:]
        setsCompletedPerExercise = [:]
        templateWasModified = false
        
        if mode == .template, let template = template {
            activeTemplate = template
            templateProgress = TemplateProgress()
        } else {
            activeTemplate = nil
            templateProgress = nil
        }
        
        saveState()
    }
    
    func endWorkout() -> String? {
        let workoutId = currentWorkoutId
        
        isWorkoutActive = false
        currentWorkoutId = nil
        workoutStartTime = nil
        selectedExercise = nil
        selectedExercise2 = nil
        exerciseNotes = [:]
        setsCompletedPerExercise = [:]
        activeTemplate = nil
        templateProgress = nil
        templateWasModified = false
        
        saveState()
        
        return workoutId
    }
    
    func cancelWorkout() {
        isWorkoutActive = false
        currentWorkoutId = nil
        workoutStartTime = nil
        currentGym = nil
        workoutMode = .free
        selectedExercise = nil
        selectedExercise2 = nil
        exerciseNotes = [:]
        setsCompletedPerExercise = [:]
        activeTemplate = nil
        templateProgress = nil
        templateWasModified = false
        
        saveState()
    }
    
    // MARK: - Template Progress
    
    func recordSetCompleted(for exerciseId: String) {
        setsCompletedPerExercise[exerciseId] = (setsCompletedPerExercise[exerciseId] ?? 0) + 1
        
        // Update template progress if in template mode
        if workoutMode == .template, var progress = templateProgress {
            let currentIndex = progress.currentExerciseIndex
            progress.completedSets[currentIndex] = (progress.completedSets[currentIndex] ?? 0) + 1
            templateProgress = progress
        }
        
        saveState()
    }
    
    func getSetsCompleted(for exerciseId: String) -> Int {
        return setsCompletedPerExercise[exerciseId] ?? 0
    }
    
    func getCurrentTemplateExerciseIndex() -> Int {
        return templateProgress?.currentExerciseIndex ?? 0
    }
    
    func advanceToNextExercise() {
        guard var progress = templateProgress else { return }
        progress.currentExerciseIndex += 1
        templateProgress = progress
        saveState()
    }
    
    // MARK: - Exercise Notes
    
    func setNote(for exerciseId: String, note: String?) {
        if let note = note, !note.isEmpty {
            exerciseNotes[exerciseId] = note
        } else {
            exerciseNotes.removeValue(forKey: exerciseId)
        }
    }
    
    func getNote(for exerciseId: String) -> String? {
        return exerciseNotes[exerciseId]
    }
    
    // MARK: - Persistence
    
    private func saveState() {
        UserDefaults.standard.set(isWorkoutActive, forKey: "workout_isActive")
        UserDefaults.standard.set(currentWorkoutId, forKey: "workout_id")
        UserDefaults.standard.set(currentGym, forKey: "workout_gym")
        UserDefaults.standard.set(workoutMode.rawValue, forKey: "workout_mode")
        UserDefaults.standard.set(templateWasModified, forKey: "workout_templateModified")
        
        if let startTime = workoutStartTime {
            UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: "workout_startTime")
        }
        
        if let notesData = try? JSONEncoder().encode(exerciseNotes) {
            UserDefaults.standard.set(notesData, forKey: "workout_exerciseNotes")
        }
        
        if let setsData = try? JSONEncoder().encode(setsCompletedPerExercise) {
            UserDefaults.standard.set(setsData, forKey: "workout_setsCompleted")
        }
        
        if let progressData = try? JSONEncoder().encode(templateProgress) {
            UserDefaults.standard.set(progressData, forKey: "workout_templateProgress")
        }
    }
    
    private func loadState() {
        isWorkoutActive = UserDefaults.standard.bool(forKey: "workout_isActive")
        currentWorkoutId = UserDefaults.standard.string(forKey: "workout_id")
        currentGym = UserDefaults.standard.string(forKey: "workout_gym")
        templateWasModified = UserDefaults.standard.bool(forKey: "workout_templateModified")
        
        if let modeStr = UserDefaults.standard.string(forKey: "workout_mode") {
            workoutMode = WorkoutMode(rawValue: modeStr) ?? .free
        }
        
        if let startTimeInterval = UserDefaults.standard.object(forKey: "workout_startTime") as? Double {
            workoutStartTime = Date(timeIntervalSince1970: startTimeInterval)
        }
        
        if let notesData = UserDefaults.standard.data(forKey: "workout_exerciseNotes"),
           let notes = try? JSONDecoder().decode([String: String].self, from: notesData) {
            exerciseNotes = notes
        }
        
        if let setsData = UserDefaults.standard.data(forKey: "workout_setsCompleted"),
           let sets = try? JSONDecoder().decode([String: Int].self, from: setsData) {
            setsCompletedPerExercise = sets
        }
        
        if let progressData = UserDefaults.standard.data(forKey: "workout_templateProgress"),
           let progress = try? JSONDecoder().decode(TemplateProgress.self, from: progressData) {
            templateProgress = progress
        }
    }
}
