import SwiftUI
import SwiftData
import Combine
import Charts

// MARK: - Settings Manager for Unit Conversion
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var weightUnit: String {
        didSet {
            UserDefaults.standard.set(weightUnit, forKey: "weightUnit")
        }
    }
    
    init() {
        self.weightUnit = UserDefaults.standard.string(forKey: "weightUnit") ?? "lbs"
    }
    
    var weightLabel: String {
        weightUnit == "kg" ? "kg" : "lbs"
    }
    
    func formatWeight(_ weightInLbs: Double) -> Double {
        if weightUnit == "kg" {
            return (weightInLbs / 2.205).rounded()
        }
        return weightInLbs
    }
    
    func formatWeightString(_ weightInLbs: Double) -> String {
        let converted = formatWeight(weightInLbs)
        return "\(Int(converted)) \(weightLabel)"
    }
    
    func formatVolume(_ volumeInLbs: Double) -> String {
        let converted = formatWeight(volumeInLbs)
        if converted >= 1_000_000 {
            return String(format: "%.1fM", converted / 1_000_000)
        } else if converted >= 1_000 {
            return String(format: "%.0fK", converted / 1_000)
        } else {
            return String(format: "%.0f", converted)
        }
    }
}

// MARK: - 1RM Calculator
func calculate1RM(weight: Double, reps: Int) -> Double {
    if reps == 1 { return weight }
    // Brzycki formula
    return weight * (36.0 / (37.0 - Double(reps)))
}

// MARK: - Muscle Recovery Status
struct MuscleRecoveryStatus {
    let status: String
    let label: String
    let color: Color
    let icon: String
    let priority: Int // Lower = higher priority (show first)
    
    static func get(daysSinceTraining: Int?) -> MuscleRecoveryStatus {
        guard let days = daysSinceTraining else {
            return MuscleRecoveryStatus(status: "unknown", label: "No data", color: Color(hex: "64748B"), icon: "❓", priority: 50)
        }
        
        switch days {
        case 0:
            return MuscleRecoveryStatus(status: "trained", label: "Trained today", color: .green, icon: "🔥", priority: 100)
        case 1:
            return MuscleRecoveryStatus(status: "recovering", label: "Recovering", color: .orange, icon: "😴", priority: 90)
        case 2:
            return MuscleRecoveryStatus(status: "almost", label: "Almost ready", color: .yellow, icon: "⏳", priority: 80)
        case 3...5:
            return MuscleRecoveryStatus(status: "ready", label: "Ready", color: .green, icon: "✅", priority: 30)
        case 6...9:
            return MuscleRecoveryStatus(status: "primed", label: "Primed", color: .blue, icon: "💪", priority: 20)
        default:
            return MuscleRecoveryStatus(status: "overdue", label: "\(days)d ago", color: .red, icon: "⚠️", priority: 10)
        }
    }
}

struct AnalyticsView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \WorkoutSet.timestamp, order: .reverse) private var allSets: [WorkoutSet]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var bodyMeasurements: [BodyMeasurement]
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var settings = SettingsManager.shared
    
    @State private var selectedSection: Int = 0
    
    let sectionNames = ["Overview", "Strength", "Muscles", "Body"]
    
    // MARK: - Computed Date Ranges
    private var sevenDaysAgo: Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
    }
    
    private var fourteenDaysAgo: Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date())
    }
    
    private var thirtyDaysAgo: Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())
    }
    
    // Filtered data
    private var last7DaysSets: [WorkoutSet] {
        allSets.filter { $0.timestamp >= sevenDaysAgo }
    }
    
    private var last7To14DaysSets: [WorkoutSet] {
        allSets.filter { $0.timestamp >= fourteenDaysAgo && $0.timestamp < sevenDaysAgo }
    }
    
    private var last7DaysWorkouts: [Workout] {
        workouts.filter { $0.date >= sevenDaysAgo }
    }
    
    private var last7To14DaysWorkouts: [Workout] {
        workouts.filter { $0.date >= fourteenDaysAgo && $0.date < sevenDaysAgo }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 45) {
                        ForEach(0..<4, id: \.self) { index in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSection = index
                                }
                            } label: {
                                Text(sectionNames[index])
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(selectedSection == index ? .white : Color(hex: "94A3B8"))
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        selectedSection == index
                                            ? themeColor
                                            : Color(hex: "1E293B")
                                    )
                                    .cornerRadius(22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: "0F172A"))
                }
                // Content
                ScrollView {
                    switch selectedSection {
                    case 0:
                        overviewSection
                    case 1:
                        StrengthSection(allSets: Array(allSets), workouts: Array(workouts), settings: settings)
                    case 2:
                        MusclesSection(
                            allSets: Array(allSets),
                            last7DaysSets: last7DaysSets,
                            last7To14DaysSets: last7To14DaysSets,
                            settings: settings
                        )
                    case 3:
                        bodySection
                    default:
                        EmptyView()
                    }
                }
            }
            .background(Color(hex: "0F172A"))
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(spacing: 16) {
            ThisWeekStatsCard(
                thisWeekWorkouts: last7DaysWorkouts,
                lastWeekWorkouts: last7To14DaysWorkouts,
                thisWeekSets: last7DaysSets,
                lastWeekSets: last7To14DaysSets,
                settings: settings
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            WeeklyActivityCard(workouts: workouts)
                .padding(.horizontal, 16)
            
            if let win = getBiggestWin() {
                BiggestWinCard(win: win, settings: settings)
                    .padding(.horizontal, 16)
            }
            
            MusclesThisWeekCard(thisWeekSets: last7DaysSets)
                .padding(.horizontal, 16)
            
            if let insight = generateInsight() {
                InsightCard(insight: insight)
                    .padding(.horizontal, 16)
            }
            
            StreakCard(workouts: workouts)
                .padding(.horizontal, 16)
            
            RecentWorkoutsCard(workouts: Array(workouts.prefix(5)), allSets: Array(allSets))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Body Section
    private var bodySection: some View {
        VStack(spacing: 16) {
            CurrentMeasurementsCard(measurements: Array(bodyMeasurements), settings: settings)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            if bodyMeasurements.count >= 2 {
                WeightProgressCard(measurements: Array(bodyMeasurements), settings: settings)
                    .padding(.horizontal, 16)
            }
            
            if bodyMeasurements.count >= 2 {
                ProgressSummaryCard(measurements: Array(bodyMeasurements), settings: settings)
                    .padding(.horizontal, 16)
            }
            
            AddMeasurementCard()
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Helper Functions (getBiggestWin and generateInsight remain the same)
    private func getBiggestWin() -> BiggestWin? {
        let olderSets = allSets.filter { $0.timestamp < sevenDaysAgo }
        guard !last7DaysSets.isEmpty else { return nil }
        
        var thisWeekMaxByExercise: [String: (weight: Double, exerciseName: String)] = [:]
        for set in last7DaysSets where set.setType != .warmup {
            let current = thisWeekMaxByExercise[set.exerciseId]
            if current == nil || set.weight > current!.weight {
                thisWeekMaxByExercise[set.exerciseId] = (set.weight, set.exerciseName)
            }
        }
        
        var previousMaxByExercise: [String: Double] = [:]
        for set in olderSets where set.setType != .warmup {
            let current = previousMaxByExercise[set.exerciseId] ?? 0
            if set.weight > current { previousMaxByExercise[set.exerciseId] = set.weight }
        }
        
        var biggestImprovement: (exerciseName: String, increase: Double, newWeight: Double, isPR: Bool)? = nil
        
        for (exerciseId, thisWeekData) in thisWeekMaxByExercise {
            let previousMax = previousMaxByExercise[exerciseId] ?? 0
            let increase = thisWeekData.weight - previousMax
            
            if previousMax > 0 && increase > 0 {
                if biggestImprovement == nil || increase > biggestImprovement!.increase {
                    biggestImprovement = (thisWeekData.exerciseName, increase, thisWeekData.weight, true)
                }
            }
        }
        
        if let improvement = biggestImprovement {
            return BiggestWin(type: .newPR, exerciseName: improvement.exerciseName, value: improvement.increase, newWeight: improvement.newWeight)
        }
        
        if let heaviestSet = last7DaysSets.filter({ $0.setType != .warmup && $0.weight > 0 }).max(by: { $0.weight < $1.weight }) {
            return BiggestWin(type: .heaviestLift, exerciseName: heaviestSet.exerciseName, value: heaviestSet.weight, newWeight: nil)
        }
        
        return nil
    }
    
    private func generateInsight() -> Insight? {
        guard workouts.count >= 3 else {
            return Insight(icon: "lightbulb.fill", text: "Keep logging workouts to unlock personalized insights!", color: .blue)
        }
        
        var insights: [Insight] = []
        
        let last7Volume = last7DaysSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        let prev7Volume = last7To14DaysSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        
        if prev7Volume > 0 && last7Volume > prev7Volume * 1.2 {
            let increase = Int((last7Volume / prev7Volume - 1) * 100)
            insights.append(Insight(icon: "arrow.up.right.circle.fill", text: "Your volume is up \(increase)% compared to last week! 📈", color: .green))
        }
        
        let exerciseCounts = Dictionary(grouping: allSets, by: { $0.exerciseName }).mapValues { $0.count }
        if let favorite = exerciseCounts.max(by: { $0.value < $1.value }), favorite.value >= 20 {
            insights.append(Insight(icon: "heart.fill", text: "\(favorite.key) is your favorite exercise (\(favorite.value) sets!)", color: .pink))
        }
        
        return insights.randomElement()
    }
}

// MARK: - STRENGTH SECTION

struct StrengthSection: View {
    let allSets: [WorkoutSet]
    let workouts: [Workout]
    let settings: SettingsManager
    
    @State private var searchText: String = ""
    @State private var selectedMuscle: String = "all"
    @State private var selectedEquipment: String = "all"
    @State private var selectedExerciseId: String? = nil
    
    // Pre-computed lookup dictionaries - computed ONCE
    @State private var setsByExercise: [String: [WorkoutSet]] = [:]
    @State private var workoutsById: [String: Workout] = [:]
    @State private var isDataReady = false
    
    // Race condition prevention
    @State private var isLoadingDetail = false
    @State private var loadTask: Task<Void, Never>? = nil
    
    private let muscles = ["all", "chest", "back", "lats", "shoulders", "biceps", "triceps", "quads", "hamstrings", "glutes", "calves", "core"]
    private let equipment = ["all", "barbell", "dumbbell", "cable", "machine", "bodyweight"]
    
    private var validWorkoutIds: Set<String> {
        Set(workouts.map { $0.id })
    }
    
    private var exerciseStats: [ExerciseStats] {
        guard isDataReady else { return [] }
        
        var statsByExercise: [String: ExerciseStats] = [:]
        
        for (exerciseId, sets) in setsByExercise {
            guard let firstSet = sets.first else { continue }
            
            var stats = ExerciseStats(
                exerciseId: exerciseId,
                exerciseName: firstSet.exerciseName,
                primaryMuscle: firstSet.primaryMuscle.lowercased(),
                equipment: firstSet.equipment.lowercased(),
                prWeight: 0,
                prReps: 0,
                prDate: Date(),
                totalSets: 0,
                totalVolume: 0,
                sessionCount: 0,
                lastDate: Date.distantPast
            )
            
            var uniqueDates = Set<Date>()
            
            for set in sets where set.setType != .warmup && set.weight > 0 {
                stats.totalSets += 1
                stats.totalVolume += set.weight * Double(set.reps)
                
                if set.weight > stats.prWeight {
                    stats.prWeight = set.weight
                    stats.prReps = set.reps
                    stats.prDate = set.timestamp
                }
                
                if set.timestamp > stats.lastDate {
                    stats.lastDate = set.timestamp
                }
                
                uniqueDates.insert(Calendar.current.startOfDay(for: set.timestamp))
            }
            
            stats.sessionCount = uniqueDates.count
            
            if stats.totalSets > 0 {
                statsByExercise[exerciseId] = stats
            }
        }
        
        return statsByExercise.values
            .filter { stats in
                let matchesSearch = searchText.isEmpty || stats.exerciseName.lowercased().contains(searchText.lowercased())
                let matchesMuscle = selectedMuscle == "all" || stats.primaryMuscle == selectedMuscle
                let matchesEquipment = selectedEquipment == "all" || stats.equipment == selectedEquipment
                return matchesSearch && matchesMuscle && matchesEquipment
            }
            .sorted { $0.prWeight > $1.prWeight }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filters
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "64748B"))
                    TextField("Search exercises...", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color(hex: "1E293B"))
                .cornerRadius(10)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(muscles, id: \.self) { muscle in
                            AnalyticsFilterChip(
                                title: muscle == "all" ? "All Muscles" : muscle.capitalized,
                                isSelected: selectedMuscle == muscle,
                                action: { selectedMuscle = muscle }
                            )
                        }
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(equipment, id: \.self) { equip in
                            AnalyticsFilterChip(
                                title: equip == "all" ? "All Equipment" : equip.capitalized,
                                isSelected: selectedEquipment == equip,
                                action: { selectedEquipment = equip }
                            )
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "0F172A"))
            
            // Exercise List
            if !isDataReady {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    Text("Loading exercises...")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "64748B"))
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 50)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(exerciseStats, id: \.exerciseId) { stats in
                            ExerciseStatRow(
                                stats: stats,
                                settings: settings,
                                isSelected: selectedExerciseId == stats.exerciseId
                            )
                            .onTapGesture {
                                handleExerciseTap(stats.exerciseId)
                            }
                            
                            if selectedExerciseId == stats.exerciseId {
                                if isLoadingDetail {
                                    HStack {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Loading...")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "64748B"))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                                    .background(Color(hex: "1E293B").opacity(0.5))
                                    .cornerRadius(12)
                                } else {
                                    ExerciseDetailView(
                                        stats: stats,
                                        exerciseSets: setsByExercise[stats.exerciseId] ?? [],
                                        workoutsById: workoutsById,
                                        settings: settings
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            prepareData()
        }
        .onDisappear {
            // Cancel any pending load when leaving the view
            loadTask?.cancel()
            loadTask = nil
        }
    }
    
    // MARK: - Safe Exercise Tap Handler
    private func handleExerciseTap(_ exerciseId: String) {
        // Cancel any existing load task
        loadTask?.cancel()
        
        // If tapping the same exercise, just close it
        if selectedExerciseId == exerciseId {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedExerciseId = nil
            }
            isLoadingDetail = false
            return
        }
        
        // Close previous and show loading state
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedExerciseId = exerciseId
            isLoadingDetail = true
        }
        
        // Debounce - wait a tiny bit before showing content
        loadTask = Task {
            // Small delay to debounce rapid taps
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
            
            // Check if cancelled
            if Task.isCancelled { return }
            
            // Update UI on main thread
            await MainActor.run {
                if !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLoadingDetail = false
                    }
                }
            }
        }
    }
    
    private func prepareData() {
        guard !isDataReady else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let validIds = Set(workouts.map { $0.id })
            
            // Pre-group sets by exercise ID
            var grouped: [String: [WorkoutSet]] = [:]
            
            for set in allSets {
                guard validIds.contains(set.workoutId) else { continue }
                grouped[set.exerciseId, default: []].append(set)
            }
            
            // Sort each group by timestamp descending
            for (key, sets) in grouped {
                grouped[key] = sets.sorted { $0.timestamp > $1.timestamp }
            }
            
            // Create workout lookup dictionary
            var workoutLookup: [String: Workout] = [:]
            for workout in workouts {
                workoutLookup[workout.id] = workout
            }
            
            DispatchQueue.main.async {
                self.setsByExercise = grouped
                self.workoutsById = workoutLookup
                self.isDataReady = true
            }
        }
    }
}


struct ExerciseStats: Identifiable {
    var id: String { exerciseId }
    let exerciseId: String
    let exerciseName: String
    let primaryMuscle: String
    let equipment: String
    var prWeight: Double
    var prReps: Int
    var prDate: Date
    var totalSets: Int
    var totalVolume: Double
    var sessionCount: Int
    var lastDate: Date
}

struct AnalyticsFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "94A3B8"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(hex: "1E293B"))
                .cornerRadius(16)
        }
    }
}

struct ExerciseStatRow: View {
    let stats: ExerciseStats
    let settings: SettingsManager
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(stats.primaryMuscle.capitalized)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "94A3B8"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "334155"))
                        .cornerRadius(4)
                    
                    Text(stats.equipment.capitalized)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "94A3B8"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "334155"))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(settings.formatWeightString(stats.prWeight))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                
                Text("\(stats.totalSets) sets")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "64748B"))
            }
            
            Image(systemName: "chevron.down")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "64748B"))
                .rotationEffect(.degrees(isSelected ? 180 : 0))
        }
        .padding(14)
        .background(isSelected ? Color(hex: "334155") : Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct ExerciseDetailView: View {
    let stats: ExerciseStats
    let exerciseSets: [WorkoutSet]
    let workoutsById: [String: Workout]
    let settings: SettingsManager
    
    // Computed property with limits for safety
    private var progressData: [(date: Date, weight: Double)] {
        let workingSets = exerciseSets.filter { $0.setType != .warmup && $0.weight > 0 }
        
        var maxByDate: [Date: Double] = [:]
        for set in workingSets.prefix(500) {
            let day = Calendar.current.startOfDay(for: set.timestamp)
            if maxByDate[day] == nil || set.weight > maxByDate[day]! {
                maxByDate[day] = set.weight
            }
        }
        
        return maxByDate
            .sorted { $0.key < $1.key }
            .suffix(12)
            .map { ($0.key, $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Stats Grid
            HStack(spacing: 12) {
                StatBox(title: "PR", value: settings.formatWeightString(stats.prWeight), subtitle: "\(stats.prReps) reps", icon: "trophy.fill", color: .yellow)
                StatBox(title: "Sessions", value: "\(stats.sessionCount)", icon: "calendar", color: .blue)
                StatBox(title: "Sets", value: "\(stats.totalSets)", icon: "flame.fill", color: .orange)
            }
            
            // Progress Chart
            if progressData.count >= 2 {
                ProgressChartView(progressData: progressData, settings: settings)
            } else {
                Text("Need more sessions to show progress chart")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B").opacity(0.5))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "94A3B8"))
            
            if let sub = subtitle {
                Text("@ \(sub)")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(hex: "0F172A"))
        .cornerRadius(10)
    }
}

// Separate view for progress chart to isolate rendering
struct ProgressChartView: View {
    let progressData: [(date: Date, weight: Double)]
    let settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress Over Time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Chart {
                ForEach(progressData, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Weight", settings.formatWeight(item.weight))
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Weight", settings.formatWeight(item.weight))
                    )
                    .foregroundStyle(Color.green)
                }
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let weight = value.as(Double.self) {
                            Text("\(Int(weight))")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatShortDate(date))
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(hex: "0F172A"))
        .cornerRadius(8)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// Separate view for recent sessions
struct RecentSessionsView: View {
    let recentSessions: [(date: Date, sets: [WorkoutSet], gym: String?)]
    let settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            if recentSessions.isEmpty {
                Text("No sessions found")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748B"))
            } else {
                ForEach(recentSessions, id: \.date) { session in
                    SessionRow(session: session, settings: settings)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "0F172A"))
        .cornerRadius(8)
    }
}

struct SessionRow: View {
    let session: (date: Date, sets: [WorkoutSet], gym: String?)
    let settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatDate(session.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                if let gym = session.gym {
                    Text("@ \(gym)")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Wrap sets to prevent overflow
            FlowLayoutSets(sets: session.sets, settings: settings)
        }
        .padding(10)
        .background(Color(hex: "1E293B"))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// Simple horizontal wrapping layout for sets
struct FlowLayoutSets: View {
    let sets: [WorkoutSet]
    let settings: SettingsManager
    
    var body: some View {
        // Limit to first 8 sets to prevent performance issues
        let displaySets = Array(sets.prefix(8))
        let hasMore = sets.count > 8
        
        HStack(spacing: 6) {
            ForEach(Array(displaySets.enumerated()), id: \.offset) { index, set in
                Text("\(Int(settings.formatWeight(set.weight)))×\(set.reps)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "334155"))
                    .cornerRadius(4)
            }
            
            if hasMore {
                Text("+\(sets.count - 8)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "64748B"))
            }
        }
    }
}// MARK: - MUSCLES SECTION

struct MusclesSection: View {
    let allSets: [WorkoutSet]
    let last7DaysSets: [WorkoutSet]
    let last7To14DaysSets: [WorkoutSet]
    let settings: SettingsManager
    
    private let allMuscles = ["chest", "back", "lats", "shoulders", "biceps", "triceps", "quads", "hamstrings", "glutes", "calves", "core", "forearms", "traps"]
    
    private var muscleData: [MuscleAnalyticsData] {
        var data: [MuscleAnalyticsData] = []
        
        for muscle in allMuscles {
            let muscleLower = muscle.lowercased()
            
            // Last 7 days
            let last7Sets = last7DaysSets.filter { $0.primaryMuscle.lowercased() == muscleLower }
            let last7Volume = last7Sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            let last7SetCount = last7Sets.count
            
            // Previous 7 days
            let prev7Sets = last7To14DaysSets.filter { $0.primaryMuscle.lowercased() == muscleLower }
            let prev7Volume = prev7Sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            
            // Percent change
            var percentChange: Int? = nil
            if prev7Volume > 0 {
                percentChange = Int(((last7Volume - prev7Volume) / prev7Volume) * 100)
            }
            
            // Days since last trained
            let lastTrainedSet = allSets.filter { $0.primaryMuscle.lowercased() == muscleLower }
                .max(by: { $0.timestamp < $1.timestamp })
            
            var daysSinceTraining: Int? = nil
            if let lastSet = lastTrainedSet {
                daysSinceTraining = Calendar.current.dateComponents([.day], from: lastSet.timestamp, to: Date()).day
            }
            
            let recovery = MuscleRecoveryStatus.get(daysSinceTraining: daysSinceTraining)
            
            data.append(MuscleAnalyticsData(
                muscle: muscle,
                last7DaysVolume: last7Volume,
                last7DaysSets: last7SetCount,
                prev7DaysVolume: prev7Volume,
                percentChange: percentChange,
                daysSinceTraining: daysSinceTraining,
                recovery: recovery
            ))
        }
        
        // Sort by priority (primed/overdue first, then ready, then recovering, then trained today)
        return data.filter { $0.last7DaysVolume > 0 || $0.daysSinceTraining != nil }
            .sorted { $0.recovery.priority < $1.recovery.priority }
    }
    
    private var pushVsPull: (push: Int, pull: Int) {
        let pushMuscles = ["chest", "shoulders", "triceps"]
        let pullMuscles = ["back", "lats", "biceps", "forearms", "traps"]
        
        let push = last7DaysSets.filter { pushMuscles.contains($0.primaryMuscle.lowercased()) }.count
        let pull = last7DaysSets.filter { pullMuscles.contains($0.primaryMuscle.lowercased()) }.count
        
        return (push, pull)
    }
    
    private var upperVsLower: (upper: Int, lower: Int) {
        let upperMuscles = ["chest", "back", "lats", "shoulders", "biceps", "triceps", "forearms", "traps"]
        let lowerMuscles = ["quads", "hamstrings", "glutes", "calves"]
        
        let upper = last7DaysSets.filter { upperMuscles.contains($0.primaryMuscle.lowercased()) }.count
        let lower = last7DaysSets.filter { lowerMuscles.contains($0.primaryMuscle.lowercased()) }.count
        
        return (upper, lower)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Balance Cards
            HStack(spacing: 12) {
                BalanceCard(title: "Push vs Pull", left: ("Push", pushVsPull.push), right: ("Pull", pushVsPull.pull), leftColor: .red, rightColor: .blue)
                BalanceCard(title: "Upper vs Lower", left: ("Upper", upperVsLower.upper), right: ("Lower", upperVsLower.lower), leftColor: .purple, rightColor: .green)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Muscle Stimulus List
            VStack(alignment: .leading, spacing: 12) {
                Text("💪 Muscle Status")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(muscleData, id: \.muscle) { data in
                    MuscleStatusRow(data: data, settings: settings)
                }
                
                if muscleData.isEmpty {
                    Text("Start working out to see muscle data!")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "64748B"))
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(Color(hex: "1E293B"))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
}

struct MuscleAnalyticsData {
    let muscle: String
    let last7DaysVolume: Double
    let last7DaysSets: Int
    let prev7DaysVolume: Double
    let percentChange: Int?
    let daysSinceTraining: Int?
    let recovery: MuscleRecoveryStatus
}

struct BalanceCard: View {
    let title: String
    let left: (label: String, value: Int)
    let right: (label: String, value: Int)
    let leftColor: Color
    let rightColor: Color
    
    private var total: Int { max(left.value + right.value, 1) }
    private var leftPercent: Int { Int(Double(left.value) / Double(total) * 100) }
    private var rightPercent: Int { 100 - leftPercent }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "94A3B8"))
            
            HStack(spacing: 4) {
                Text("\(leftPercent)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(leftColor)
                
                Text("/")
                    .foregroundColor(Color(hex: "64748B"))
                
                Text("\(rightPercent)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rightColor)
            }
            
            // Balance bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(leftColor)
                        .frame(width: geo.size.width * CGFloat(leftPercent) / 100)
                    Rectangle()
                        .fill(rightColor)
                        .frame(width: geo.size.width * CGFloat(rightPercent) / 100)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            HStack {
                Text(left.label)
                    .font(.system(size: 10))
                    .foregroundColor(leftColor)
                Spacer()
                Text(right.label)
                    .font(.system(size: 10))
                    .foregroundColor(rightColor)
            }
        }
        .padding(12)
        .background(Color(hex: "1E293B"))
        .cornerRadius(10)
    }
}

struct MuscleStatusRow: View {
    let data: MuscleAnalyticsData
    let settings: SettingsManager
    
    private var needsAttention: Bool {
        data.recovery.status == "overdue" || data.recovery.status == "primed" ||
        (data.percentChange ?? 0) < -20
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Status icon and muscle name
                HStack(spacing: 8) {
                    Text(data.recovery.icon)
                        .font(.system(size: 18))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.muscle.capitalized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(data.recovery.label)
                            .font(.system(size: 11))
                            .foregroundColor(data.recovery.color)
                    }
                }
                
                Spacer()
                
                // Volume and trend
                VStack(alignment: .trailing, spacing: 2) {
                    if data.last7DaysVolume > 0 {
                        Text(settings.formatVolume(data.last7DaysVolume))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    if let change = data.percentChange {
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(abs(change))%")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(change >= 0 ? .green : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((change >= 0 ? Color.green : Color.orange).opacity(0.15))
                        .cornerRadius(4)
                    }
                }
            }
            
            // Sets count
            HStack {
                Text("\(data.last7DaysSets) sets this week")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "64748B"))
                Spacer()
            }
        }
        .padding(12)
        .background(needsAttention ? Color.orange.opacity(0.1) : Color(hex: "0F172A"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(needsAttention ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Supporting Types (Keep existing)

struct BiggestWin {
    enum WinType { case newPR, weightIncrease, volumeKing, heaviestLift }
    let type: WinType
    let exerciseName: String
    let value: Double
    let newWeight: Double?
}

struct Insight {
    let icon: String
    let text: String
    let color: Color
}


// MARK: - Overview Cards

struct ThisWeekStatsCard: View {
    let thisWeekWorkouts: [Workout]
    let lastWeekWorkouts: [Workout]
    let thisWeekSets: [WorkoutSet]
    let lastWeekSets: [WorkoutSet]
    let settings: SettingsManager
    
    private var thisWeekVolume: Double {
        thisWeekSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    private var lastWeekVolume: Double {
        lastWeekSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 Days")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                WeekStatItem(
                    label: "Workouts",
                    value: "\(thisWeekWorkouts.count)",
                    comparison: thisWeekWorkouts.count - lastWeekWorkouts.count,
                    isPercentage: false,
                    icon: "figure.strengthtraining.traditional"
                )
                
                WeekStatItem(
                    label: "Sets",
                    value: "\(thisWeekSets.count)",
                    comparison: thisWeekSets.count - lastWeekSets.count,
                    isPercentage: false,
                    icon: "flame.fill"
                )
                
                WeekStatItem(
                    label: "Volume",
                    value: settings.formatVolume(thisWeekVolume),
                    comparison: compareVolume(),
                    isPercentage: true,
                    icon: "scalemass.fill"
                )
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
    
    private func compareVolume() -> Int {
        guard lastWeekVolume > 0 else { return 0 }
        let percentChange = ((thisWeekVolume - lastWeekVolume) / lastWeekVolume) * 100
        return Int(percentChange)
    }
}

struct WeekStatItem: View {
    let label: String
    let value: String
    let comparison: Int
    let isPercentage: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "94A3B8"))
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "94A3B8"))
            
            if comparison != 0 {
                HStack(spacing: 2) {
                    Image(systemName: comparison > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(isPercentage ? "\(abs(comparison))%" : "\(abs(comparison))")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(comparison > 0 ? .green : .red)
            } else {
                Text("—")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "64748B"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "0F172A"))
        .cornerRadius(10)
    }
}

struct WeeklyActivityCard: View {
    let workouts: [Workout]
    
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                // Use enumerated() with index as ID instead of the day string
                ForEach(Array(last7Days.enumerated()), id: \.offset) { index, date in
                    let hasWorkout = hasWorkout(on: date)
                    let isToday = Calendar.current.isDateInToday(date)
                    let dayIndex = Calendar.current.component(.weekday, from: date) - 1
                    
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(hasWorkout ? Color.green : Color(hex: "334155"))
                                .frame(width: 36, height: 36)
                            
                            if hasWorkout {
                                Text("💪")
                                    .font(.system(size: 16))
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(isToday ? Color.white : Color.clear, lineWidth: 2)
                        )
                        
                        Text(dayLabels[dayIndex])
                            .font(.system(size: 11, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? .white : Color(hex: "94A3B8"))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
    
    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -(6 - $0), to: today) }
    }
    
    private func hasWorkout(on date: Date) -> Bool {
        let calendar = Calendar.current
        return workouts.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

struct BiggestWinCard: View {
    let win: BiggestWin
    let settings: SettingsManager
    
    private var isPR: Bool { win.type == .newPR }
    
    private var title: String {
        switch win.type {
        case .newPR: return "New PR This Week!"
        case .weightIncrease: return "Weight Increase!"
        case .volumeKing: return "Volume King"
        case .heaviestLift: return "Heaviest Lift This Week"
        }
    }
    
    private var emoji: String {
        switch win.type {
        case .newPR: return "🏆"
        case .weightIncrease: return "📈"
        case .volumeKing: return "👑"
        case .heaviestLift: return "💪"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isPR ? Color.yellow.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 56, height: 56)
                Text(emoji)
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isPR ? .yellow : .green)
                    .textCase(.uppercase)
                
                Text(win.exerciseName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if isPR, let newWeight = win.newWeight {
                    Text("+\(Int(settings.formatWeight(win.value))) \(settings.weightLabel) → \(Int(settings.formatWeight(newWeight))) \(settings.weightLabel)")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94A3B8"))
                } else if win.type == .heaviestLift {
                    Text(settings.formatWeightString(win.value))
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94A3B8"))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [isPR ? Color.yellow.opacity(0.15) : Color.green.opacity(0.15), Color(hex: "1E293B")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPR ? Color.yellow.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct MusclesThisWeekCard: View {
    let thisWeekSets: [WorkoutSet]
    
    private var muscleData: [(muscle: String, sets: Int, percentage: Double)] {
        var muscleCounts: [String: Int] = [:]
        for set in thisWeekSets {
            muscleCounts[set.primaryMuscle.lowercased(), default: 0] += 1
        }
        
        let maxSets = muscleCounts.values.max() ?? 1
        
        return muscleCounts
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { (muscle: $0.key.capitalized, sets: $0.value, percentage: Double($0.value) / Double(maxSets) * 100) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscles Trained")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            if muscleData.isEmpty {
                Text("No workouts in the last 7 days")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(muscleData, id: \.muscle) { data in
                        HStack(spacing: 12) {
                            Text(data.muscle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "CBD5E1"))
                                .frame(width: 80, alignment: .leading)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(hex: "334155"))
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(muscleColor(for: data.muscle))
                                        .frame(width: geo.size.width * data.percentage / 100, height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(data.sets)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "94A3B8"))
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
    
    private func muscleColor(for muscle: String) -> Color {
        switch muscle.lowercased() {
        case "chest": return .red
        case "back", "lats": return .blue
        case "shoulders": return .orange
        case "biceps": return .purple
        case "triceps": return .pink
        case "quads", "hamstrings", "glutes": return .green
        case "core", "abs": return .yellow
        default: return .gray
        }
    }
}

struct InsightCard: View {
    let insight: Insight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.system(size: 24))
                .foregroundColor(insight.color)
            
            Text(insight.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [insight.color.opacity(0.15), Color(hex: "1E293B")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }
}

struct StreakCard: View {
    let workouts: [Workout]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "94A3B8"))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("days")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "94A3B8"))
                }
            }
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundColor(currentStreak > 0 ? .orange : Color(hex: "334155"))
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        
        let todayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
        if todayWorkouts.isEmpty {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            let yesterdayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if yesterdayWorkouts.isEmpty { return 0 }
        }
        
        while true {
            let dayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if dayWorkouts.isEmpty { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        return streak
    }
}

struct RecentWorkoutsCard: View {
    let workouts: [Workout]
    let allSets: [WorkoutSet]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            if workouts.isEmpty {
                Text("No workouts yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(workouts, id: \.id) { workout in
                        RecentWorkoutRow(workout: workout, allSets: allSets)
                        if workout.id != workouts.last?.id {
                            Divider().background(Color(hex: "334155"))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct RecentWorkoutRow: View {
    let workout: Workout
    let allSets: [WorkoutSet]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutType ?? "Workout")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(formatDate(workout.date))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748B"))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(workout.totalSets) sets")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "94A3B8"))
                
                Text(formatDuration(workout.duration ?? 0))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748B"))
            }
        }
        .padding(.vertical, 10)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Strength Cards

struct AllTimePRsCard: View {
    let allSets: [WorkoutSet]
    let settings: SettingsManager
    
    private var topPRs: [(exercise: String, weight: Double, reps: Int, date: Date)] {
        var prByExercise: [String: (weight: Double, reps: Int, date: Date)] = [:]
        
        for set in allSets where set.setType != .warmup && set.weight > 0 {
            let existing = prByExercise[set.exerciseName]
            if existing == nil || set.weight > existing!.weight {
                prByExercise[set.exerciseName] = (set.weight, set.reps, set.timestamp)
            }
        }
        
        return prByExercise
            .map { (exercise: $0.key, weight: $0.value.weight, reps: $0.value.reps, date: $0.value.date) }
            .sorted { $0.weight > $1.weight }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🏆 All-Time PRs")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if topPRs.isEmpty {
                Text("Start lifting to set PRs!")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topPRs.enumerated()), id: \.offset) { index, pr in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.exercise)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(formatDate(pr.date))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "64748B"))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(settings.formatWeightString(pr.weight))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text("\(pr.reps) reps")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "94A3B8"))
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "0F172A"))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct StrengthGainsCard: View {
    let last30DaysSets: [WorkoutSet]
    let olderSets: [WorkoutSet]
    let settings: SettingsManager
    
    private var gains: [(exercise: String, change: Double, newMax: Double)] {
        var last30Max: [String: Double] = [:]
        var olderMax: [String: Double] = [:]
        
        for set in last30DaysSets where set.setType != .warmup && set.weight > 0 {
            let current = last30Max[set.exerciseName] ?? 0
            if set.weight > current { last30Max[set.exerciseName] = set.weight }
        }
        
        for set in olderSets where set.setType != .warmup && set.weight > 0 {
            let current = olderMax[set.exerciseName] ?? 0
            if set.weight > current { olderMax[set.exerciseName] = set.weight }
        }
        
        var results: [(exercise: String, change: Double, newMax: Double)] = []
        
        for (exercise, newMax) in last30Max {
            if let oldMax = olderMax[exercise], newMax > oldMax {
                results.append((exercise: exercise, change: newMax - oldMax, newMax: newMax))
            }
        }
        
        return results.sorted { $0.change > $1.change }.prefix(5).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💪 Strength Gains (30 Days)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if gains.isEmpty {
                Text("Keep pushing to see your gains!")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(gains.enumerated()), id: \.offset) { index, gain in
                        HStack {
                            Text(gain.exercise)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 11, weight: .bold))
                                Text("+\(Int(settings.formatWeight(gain.change))) \(settings.weightLabel)")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.green)
                        }
                        .padding(12)
                        .background(Color(hex: "0F172A"))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct ExerciseProgressCard: View {
    let allSets: [WorkoutSet]
    let settings: SettingsManager
    
    @State private var selectedExercise: String? = nil
    
    private var exercises: [String] {
        let exerciseCounts = Dictionary(grouping: allSets, by: { $0.exerciseName })
            .mapValues { $0.count }
            .filter { $0.value >= 3 }
        
        return exerciseCounts.sorted { $0.value > $1.value }.map { $0.key }.prefix(10).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📈 Exercise Progress")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if exercises.isEmpty {
                Text("Log more sets to see progress")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                            Button {
                                selectedExercise = selectedExercise == exercise ? nil : exercise
                            } label: {
                                Text(exercise)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedExercise == exercise ? .white : Color(hex: "94A3B8"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedExercise == exercise ? Color.blue : Color(hex: "0F172A"))
                                    .cornerRadius(16)
                            }
                        }
                    }
                }
                
                if let exercise = selectedExercise {
                    ExerciseProgressChart(exerciseName: exercise, allSets: allSets, settings: settings)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct ExerciseProgressChart: View {
    let exerciseName: String
    let allSets: [WorkoutSet]
    let settings: SettingsManager
    
    private var progressData: [(date: Date, maxWeight: Double)] {
        let exerciseSets = allSets
            .filter { $0.exerciseName == exerciseName && $0.setType != .warmup && $0.weight > 0 }
            .sorted { $0.timestamp < $1.timestamp }
        
        var maxByDate: [String: (date: Date, weight: Double)] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for set in exerciseSets {
            let dateKey = formatter.string(from: set.timestamp)
            if maxByDate[dateKey] == nil || set.weight > maxByDate[dateKey]!.weight {
                maxByDate[dateKey] = (set.timestamp, set.weight)
            }
        }
        
        return maxByDate.values.sorted { $0.date < $1.date }.suffix(10).map { ($0.date, $0.weight) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if progressData.count < 2 {
                Text("Need more sessions to show chart")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 12)
            } else {
                let minWeight = progressData.map { $0.maxWeight }.min() ?? 0
                let maxWeight = progressData.map { $0.maxWeight }.max() ?? 1
                let range = max(maxWeight - minWeight, 1)
                
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(progressData.enumerated()), id: \.offset) { index, data in
                        VStack(spacing: 4) {
                            Text("\(Int(settings.formatWeight(data.maxWeight)))")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "94A3B8"))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(20, CGFloat((data.maxWeight - minWeight) / range) * 80 + 20))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)
                
                HStack {
                    Text(formatDate(progressData.first?.date ?? Date()))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "64748B"))
                    Spacer()
                    Text(formatDate(progressData.last?.date ?? Date()))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "64748B"))
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Muscles Cards

struct MuscleBalanceCard: View {
    let last7DaysSets: [WorkoutSet]
    let last7To14DaysSets: [WorkoutSet]
    
    private var muscleData: [(muscle: String, sets: Int, trend: Int)] {
        var thisWeek: [String: Int] = [:]
        var lastWeek: [String: Int] = [:]
        
        for set in last7DaysSets {
            thisWeek[set.primaryMuscle.lowercased(), default: 0] += 1
        }
        
        for set in last7To14DaysSets {
            lastWeek[set.primaryMuscle.lowercased(), default: 0] += 1
        }
        
        let allMuscles = Set(thisWeek.keys).union(lastWeek.keys)
        
        return allMuscles.map { muscle in
            let current = thisWeek[muscle] ?? 0
            let previous = lastWeek[muscle] ?? 0
            let trend = current - previous
            return (muscle: muscle.capitalized, sets: current, trend: trend)
        }
        .sorted { $0.sets > $1.sets }
        .prefix(8)
        .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎯 Muscle Balance")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if muscleData.isEmpty {
                Text("No data yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(muscleData.enumerated()), id: \.offset) { index, data in                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(data.muscle)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("\(data.sets) sets")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "94A3B8"))
                            }
                            
                            Spacer()
                            
                            if data.trend != 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: data.trend > 0 ? "arrow.up" : "arrow.down")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("\(abs(data.trend))")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(data.trend > 0 ? .green : .red)
                            }
                        }
                        .padding(10)
                        .background(Color(hex: "0F172A"))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct PushPullLegsCard: View {
    let last7DaysSets: [WorkoutSet]
    
    private var splitData: (push: Int, pull: Int, legs: Int) {
        var push = 0, pull = 0, legs = 0
        
        let pushMuscles = ["chest", "shoulders", "triceps"]
        let pullMuscles = ["back", "lats", "biceps", "forearms", "traps"]
        let legMuscles = ["quads", "hamstrings", "glutes", "calves"]
        
        for set in last7DaysSets {
            let muscle = set.primaryMuscle.lowercased()
            if pushMuscles.contains(muscle) { push += 1 }
            else if pullMuscles.contains(muscle) { pull += 1 }
            else if legMuscles.contains(muscle) { legs += 1 }
        }
        
        return (push, pull, legs)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚖️ Push / Pull / Legs")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            let total = max(splitData.push + splitData.pull + splitData.legs, 1)
            
            HStack(spacing: 12) {
                SplitStatItem(label: "Push", value: splitData.push, total: total, color: .red)
                SplitStatItem(label: "Pull", value: splitData.pull, total: total, color: .blue)
                SplitStatItem(label: "Legs", value: splitData.legs, total: total, color: .green)
            }
            
            // Balance bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if splitData.push > 0 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width * CGFloat(splitData.push) / CGFloat(total))
                    }
                    if splitData.pull > 0 {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geo.size.width * CGFloat(splitData.pull) / CGFloat(total))
                    }
                    if splitData.legs > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geo.size.width * CGFloat(splitData.legs) / CGFloat(total))
                    }
                }
                .cornerRadius(4)
            }
            .frame(height: 12)
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct SplitStatItem: View {
    let label: String
    let value: Int
    let total: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "94A3B8"))
            
            Text("\(Int(Double(value) / Double(total) * 100))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "0F172A"))
        .cornerRadius(8)
    }
}

struct MuscleVolumeCard: View {
    let last7DaysSets: [WorkoutSet]
    let last7To14DaysSets: [WorkoutSet]
    let settings: SettingsManager
    
    private var volumeData: [(muscle: String, volume: Double, percentChange: Int?)] {
        var thisWeekVolume: [String: Double] = [:]
        var lastWeekVolume: [String: Double] = [:]
        
        for set in last7DaysSets {
            let volume = set.weight * Double(set.reps)
            thisWeekVolume[set.primaryMuscle.lowercased(), default: 0] += volume
        }
        
        for set in last7To14DaysSets {
            let volume = set.weight * Double(set.reps)
            lastWeekVolume[set.primaryMuscle.lowercased(), default: 0] += volume
        }
        
        return thisWeekVolume.map { muscle, volume in
            let lastWeek = lastWeekVolume[muscle] ?? 0
            let percentChange: Int? = lastWeek > 0 ? Int(((volume - lastWeek) / lastWeek) * 100) : nil
            return (muscle: muscle.capitalized, volume: volume, percentChange: percentChange)
        }
        .sorted { $0.volume > $1.volume }
        .prefix(6)
        .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Volume by Muscle")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if volumeData.isEmpty {
                Text("No data yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(volumeData.enumerated()), id: \.offset) { index, data in
                        HStack {
                            Text(data.muscle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 90, alignment: .leading)
                            
                            Text(settings.formatVolume(data.volume))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            if let change = data.percentChange {
                                HStack(spacing: 2) {
                                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("\(abs(change))%")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(change >= 0 ? .green : .orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((change >= 0 ? Color.green : Color.orange).opacity(0.15))
                                .cornerRadius(4)
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "0F172A"))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct NeglectedMusclesCard: View {
    let allSets: [WorkoutSet]
    
    private var neglectedMuscles: [(muscle: String, daysSince: Int)] {
        let allMuscles = ["chest", "back", "shoulders", "biceps", "triceps", "quads", "hamstrings", "glutes", "calves", "core"]
        
        var lastTrained: [String: Date] = [:]
        
        for set in allSets {
            let muscle = set.primaryMuscle.lowercased()
            if lastTrained[muscle] == nil || set.timestamp > lastTrained[muscle]! {
                lastTrained[muscle] = set.timestamp
            }
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        return allMuscles.compactMap { muscle in
            if let lastDate = lastTrained[muscle] {
                let days = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
                if days >= 7 {
                    return (muscle: muscle.capitalized, daysSince: days)
                }
            } else if allSets.count > 10 {
                // Only show as neglected if user has been training
                return (muscle: muscle.capitalized, daysSince: 999)
            }
            return nil
        }
        .sorted { $0.daysSince > $1.daysSince }
        .prefix(4)
        .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚠️ Needs Attention")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if neglectedMuscles.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All muscles trained recently!")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94A3B8"))
                }
                .padding(.vertical, 12)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(neglectedMuscles.enumerated()), id: \.offset) { index, data in
                        HStack(spacing: 6) {
                            Text(data.muscle)
                                .font(.system(size: 13, weight: .semibold))
                            
                            Text(data.daysSince >= 999 ? "Never" : "\(data.daysSince)d")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "94A3B8"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(16)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Body Cards

struct CurrentMeasurementsCard: View {
    let measurements: [BodyMeasurement]
    let settings: SettingsManager
    
    private var latest: BodyMeasurement? { measurements.first }
    private var previous: BodyMeasurement? { measurements.count > 1 ? measurements[1] : nil }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📏 Current Measurements")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if let m = latest {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MeasurementItem(
                        label: "Weight",
                        value: m.weight > 0 ? settings.formatWeightString(m.weight) : "-",
                        change: getChange(current: m.weight, previous: previous?.weight, unit: settings.weightLabel),
                        isHighlight: true
                    )
                    
                    MeasurementItem(label: "Chest", value: m.chest > 0 ? "\(String(format: "%.1f", m.chest))\"" : "-", change: nil)
                    MeasurementItem(label: "Waist", value: m.waist > 0 ? "\(String(format: "%.1f", m.waist))\"" : "-", change: nil)
                    MeasurementItem(label: "Arms", value: m.arms > 0 ? "\(String(format: "%.1f", m.arms))\"" : "-", change: nil)
                    MeasurementItem(label: "Thighs", value: m.thighs > 0 ? "\(String(format: "%.1f", m.thighs))\"" : "-", change: nil)
                }
                
                Text("Last updated: \(formatDate(m.date))")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748B"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            } else {
                Text("No measurements recorded yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
    
    private func getChange(current: Double, previous: Double?, unit: String) -> (value: String, isPositive: Bool)? {
        guard let prev = previous, prev > 0, current > 0 else { return nil }
        let diff = current - prev
        if diff == 0 { return nil }
        return (value: "\(diff > 0 ? "+" : "")\(String(format: "%.1f", settings.formatWeight(diff))) \(unit)", isPositive: diff > 0)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct MeasurementItem: View {
    let label: String
    let value: String
    let change: (value: String, isPositive: Bool)?
    var isHighlight: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "64748B"))
                .textCase(.uppercase)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            if let change = change {
                Text(change.value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(change.isPositive ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            isHighlight
                ? LinearGradient(colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [Color(hex: "0F172A"), Color(hex: "0F172A")], startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHighlight ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct WeightProgressCard: View {
    let measurements: [BodyMeasurement]
    let settings: SettingsManager
    
    private var weightData: [(date: Date, weight: Double)] {
        measurements
            .filter { $0.weight > 0 }
            .sorted { $0.date < $1.date }
            .suffix(12)
            .map { ($0.date, $0.weight) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📉 Weight History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if weightData.count < 2 {
                Text("Need more measurements")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 12)
            } else {
                let minWeight = weightData.map { $0.weight }.min() ?? 0
                let maxWeight = weightData.map { $0.weight }.max() ?? 1
                let range = max(maxWeight - minWeight, 1)
                
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(weightData.enumerated()), id: \.offset) { index, data in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(20, CGFloat((data.weight - minWeight) / range) * 80 + 20))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)
                
                HStack {
                    Text(formatDate(weightData.first?.date ?? Date()))
                    Spacer()
                    Text(formatDate(weightData.last?.date ?? Date()))
                }
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "64748B"))
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct ProgressSummaryCard: View {
    let measurements: [BodyMeasurement]
    let settings: SettingsManager
    
    private var first: BodyMeasurement? { measurements.last }
    private var latest: BodyMeasurement? { measurements.first }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Progress Summary")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if let first = first, let latest = latest, first.weight > 0, latest.weight > 0 {
                let weightChange = latest.weight - first.weight
                
                HStack(spacing: 16) {
                    ProgressItem(
                        label: "Starting",
                        value: settings.formatWeightString(first.weight)
                    )
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(Color(hex: "64748B"))
                    
                    ProgressItem(
                        label: "Current",
                        value: settings.formatWeightString(latest.weight)
                    )
                    
                    VStack(spacing: 4) {
                        Text("Change")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "64748B"))
                        
                        Text("\(weightChange >= 0 ? "+" : "")\(Int(settings.formatWeight(weightChange))) \(settings.weightLabel)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(weightChange >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .cornerRadius(12)
    }
}

struct ProgressItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "64748B"))
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct AddMeasurementCard: View {
    @State private var showMeasurementSheet = false
    
    var body: some View {
        Button {
            showMeasurementSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("Add/Update Measurements")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                LinearGradient(
                    colors: [.green, .green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .sheet(isPresented: $showMeasurementSheet) {
            AddMeasurementSheet()
        }
    }
}

struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var settings = SettingsManager.shared
    
    @State private var weight: String = ""
    @State private var chest: String = ""
    @State private var waist: String = ""
    @State private var arms: String = ""
    @State private var thighs: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Measurements") {
                    HStack {
                        Text("Body Weight (\(settings.weightLabel))")
                        Spacer()
                        TextField("175", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Chest (inches)")
                        Spacer()
                        TextField("42", text: $chest)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Waist (inches)")
                        Spacer()
                        TextField("32", text: $waist)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Arms (inches)")
                        Spacer()
                        TextField("15", text: $arms)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Thighs (inches)")
                        Spacer()
                        TextField("24", text: $thighs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("Body Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMeasurement()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveMeasurement() {
        var weightValue = Double(weight) ?? 0
        
        // Convert kg input to lbs for storage if needed
        if settings.weightUnit == "kg" && weightValue > 0 {
            weightValue = weightValue * 2.205
        }
        
        let measurement = BodyMeasurement(
            date: Date(),
            weight: weightValue,
            chest: Double(chest) ?? 0,
            waist: Double(waist) ?? 0,
            arms: Double(arms) ?? 0,
            thighs: Double(thighs) ?? 0
        )
        
        modelContext.insert(measurement)
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(ThemeManager.shared)
        .modelContainer(for: [Workout.self, WorkoutSet.self, BodyMeasurement.self], inMemory: true)
}
