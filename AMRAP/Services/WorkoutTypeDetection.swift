//
//  WorkoutTypeDetection.swift
//  AMRAP
//

import SwiftUI

// MARK: - Enhanced Workout Type Detection

func detectWorkoutType(from sets: [WorkoutSet]) -> String {
    guard !sets.isEmpty else { return "Workout" }
    
    // Count sets by primary muscle
    var muscleCount: [String: Int] = [:]
    for set in sets {
        let muscle = set.primaryMuscle.lowercased()
        muscleCount[muscle, default: 0] += 1
    }
    
    // Define muscle groupings
    let chestMuscles = ["chest"]
    let shoulderMuscles = ["shoulders"]
    let tricepMuscles = ["triceps"]
    let backMuscles = ["back", "lats", "traps"]
    let bicepMuscles = ["biceps"]
    let forearmMuscles = ["forearms"]
    let quadMuscles = ["quads"]
    let hamstringMuscles = ["hamstrings"]
    let gluteMuscles = ["glutes"]
    let calfMuscles = ["calves"]
    let coreMuscles = ["core", "abs"]
    
    // Calculate category totals
    var chestCount = 0
    var shoulderCount = 0
    var tricepCount = 0
    var backCount = 0
    var bicepCount = 0
    var forearmCount = 0
    var quadCount = 0
    var hamstringCount = 0
    var gluteCount = 0
    var calfCount = 0
    var coreCount = 0
    
    for (muscle, count) in muscleCount {
        if chestMuscles.contains(muscle) { chestCount += count }
        else if shoulderMuscles.contains(muscle) { shoulderCount += count }
        else if tricepMuscles.contains(muscle) { tricepCount += count }
        else if backMuscles.contains(muscle) { backCount += count }
        else if bicepMuscles.contains(muscle) { bicepCount += count }
        else if forearmMuscles.contains(muscle) { forearmCount += count }
        else if quadMuscles.contains(muscle) { quadCount += count }
        else if hamstringMuscles.contains(muscle) { hamstringCount += count }
        else if gluteMuscles.contains(muscle) { gluteCount += count }
        else if calfMuscles.contains(muscle) { calfCount += count }
        else if coreMuscles.contains(muscle) { coreCount += count }
    }
    
    // Group into broader categories
    let legCount = quadCount + hamstringCount + gluteCount + calfCount
    let pushCount = chestCount + shoulderCount + tricepCount
    let pullCount = backCount + bicepCount + forearmCount
    let armCount = bicepCount + tricepCount + forearmCount
    let upperCount = pushCount + pullCount
    
    let total = legCount + pushCount + pullCount + coreCount
    guard total > 0 else { return "Workout" }
    
    // Calculate ratios
    let legRatio = Double(legCount) / Double(total)
    let pushRatio = Double(pushCount) / Double(total)
    let pullRatio = Double(pullCount) / Double(total)
    let coreRatio = Double(coreCount) / Double(total)
    let upperRatio = Double(upperCount) / Double(total)
    let chestRatio = Double(chestCount) / Double(total)
    let backRatio = Double(backCount) / Double(total)
    let shoulderRatio = Double(shoulderCount) / Double(total)
    let armRatio = Double(armCount) / Double(total)
    
    // Determine workout type with priority order
    
    // 1. Core-focused workout
    if coreRatio > 0.6 {
        return "Core"
    }
    
    // 2. Pure leg day
    if legRatio > 0.7 {
        return "Legs"
    }
    
    // 3. Pure push day
    if pushRatio > 0.7 {
        return "Push"
    }
    
    // 4. Pure pull day
    if pullRatio > 0.7 {
        return "Pull"
    }
    
    // 5. Chest & Back (antagonist split)
    if chestRatio > 0.25 && backRatio > 0.25 && legRatio < 0.2 {
        return "Chest & Back"
    }
    
    // 6. Shoulders & Arms
    if shoulderRatio > 0.2 && armRatio > 0.3 && chestRatio < 0.15 && backRatio < 0.15 {
        return "Shoulders & Arms"
    }
    
    // 7. Arms only
    if armRatio > 0.6 && shoulderRatio < 0.15 {
        return "Arms"
    }
    
    // 8. Upper body (mix of push and pull, minimal legs)
    if upperRatio > 0.7 && legRatio < 0.2 {
        return "Upper Body"
    }
    
    // 9. Full body (significant work in all areas)
    if legRatio > 0.2 && upperRatio > 0.4 {
        return "Full Body"
    }
    
    // 10. Push-leaning upper
    if pushRatio > 0.5 && pullRatio > 0.2 {
        return "Upper Body"
    }
    
    // 11. Pull-leaning upper
    if pullRatio > 0.5 && pushRatio > 0.2 {
        return "Upper Body"
    }
    
    // Default fallback
    if legRatio > pushRatio && legRatio > pullRatio {
        return "Legs"
    } else if pushRatio > pullRatio {
        return "Push"
    } else if pullRatio > pushRatio {
        return "Pull"
    }
    
    return "Workout"
}

// Helper function to abbreviate workout type for calendar display
func abbreviateWorkoutType(_ type: String) -> String {
    switch type {
    case "Push": return "Push"
    case "Pull": return "Pull"
    case "Legs": return "Legs"
    case "Upper Body": return "Upper"
    case "Full Body": return "Full"
    case "Chest & Back": return "C/B"
    case "Shoulders & Arms": return "S/A"
    case "Arms": return "Arms"
    case "Core": return "Core"
    default: return ""
    }
}

// Helper function to get color for workout type
func workoutTypeColor(_ type: String) -> Color {
    switch type.lowercased() {
    case "push": return .red
    case "pull": return .blue
    case "legs": return .green
    case "upper body", "upper": return .purple
    case "full body", "full": return .orange
    case "chest & back", "c/b": return .pink
    case "shoulders & arms", "s/a": return .cyan
    case "arms": return .indigo
    case "core": return .yellow
    default: return .gray
    }
}
