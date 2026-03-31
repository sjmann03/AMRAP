import Foundation
import SwiftData

private func generateID() -> String {
    return Foundation.UUID().uuidString
}

// MARK: - Exercise Model
@Model
final class Exercise {
    @Attribute(.unique) var id: String
    var name: String
    var category: String  // compound, isolation
    var primaryMuscle: String
    var muscleGroups: [String]
    var equipment: String
    var split: String
    var isCustom: Bool
    var disableRecommendations: Bool
    var notes: String?
    
    init(
        id: String,
        name: String,
        category: String = "compound",
        primaryMuscle: String,
        muscleGroups: [String]? = nil,
        equipment: String,
        split: String,
        isCustom: Bool = false,
        disableRecommendations: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.primaryMuscle = primaryMuscle
        self.muscleGroups = muscleGroups ?? [primaryMuscle]
        self.equipment = equipment
        self.split = split
        self.isCustom = isCustom
        self.disableRecommendations = disableRecommendations
        self.notes = notes
    }
}

// MARK: - Set Type Enum
enum SetType: String, Codable, CaseIterable {
    case standard = "standard"
    case warmup = "warmup"
    case drop = "drop"
    case superSet = "super"
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .warmup: return "Warm-up"
        case .drop: return "Drop Set"
        case .superSet: return "Super Set"
        }
    }
    
    var color: String {
        switch self {
        case .standard: return "green"
        case .warmup: return "orange"
        case .drop: return "purple"
        case .superSet: return "blue"
        }
    }
}

// MARK: - WorkoutSet Model
@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var exerciseId: String
    var exerciseName: String
    var primaryMuscle: String
    var muscleGroups: [String]
    var equipment: String
    var category: String
    var split: String
    var weight: Double
    var reps: Int
    var setType: SetType
    var toFailure: Bool
    var setGroup: Int
    var dropIndex: Int
    var superSetId: String?
    var superSetOrder: Int?
    var timestamp: Date
    var date: Date
    var workoutId: String
    var gym: String?
    var exerciseNote: String?
    
    init(
        exerciseId: String,
        exerciseName: String,
        primaryMuscle: String,
        muscleGroups: [String] = [],
        equipment: String,
        category: String,
        split: String,
        weight: Double,
        reps: Int,
        setType: SetType = .standard,
        toFailure: Bool = false,
        setGroup: Int = 1,
        dropIndex: Int = 0,
        superSetId: String? = nil,
        superSetOrder: Int? = nil,
        workoutId: String,
        gym: String? = nil,
        exerciseNote: String? = nil
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.primaryMuscle = primaryMuscle
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.category = category
        self.split = split
        self.weight = weight
        self.reps = reps
        self.setType = setType
        self.toFailure = toFailure
        self.setGroup = setGroup
        self.dropIndex = dropIndex
        self.superSetId = superSetId
        self.superSetOrder = superSetOrder
        self.timestamp = Date()
        self.date = Date()
        self.workoutId = workoutId
        self.gym = gym
        self.exerciseNote = exerciseNote
    }
}

// Add this extension for SetType if you don't have it
extension SetType {
    static func from(string: String) -> SetType {
        switch string.lowercased() {
        case "warmup", "warm-up", "warm_up": return .warmup
        case "drop", "dropset", "drop_set": return .drop
        case "super", "superset", "super_set": return .superSet
        default: return .standard
        }
    }
}

// MARK: - Workout Model
@Model
final class Workout {
    @Attribute(.unique) var id: String
    var date: Date
    var startedAt: Date
    var endedAt: Date?
    var gym: String?
    var duration: Int?
    var exerciseNames: [String]
    var totalSets: Int
    var totalVolume: Double
    var notes: String?
    var rpe: Int?
    var density: Double?
    var workoutType: String?
    
    init(
        id: String? = nil,
        date: Date = Date(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        gym: String? = nil,
        duration: Int? = nil,
        exerciseNames: [String] = [],
        totalSets: Int = 0,
        totalVolume: Double = 0,
        notes: String? = nil,
        rpe: Int? = nil,
        density: Double? = nil,
        workoutType: String? = nil
    ) {
        self.id = id ?? generateID()
        self.date = date
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.gym = gym
        self.duration = duration
        self.exerciseNames = exerciseNames
        self.totalSets = totalSets
        self.totalVolume = totalVolume
        self.notes = notes
        self.rpe = rpe
        self.density = density
        self.workoutType = workoutType
    }
}

// MARK: - Workout Template
@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: String
    var name: String
    var exercises: [TemplateExercise]
    var createdAt: Date
    var lastUsed: Date?
    
    init(
        id: String? = nil,
        name: String,
        exercises: [TemplateExercise] = [],
        createdAt: Date = Date(),
        lastUsed: Date? = nil
    ) {
        self.id = id ?? generateID()
        self.name = name
        self.exercises = exercises
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
}

// MARK: - Template Exercise (stored as Codable within template)
struct TemplateExercise: Codable, Identifiable, Hashable {
    var id: String { "\(exerciseId)-\(order)" }
    var exerciseId: String
    var exerciseName: String
    var equipment: String
    var primaryMuscle: String
    var targetSets: Int
    var setType: String
    var order: Int
    var warmupSets: Int
    
    // Superset fields
    var supersetExerciseId: String?
    var supersetExerciseName: String?
    var supersetPrimaryMuscle: String?
    var supersetEquipment: String?
    
    init(
        exerciseId: String,
        exerciseName: String,
        equipment: String,
        primaryMuscle: String,
        targetSets: Int = 3,
        setType: String = "standard",
        order: Int = 0,
        warmupSets: Int = 0,
        supersetExerciseId: String? = nil,
        supersetExerciseName: String? = nil,
        supersetPrimaryMuscle: String? = nil,
        supersetEquipment: String? = nil
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.primaryMuscle = primaryMuscle
        self.targetSets = targetSets
        self.setType = setType
        self.order = order
        self.warmupSets = warmupSets
        self.supersetExerciseId = supersetExerciseId
        self.supersetExerciseName = supersetExerciseName
        self.supersetPrimaryMuscle = supersetPrimaryMuscle
        self.supersetEquipment = supersetEquipment
    }
}

// MARK: - Gym Location
@Model
final class GymLocation {
    @Attribute(.unique) var id: String
    var name: String
    var isDefault: Bool
    var createdAt: Date
    
    init(id: String? = nil, name: String, isDefault: Bool = false) {
        self.id = id ?? generateID()
        self.name = name
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}


// MARK: - App Settings (SwiftData Model)
@Model
final class AppSettings {
    var restTime: Int = 90
    var defaultSets: Int = 3
    var weightUnit: String = "lbs"
    var askGymOnSave: Bool = false
    var themeColor: String = "green"
    var compactMode: Bool = false
    var showConfetti: Bool = true
    var autoStartTimer: Bool = true
    var vibrateOnTimer: Bool = true
    var soundOnTimer: Bool = true
    var defaultRepRangeMin: Int = 8
    var defaultRepRangeMax: Int = 12
    
    init() {}
}

@Model
final class BodyMeasurement {
    var id: UUID
    var date: Date
    var weight: Double
    var chest: Double
    var waist: Double
    var arms: Double
    var thighs: Double
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double = 0,
        chest: Double = 0,
        waist: Double = 0,
        arms: Double = 0,
        thighs: Double = 0
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.chest = chest
        self.waist = waist
        self.arms = arms
        self.thighs = thighs
    }
}

