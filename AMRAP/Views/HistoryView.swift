import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \WorkoutSet.timestamp, order: .reverse) private var allSets: [WorkoutSet]
    
    @State private var viewMode: ViewMode = .calendar
    @State private var selectedDate: Date = Date()
    @State private var selectedWorkout: Workout? = nil
    @State private var showWorkoutDetail = false
    @State private var expandedWorkoutId: String? = nil
    
    enum ViewMode: String, CaseIterable {
        case calendar = "Calendar"
        case list = "List"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View mode picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if viewMode == .calendar {
                    calendarView
                } else {
                    listView
                }
            }
            .navigationTitle("History")
            .background(Color.black.opacity(0.95))
            .sheet(isPresented: $showWorkoutDetail) {
                if let workout = selectedWorkout {
                    WorkoutDetailSheet(
                        workout: workout,
                        sets: getSetsForWorkout(workout),
                        onDelete: {
                            deleteWorkout(workout)
                            showWorkoutDetail = false
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Calendar View
    private var calendarView: some View {
        VStack(spacing: 0) {
            CalendarGridView(
                selectedDate: $selectedDate,
                workouts: workouts,
                allSets: allSets,  // ADD THIS LINE
                onDateSelected: { date in
                    if let workout = workouts.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                        selectedWorkout = workout
                        showWorkoutDetail = true
                    }
                }
            )
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            selectedDateInfo
        }
    }
    
    private var selectedDateInfo: some View {
        let workoutsOnDate = workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        
        return VStack(spacing: 12) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            if workoutsOnDate.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.cooldown")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Rest Day")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(workoutsOnDate) { workout in
                            WorkoutPreviewCard(workout: workout, sets: getSetsForWorkout(workout)) {
                                selectedWorkout = workout
                                showWorkoutDetail = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - List View
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if workouts.isEmpty {
                    emptyState
                } else {
                    ForEach(workouts) { workout in
                        WorkoutListItem(
                            workout: workout,
                            sets: getSetsForWorkout(workout),
                            isExpanded: expandedWorkoutId == workout.id,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expandedWorkoutId = expandedWorkoutId == workout.id ? nil : workout.id
                                }
                            },
                            onDelete: { deleteWorkout(workout) },
                            onShare: { shareWorkout(workout) }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Complete your first workout to see it here")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helper Functions
    
    private func getSetsForWorkout(_ workout: Workout) -> [WorkoutSet] {
        allSets.filter { $0.workoutId == workout.id }.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func deleteWorkout(_ workout: Workout) {
        let setsToDelete = getSetsForWorkout(workout)
        for set in setsToDelete {
            modelContext.delete(set)
        }
        modelContext.delete(workout)
        
        if expandedWorkoutId == workout.id {
            expandedWorkoutId = nil
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func shareWorkout(_ workout: Workout) {
        let sets = getSetsForWorkout(workout)
        let shareText = formatWorkoutForShare(workout: workout, sets: sets)
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func formatWorkoutForShare(workout: Workout, sets: [WorkoutSet]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        
        let workoutType = detectWorkoutType(from: sets)
        
        var text = "1 workout from AMRAP\n"
        text += "AMRAP Workout Log\n"
        text += "Exported: \(Date().formatted(.dateTime.month().day().year()))\n"
        text += "═══════════════════════════════════════\n\n"
        
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "🏋️ \(workoutType)\n"
        text += "📅 \(dateFormatter.string(from: workout.date))\n"
        
        if let gym = workout.gym, !gym.isEmpty {
            text += "📍 \(gym)\n"
        }
        
        let duration = workout.duration ?? 0
        if duration > 0 {
            text += "⏱️ \(duration) minutes\n"
        }
        
        if let rpe = workout.rpe {
            text += "💪 Effort: \(rpe)/10\n"
        }
        
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        
        if let notes = workout.notes, !notes.isEmpty {
            text += "📝 \(notes)\n\n"
        }
        
        let groupedSets = groupSetsByExercise(sets)
        
        for group in groupedSets {
            text += "💪 \(group.exerciseName)\n"
            
            if let note = group.exerciseNote, !note.isEmpty {
                text += "   📝 \(note)\n"
            }
            
            for setInfo in group.sets {
                let setLabel = formatSetLabel(setInfo: setInfo)
                let failureEmoji = setInfo.toFailure ? " 🔥" : ""
                let dropIndicator = setInfo.isDropPortion ? " ↓" : ""
                let weightInt = Int(setInfo.weight)
                
                text += "   \(setLabel). \(weightInt)lbs × \(setInfo.reps)\(failureEmoji)\(dropIndicator)\n"
            }
            
            text += "\n"
        }
        
        let workingSets = sets.filter { $0.setType != .warmup && ($0.dropIndex ?? 0) == 0 };        let workingSetCount = workingSets.count;
        let setsPerMin = (workout.duration ?? 0) > 0 ? Double(workingSetCount) / Double(workout.duration ?? 0) : 0
        
        text += "📊 Summary: \(workingSetCount) working sets • \(String(format: "%.2f", setsPerMin)) sets/min\n\n"
        text += "═══════════════════════════════════════\n"
        text += "Exported from AMRAP - Workout Tracker"
        
        return text
    }
    
    struct ExerciseSetGroup {
        let exerciseName: String
        let exerciseNote: String?
        var sets: [SetInfo]
    }
    
    struct SetInfo {
        let weight: Double
        let reps: Int
        let toFailure: Bool
        let setGroup: Int
        let dropIndex: Int
        let isDropPortion: Bool
        let setType: SetType
    }
    
    private func groupSetsByExercise(_ sets: [WorkoutSet]) -> [ExerciseSetGroup] {
        var groups: [ExerciseSetGroup] = []
        var currentExerciseId: String? = nil
        
        for set in sets {
            let dropIdx = set.dropIndex ?? 0
            let setInfo = SetInfo(
                weight: set.weight,
                reps: set.reps,
                toFailure: set.toFailure,
                setGroup: set.setGroup,
                dropIndex: dropIdx,
                isDropPortion: dropIdx > 0,
                setType: set.setType
            )
            
            if set.exerciseId == currentExerciseId, let lastIndex = groups.indices.last {
                groups[lastIndex].sets.append(setInfo)
            } else {
                groups.append(ExerciseSetGroup(
                    exerciseName: set.exerciseName,
                    exerciseNote: set.exerciseNote,
                    sets: [setInfo]
                ))
                currentExerciseId = set.exerciseId
            }
        }
        
        return groups
    }
    
    private func formatSetLabel(setInfo: SetInfo) -> String {
        if setInfo.isDropPortion {
            let baseSetNum = setInfo.setGroup
            let letterCode = 96 + setInfo.dropIndex
            if let scalar = UnicodeScalar(letterCode) {
                return "   \(baseSetNum)\(Character(scalar))"
            }
        }
        return "\(setInfo.setGroup)"
    }
    


    }




// MARK: - Calendar Grid View
struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let workouts: [Workout]
    let allSets: [WorkoutSet]  // ADD THIS NEW PARAMETER
    let onDateSelected: (Date) -> Void
    
    @State private var displayedMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    private var monthString: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }
    
    private var daysInMonth: [Date?] {
        var days: [Date?] = []
        
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return days
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let offsetDays = firstWeekday - 1
        
        for _ in 0..<offsetDays {
            days.append(nil)
        }
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // Helper to get sets for a specific workout
    private func getSetsForDate(_ date: Date) -> [WorkoutSet] {
        guard let workout = workouts.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return []
        }
        return allSets.filter { $0.workoutId == workout.id }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation {
                        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                            displayedMonth = newMonth
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                }
                
                Spacer()
                
                Text(monthString)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    withAnimation {
                        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                            displayedMonth = newMonth
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            workout: workouts.first { calendar.isDate($0.date, inSameDayAs: date) },
                            workoutSets: getSetsForDate(date),  // ADD THIS
                            onTap: {
                                selectedDate = date
                                if workouts.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                                    onDateSelected(date)
                                }
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let workout: Workout?
    let workoutSets: [WorkoutSet]  // ADD THIS NEW PARAMETER
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }
    
    private var workoutType: String {
        guard !workoutSets.isEmpty else { return "" }
        return detectWorkoutType(from: workoutSets)
    }
    
    private var abbreviatedType: String {
        abbreviateWorkoutType(workoutType)
    }
    
    private var typeColor: Color {
        workoutTypeColor(workoutType)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : (isToday ? .green : .white))
                
                if workout != nil && !abbreviatedType.isEmpty {
                    Text(abbreviatedType)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(typeColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else if workout != nil {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                } else {
                    Color.clear
                        .frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)  // Slightly taller to accommodate text
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green.opacity(0.3) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.green : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout Preview Card
struct WorkoutPreviewCard: View {
    let workout: Workout
    let sets: [WorkoutSet]
    let onTap: () -> Void
    
    private var workoutType: String {
        detectWorkoutType(from: sets)
    }
    
    private var setsPerMin: Double {
        let duration = workout.duration ?? 0
        guard duration > 0 else { return 0 }
        let workingSets = sets.filter { $0.setType != .warmup && ($0.dropIndex ?? 0) == 0 }
        return Double(workingSets.count) / Double(duration)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(workoutType)
                                .font(.headline)
                                .foregroundColor(workoutTypeColor)
                            
                            if let rpe = workout.rpe {
                                Text("RPE \(rpe)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(rpeColor(rpe).opacity(0.2))
                                    .foregroundColor(rpeColor(rpe))
                                    .cornerRadius(4)
                            }
                            
                            if workout.notes != nil && !workout.notes!.isEmpty {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if let gym = workout.gym, !gym.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption2)
                                Text(gym)
                                    .font(.caption)
                            }
                            .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 16) {
                    StatBadge(icon: "dumbbell.fill", value: "\(sets.count)", label: "sets")
                    StatBadge(icon: "clock", value: "\(workout.duration ?? 0)", label: "min")
                    StatBadge(icon: "speedometer", value: String(format: "%.2f", setsPerMin), label: "sets/min")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var workoutTypeColor: Color {
        switch workoutType.lowercased() {
        case "push": return .red
        case "pull": return .blue
        case "legs": return .green
        case "upper body": return .purple
        case "full body": return .orange
        default: return .white
        }
    }
    
    private func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
        }
    }
    

}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Workout List Item
struct WorkoutListItem: View {
    let workout: Workout
    let sets: [WorkoutSet]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    
    private var workoutType: String {
        detectWorkoutType(from: sets)
    }
    
    private var workingSetsCount: Int {
        sets.filter { $0.setType != .warmup && ($0.dropIndex ?? 0) == 0 }.count
    }
    
    private var setsPerMin: Double {
        let duration = workout.duration ?? 0
        guard duration > 0 else { return 0 }
        return Double(workingSetsCount) / Double(duration)
    }
    
    private var hasNote: Bool {
        if let notes = workout.notes {
            return !notes.isEmpty
        }
        return false
    }
    
    private var hasExerciseNotes: Bool {
        sets.contains { set in
            if let note = set.exerciseNote {
                return !note.isEmpty
            }
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(workout.date.formatted(.dateTime.day()))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(workout.date.formatted(.dateTime.month(.abbreviated)))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 44)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(workoutType)
                                .font(.headline)
                                .foregroundColor(workoutTypeColor)
                            
                            if let rpe = workout.rpe {
                                Text("RPE \(rpe)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(rpeColor(rpe).opacity(0.2))
                                    .foregroundColor(rpeColor(rpe))
                                    .cornerRadius(4)
                            }
                            
                            if hasNote || hasExerciseNotes {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            if let gym = workout.gym, !gym.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "mappin")
                                        .font(.caption2)
                                    Text(gym)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                            }
                            
                            HStack(spacing: 2) {
                                Image(systemName: "number")
                                    .font(.caption2)
                                Text("\(workingSetsCount) sets")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "speedometer")
                                    .font(.caption2)
                                Text(String(format: "%.2f/min", setsPerMin))
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(isExpanded ? 0 : 12)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                expandedContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("Delete Workout?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This will permanently delete this workout and all its sets. This cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareExerciseSelectionSheet(
                sets: sets,
                workout: workout,
                workoutType: workoutType
            )
        }
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(workout.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                
                if let gym = workout.gym, !gym.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                        Text(gym)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(workout.duration ?? 0) min")
                    }
                    
                    if let rpe = workout.rpe {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                            Text("RPE \(rpe)/10")
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame")
                        Text("\(workingSetsCount) sets")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                if let notes = workout.notes, !notes.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.caption)
                        Text(notes)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(groupedExercises, id: \.exerciseName) { group in
                    ExerciseSetGroupView(group: group)
                }
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Button {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                    Text("Delete Workout")
                    Spacer()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.red)
                .padding()
            }
        }
        .background(Color.gray.opacity(0.1))
    }
    
    private var groupedExercises: [ExerciseSetGroupData] {
        var groups: [ExerciseSetGroupData] = []
        var currentExerciseId: String? = nil
        
        for set in sets.sorted(by: { $0.timestamp < $1.timestamp }) {
            if set.exerciseId == currentExerciseId, let lastIndex = groups.indices.last {
                groups[lastIndex].sets.append(set)
            } else {
                groups.append(ExerciseSetGroupData(
                    exerciseId: set.exerciseId,
                    exerciseName: set.exerciseName,
                    exerciseNote: set.exerciseNote,
                    sets: [set]
                ))
                currentExerciseId = set.exerciseId
            }
        }
        
        return groups
    }
    
    private var workoutTypeColor: Color {
        switch workoutType.lowercased() {
        case "push": return .red
        case "pull": return .blue
        case "legs": return .green
        case "upper body": return .purple
        case "full body": return .orange
        default: return .white
        }
    }
    
    private func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
        }
    }
    

}

// MARK: - Exercise Set Group Data
struct ExerciseSetGroupData {
    let exerciseId: String
    let exerciseName: String
    let exerciseNote: String?
    var sets: [WorkoutSet]
}

// MARK: - Exercise Set Group View
struct ExerciseSetGroupView: View {
    let group: ExerciseSetGroupData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.exerciseName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let note = group.exerciseNote, !note.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                    Text(note)
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            ForEach(Array(group.sets.enumerated()), id: \.element.id) { _, set in
                HStack(spacing: 8) {
                    Text(formatSetLabel(set: set))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 30, alignment: .leading)
                    
                    if set.setType == .warmup {
                        Text("W")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                    
                    if set.setType == .drop || (set.dropIndex ?? 0) > 0 {                        Text("D")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.3))
                            .foregroundColor(.purple)
                            .cornerRadius(3)
                    }
                    
                    if set.setType == .superSet {
                        Text("SS")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                    
                    Text("\(Int(set.weight)) lbs × \(set.reps)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    if set.toFailure {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
                .padding(.leading, (set.dropIndex ?? 0) > 0 ? 16 : 0)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatSetLabel(set: WorkoutSet) -> String {
        let dropIndex = set.dropIndex ?? 0
        if dropIndex > 0 {
            let letterCode = 96 + dropIndex
            if let scalar = UnicodeScalar(letterCode) {
                return "\(set.setGroup)\(Character(scalar))."
            }
        }
        return "\(set.setGroup)."
    }
}

// MARK: - Workout Detail Sheet
struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let workout: Workout
    let sets: [WorkoutSet]
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    
    private var workoutType: String {
        detectWorkoutType(from: sets)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workoutType)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(workoutTypeColor)
                        
                        Text(workout.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        if let gym = workout.gym, !gym.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                Text(gym)
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(workout.duration ?? 0)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("minutes")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            if let rpe = workout.rpe {
                                VStack {
                                    Text("\(rpe)/10")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("effort")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            VStack {
                                Text("\(sets.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("sets")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 8)
                        
                        if let notes = workout.notes, !notes.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "note.text")
                                Text(notes)
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercises")
                            .font(.headline)
                        
                        ForEach(groupedExercises, id: \.exerciseName) { group in
                            ExerciseSetGroupView(group: group)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Workout")
                            Spacer()
                        }
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .alert("Delete Workout?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete this workout and all its sets.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareExerciseSelectionSheet(
                    sets: sets,
                    workout: workout,
                    workoutType: workoutType
                )
            }
        }
    }
    
    private var groupedExercises: [ExerciseSetGroupData] {
        var groups: [ExerciseSetGroupData] = []
        var currentExerciseId: String? = nil
        
        for set in sets.sorted(by: { $0.timestamp < $1.timestamp }) {
            if set.exerciseId == currentExerciseId, let lastIndex = groups.indices.last {
                groups[lastIndex].sets.append(set)
            } else {
                groups.append(ExerciseSetGroupData(
                    exerciseId: set.exerciseId,
                    exerciseName: set.exerciseName,
                    exerciseNote: set.exerciseNote,
                    sets: [set]
                ))
                currentExerciseId = set.exerciseId
            }
        }
        
        return groups
    }
    
    private var workoutTypeColor: Color {
        switch workoutType.lowercased() {
        case "push": return .red
        case "pull": return .blue
        case "legs": return .green
        case "upper body": return .purple
        case "full body": return .orange
        default: return .white
        }
    }
    
    
}

// MARK: - Share Exercise Selection Sheet
struct ShareExerciseSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let sets: [WorkoutSet]
    let workout: Workout
    let workoutType: String
    
    @State private var selectedExercises: Set<String> = []
    
    private var exerciseNames: [String] {
        var names: [String] = []
        var seen: Set<String> = []
        
        for set in sets.sorted(by: { $0.timestamp < $1.timestamp }) {
            if !seen.contains(set.exerciseId) {
                names.append(set.exerciseName)
                seen.insert(set.exerciseId)
            }
        }
        
        return names
    }
    
    private var exerciseIdMap: [String: String] {
        var map: [String: String] = [:]
        for set in sets {
            map[set.exerciseName] = set.exerciseId
        }
        return map
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        Button {
                            if selectedExercises.count == exerciseNames.count {
                                selectedExercises.removeAll()
                            } else {
                                selectedExercises = Set(exerciseNames)
                            }
                        } label: {
                            HStack {
                                Text(selectedExercises.count == exerciseNames.count ? "Deselect All" : "Select All")
                                Spacer()
                                if selectedExercises.count == exerciseNames.count {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    
                    Section("Exercises") {
                        ForEach(exerciseNames, id: \.self) { name in
                            Button {
                                if selectedExercises.contains(name) {
                                    selectedExercises.remove(name)
                                } else {
                                    selectedExercises.insert(name)
                                }
                            } label: {
                                HStack {
                                    Text(name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedExercises.contains(name) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Button {
                    shareSelectedExercises()
                } label: {
                    let count = selectedExercises.count
                    Text("Share \(count) Exercise\(count == 1 ? "" : "s")")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedExercises.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(selectedExercises.isEmpty)
                .padding()
            }
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedExercises = Set(exerciseNames)
            }
        }
    }
    
    private func shareSelectedExercises() {
        let shareText = formatWorkoutForShare()
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
    
    private func formatWorkoutForShare() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        
        var text = "1 workout from AMRAP\n"
        text += "AMRAP Workout Log\n"
        text += "Exported: \(Date().formatted(.dateTime.month().day().year()))\n"
        text += "═══════════════════════════════════════\n\n"
        
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "🏋️ \(workoutType)\n"
        text += "📅 \(dateFormatter.string(from: workout.date))\n"
        
        if let gym = workout.gym, !gym.isEmpty {
            text += "📍 \(gym)\n"
        }
        
        let duration = workout.duration ?? 0
        if duration > 0 {
            text += "⏱️ \(duration) minutes\n"
        }
        
        if let rpe = workout.rpe {
            text += "💪 Effort: \(rpe)/10\n"
        }
        
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        
        if let notes = workout.notes, !notes.isEmpty {
            text += "📝 \(notes)\n\n"
        }
        
        let selectedIds = Set(selectedExercises.compactMap { exerciseIdMap[$0] })
        let filteredSets = sets.filter { selectedIds.contains($0.exerciseId) }
        let groupedSets = groupSetsByExercise(filteredSets)
        
        for group in groupedSets {
            text += "💪 \(group.exerciseName)\n"
            
            if let note = group.exerciseNote, !note.isEmpty {
                text += "   📝 \(note)\n"
            }
            
            for setInfo in group.sets {
                let setLabel = formatSetLabel(setInfo: setInfo)
                let failureEmoji = setInfo.toFailure ? " 🔥" : ""
                let dropIndicator = setInfo.isDropPortion ? " ↓" : ""
                let weightInt = Int(setInfo.weight)
                
                text += "   \(setLabel). \(weightInt)lbs × \(setInfo.reps)\(failureEmoji)\(dropIndicator)\n"
            }
            
            text += "\n"
        }
        
        let workingSets = filteredSets.filter { $0.setType != .warmup && ($0.dropIndex ?? 0) == 0 }
        let workingSetCount = workingSets.count
        let setsPerMin = duration > 0 ? Double(workingSetCount) / Double(duration) : 0
        
        text += "📊 Summary: \(workingSetCount) working sets • \(String(format: "%.2f", setsPerMin)) sets/min\n\n"
        text += "═══════════════════════════════════════\n"
        text += "Exported from AMRAP - Workout Tracker"
        
        return text
    }
    
    struct SetInfo {
        let weight: Double
        let reps: Int
        let toFailure: Bool
        let setGroup: Int
        let dropIndex: Int
        let isDropPortion: Bool
    }
    
    struct ExerciseGroup {
        let exerciseName: String
        let exerciseNote: String?
        var sets: [SetInfo]
    }
    
    private func groupSetsByExercise(_ sets: [WorkoutSet]) -> [ExerciseGroup] {
        var groups: [ExerciseGroup] = []
        var currentExerciseId: String? = nil
        
        for set in sets.sorted(by: { $0.timestamp < $1.timestamp }) {
            let dropIdx = set.dropIndex ?? 0
            let setInfo = SetInfo(
                weight: set.weight,
                reps: set.reps,
                toFailure: set.toFailure,
                setGroup: set.setGroup,
                dropIndex: dropIdx,
                isDropPortion: dropIdx > 0
            )
            
            if set.exerciseId == currentExerciseId, let lastIndex = groups.indices.last {
                groups[lastIndex].sets.append(setInfo)
            } else {
                groups.append(ExerciseGroup(
                    exerciseName: set.exerciseName,
                    exerciseNote: set.exerciseNote,
                    sets: [setInfo]
                ))
                currentExerciseId = set.exerciseId
            }
        }
        
        return groups
    }
    
    private func formatSetLabel(setInfo: SetInfo) -> String {
        if setInfo.isDropPortion {
            let letterCode = 96 + setInfo.dropIndex
            if let scalar = UnicodeScalar(letterCode) {
                return "\(setInfo.setGroup)\(Character(scalar))"
            }
        }
        return "\(setInfo.setGroup)"
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Workout.self, WorkoutSet.self], inMemory: true)
}
