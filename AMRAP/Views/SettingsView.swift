//
//  SettingsView.swift
//  AMRAP
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    @Query private var workouts: [Workout]
    @Query private var workoutSets: [WorkoutSet]
    @Query private var templates: [WorkoutTemplate]
    @Query private var gyms: [GymLocation]
    @Query private var appSettingsArray: [AppSettings]
    
    @State private var showClearDataAlert = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showImportConfirmation = false
    @State private var importData: ParsedImportData?
    @State private var importURL: URL?
    @State private var newGymName = ""
    @State private var storageUsed: String = "Calculating..."
    @State private var importError: String?
    @State private var showImportError = false
    @State private var showImportSuccess = false
    @State private var importSuccessMessage = ""
    
    @State private var minRepsText: String = ""
    @State private var maxRepsText: String = ""
    
    @FocusState private var isGymFieldFocused: Bool
    @FocusState private var isMinRepsFocused: Bool
    @FocusState private var isMaxRepsFocused: Bool
    
    private var settings: AppSettings {
        if let existing = appSettingsArray.first {
            return existing
        }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        return newSettings
    }
    
    var body: some View {
        NavigationStack {
            List {
                workoutDefaultsSection
                repRangeSection
                gymLocationsSection
                appearanceSection
                timerSection
                dataManagementSection
                aboutSection
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .onAppear {
                calculateStorageUsed()
                ensureSettingsExist()
                minRepsText = "\(settings.defaultRepRangeMin)"
                maxRepsText = "\(settings.defaultRepRangeMax)"
                
                // Sync TimerManager with AppSettings
                syncTimerSettings()
            }
            .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Everything", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all your workout history, templates, and settings. This cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                ExportDataSheet(workouts: workouts, sets: workoutSets, templates: templates, gyms: gyms, settings: settings)
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Data", isPresented: $showImportConfirmation) {
                Button("Replace All", role: .destructive) {
                    performImport(merge: false)
                }
                Button("Merge", role: .none) {
                    performImport(merge: true)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let data = importData {
                    Text("Found \(data.workouts.count) workouts, \(data.sets.count) sets, and \(data.templates.count) templates.\n\nReplace will delete existing data. Merge will add to existing data.")
                }
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Unknown error occurred")
            }
            .alert("Import Successful", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importSuccessMessage)
            }
        }
    }
    
    private func ensureSettingsExist() {
        if appSettingsArray.isEmpty {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
        }
    }
    
    // MARK: - Workout Defaults Section
    private var workoutDefaultsSection: some View {
        Section {
            HStack {
                Label("Default Rest Time", systemImage: "timer")
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.restTime },
                    set: { newValue in
                        settings.restTime = newValue
                        UserDefaults.standard.set(newValue, forKey: "restTime")
                        TimerManager.shared.defaultRestTime = newValue
                    }
                )) {
                    Text("30 sec").tag(30)
                    Text("45 sec").tag(45)
                    Text("60 sec").tag(60)
                    Text("90 sec").tag(90)
                    Text("120 sec").tag(120)
                    Text("150 sec").tag(150)
                    Text("180 sec").tag(180)
                    Text("240 sec").tag(240)
                    Text("300 sec").tag(300)
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                Label("Default Sets", systemImage: "number.square")
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.defaultSets },
                    set: { settings.defaultSets = $0 }
                )) {
                    ForEach(1...10, id: \.self) { num in
                        Text("\(num) sets").tag(num)
                    }
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                Label("Weight Unit", systemImage: "scalemass")
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.weightUnit },
                    set: { settings.weightUnit = $0 }
                )) {
                    Text("Pounds (lbs)").tag("lbs")
                    Text("Kilograms (kg)").tag("kg")
                }
                .pickerStyle(.menu)
            }
        } header: {
            Label("Workout Defaults", systemImage: "dumbbell.fill")
        }
    }
    
    // MARK: - Rep Range Section
    private var repRangeSection: some View {
        Section {
            HStack {
                Text("Min Reps")
                Spacer()
                TextField("8", text: $minRepsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .focused($isMinRepsFocused)
                    .onSubmit { saveMinReps() }
                    .onChange(of: isMinRepsFocused) { _, focused in
                        if !focused { saveMinReps() }
                    }
            }
            
            HStack {
                Text("Max Reps")
                Spacer()
                TextField("12", text: $maxRepsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .focused($isMaxRepsFocused)
                    .onSubmit { saveMaxReps() }
                    .onChange(of: isMaxRepsFocused) { _, focused in
                        if !focused { saveMaxReps() }
                    }
            }
        } header: {
            Label("Default Rep Range", systemImage: "repeat")
        } footer: {
            Text("Target rep range for new exercises")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isMinRepsFocused = false
                    isMaxRepsFocused = false
                    isGymFieldFocused = false
                }
            }
        }
    }
    
    private func syncTimerSettings() {
        // Sync from AppSettings to UserDefaults and TimerManager
        UserDefaults.standard.set(settings.restTime, forKey: "restTime")
        UserDefaults.standard.set(settings.autoStartTimer, forKey: "autoStartTimer")
        UserDefaults.standard.set(settings.vibrateOnTimer, forKey: "vibrateOnTimer")
        UserDefaults.standard.set(settings.soundOnTimer, forKey: "soundOnTimer")
        UserDefaults.standard.set(settings.showConfetti, forKey: "showConfetti")
        
        TimerManager.shared.defaultRestTime = settings.restTime
        TimerManager.shared.autoStartTimer = settings.autoStartTimer
        TimerManager.shared.vibrateOnComplete = settings.vibrateOnTimer
        TimerManager.shared.soundOnComplete = settings.soundOnTimer
    }
    
    private func saveMinReps() {
        if let value = Int(minRepsText), value > 0 {
            settings.defaultRepRangeMin = value
        } else {
            minRepsText = "\(settings.defaultRepRangeMin)"
        }
    }
    
    private func saveMaxReps() {
        if let value = Int(maxRepsText), value > 0 {
            settings.defaultRepRangeMax = value
        } else {
            maxRepsText = "\(settings.defaultRepRangeMax)"
        }
    }
    
    // MARK: - Gym Locations Section
    private var gymLocationsSection: some View {
        Section {
            if let defaultGym = gyms.first(where: { $0.isDefault }) {
                HStack {
                    Label("Default", systemImage: "star.fill")
                        .foregroundColor(.yellow)
                    Spacer()
                    Text(defaultGym.name)
                        .foregroundColor(.secondary)
                }
            }
            
            ForEach(gyms) { gym in
                HStack {
                    Text(gym.name)
                    Spacer()
                    if gym.isDefault {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    
                    if !gym.isDefault {
                        Button {
                            setDefaultGym(gym)
                        } label: {
                            Image(systemName: "star")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(gyms[index])
                }
            }
            
            HStack {
                TextField("Add new gym...", text: $newGymName)
                    .focused($isGymFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { addNewGym() }
                
                Button {
                    addNewGym()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(newGymName.isEmpty ? .gray : themeManager.accentColor)
                }
                .disabled(newGymName.isEmpty)
            }
            
            Toggle(isOn: Binding(
                get: { settings.askGymOnSave },
                set: { settings.askGymOnSave = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Gym Location")
                    Text("Prompt when saving workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
        } header: {
            Label("Gym Locations", systemImage: "mappin.circle.fill")
        }
    }
    
    private func addNewGym() {
        let trimmed = newGymName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newGym = GymLocation(name: trimmed, isDefault: gyms.isEmpty)
        modelContext.insert(newGym)
        newGymName = ""
        isGymFieldFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func setDefaultGym(_ gym: GymLocation) {
        for g in gyms { g.isDefault = false }
        gym.isDefault = true
    }
    
    // MARK: - Appearance Section (NO compact mode)
    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme Color")
                    .font(.subheadline)
                
                HStack(spacing: 12) {
                    ForEach(["green", "blue", "purple", "orange", "red", "pink"], id: \.self) { color in
                        Circle()
                            .fill(colorForName(color))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: themeManager.themeColorName == color ? 3 : 0)
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .opacity(themeManager.themeColorName == color ? 1 : 0)
                            )
                            .onTapGesture {
                                themeManager.themeColorName = color
                                settings.themeColor = color
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    }
                }
            }
            .padding(.vertical, 4)
            
            Toggle(isOn: Binding(
                get: { settings.showConfetti },
                set: { newValue in
                    settings.showConfetti = newValue
                    UserDefaults.standard.set(newValue, forKey: "showConfetti")
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Confetti on PR")
                    Text("Celebrate when you hit a new PR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
        } header: {
            Label("Appearance", systemImage: "paintbrush.fill")
        }
    }
    
    // MARK: - Timer Section
    private var timerSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.autoStartTimer },
                set: { newValue in
                    settings.autoStartTimer = newValue
                    UserDefaults.standard.set(newValue, forKey: "autoStartTimer")
                    TimerManager.shared.autoStartTimer = newValue
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-start Timer")
                    Text("Start rest timer after logging set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
            
            Toggle(isOn: Binding(
                get: { settings.vibrateOnTimer },
                set: { newValue in
                    settings.vibrateOnTimer = newValue
                    UserDefaults.standard.set(newValue, forKey: "vibrateOnTimer")
                    TimerManager.shared.vibrateOnComplete = newValue
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vibrate on Timer End")
                    Text("Vibrate when rest timer completes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
            
            Toggle(isOn: Binding(
                get: { settings.soundOnTimer },
                set: { newValue in
                    settings.soundOnTimer = newValue
                    UserDefaults.standard.set(newValue, forKey: "soundOnTimer")
                    TimerManager.shared.soundOnComplete = newValue
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sound on Timer End")
                    Text("Play sound when rest timer completes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
        } header: {
            Label("Timer & Notifications", systemImage: "bell.fill")
        }
    }
    
    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        Section {
            Button {
                showExportSheet = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Data")
                            .foregroundColor(.primary)
                        Text("Download all your workout data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
            }
            
            Button {
                showImportPicker = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Data")
                            .foregroundColor(.primary)
                        Text("Restore from backup file")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(themeManager.accentColor)
                }
            }
            
            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear All Data")
                        Text("Delete all workouts and settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "trash")
                }
            }
        } header: {
            Label("Data Management", systemImage: "externaldrive.fill")
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("💪")
                    .font(.system(size: 50))
                Text("AMRAP")
                    .font(.title.bold())
                    .foregroundColor(themeManager.accentColor)
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Track your gains, crush your goals")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: themeManager.gradientColors, startPoint: .leading, endPoint: .trailing))
                            .frame(width: min(geo.size.width * storagePercentage, geo.size.width), height: 8)
                    }
                }
                .frame(height: 8)
                
                Text(storageUsed)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 4)
            
            HStack {
                Text("Built with")
                Spacer()
                Text("SwiftUI + SwiftData")
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("About", systemImage: "info.circle.fill")
        }
    }
    
    // MARK: - Helper Properties & Functions
    
    private var storagePercentage: CGFloat {
        let totalItems = workouts.count + workoutSets.count + templates.count
        return min(CGFloat(totalItems) / 1000.0, 1.0)
    }
    
    private func colorForName(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        default: return .green
        }
    }
    
    private func calculateStorageUsed() {
        let workoutCount = workouts.count
        let setCount = workoutSets.count
        let templateCount = templates.count
        
        let estimatedBytes = (setCount * 500) + (workoutCount * 200) + (templateCount * 1000)
        
        if estimatedBytes < 1024 {
            storageUsed = "\(estimatedBytes) bytes"
        } else if estimatedBytes < 1024 * 1024 {
            storageUsed = String(format: "%.1f KB", Double(estimatedBytes) / 1024.0)
        } else {
            storageUsed = String(format: "%.2f MB", Double(estimatedBytes) / (1024.0 * 1024.0))
        }
    }
    
    private func clearAllData() {
        for workout in workouts { modelContext.delete(workout) }
        for set in workoutSets { modelContext.delete(set) }
        for template in templates { modelContext.delete(template) }
        for gym in gyms { modelContext.delete(gym) }
        
        settings.restTime = 90
        settings.defaultSets = 3
        settings.weightUnit = "lbs"
        settings.askGymOnSave = false
        settings.themeColor = "green"
        settings.showConfetti = true
        settings.autoStartTimer = true
        settings.vibrateOnTimer = true
        settings.soundOnTimer = true
        settings.defaultRepRangeMin = 8
        settings.defaultRepRangeMax = 12
        
        themeManager.themeColorName = "green"
        
        minRepsText = "8"
        maxRepsText = "12"
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        calculateStorageUsed()
    }
    
    // MARK: - Import Functions (Smart format detection)
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importError = "No file selected"
                showImportError = true
                return
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Unable to access the selected file. Please try again."
                showImportError = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                print("📁 Read \(data.count) bytes from file")
                
                // Parse as generic JSON first to detect format
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    importError = "Invalid JSON format"
                    showImportError = true
                    return
                }
                
                // Detect format and parse accordingly
                let parsed = try parseImportData(json: json)
                
                print("✅ Parsed successfully")
                print("   - Sets: \(parsed.sets.count)")
                print("   - Workouts: \(parsed.workouts.count)")
                print("   - Templates: \(parsed.templates.count)")
                
                self.importData = parsed
                self.showImportConfirmation = true
                
            } catch {
                print("❌ Error: \(error)")
                importError = "Failed to parse file: \(error.localizedDescription)"
                showImportError = true
            }
            
        case .failure(let error):
            print("❌ File picker error: \(error)")
            importError = "File picker error: \(error.localizedDescription)"
            showImportError = true
        }
    }
    
    // MARK: - Smart JSON Parser
    private func parseImportData(json: [String: Any]) throws -> ParsedImportData {
        var parsedSets: [ParsedSet] = []
        var parsedWorkouts: [ParsedWorkout] = []
        var parsedTemplates: [ParsedTemplate] = []
        var parsedSettings: ParsedSettings?
        var parsedGyms: [String] = []
        
        // Detect format: iOS app exports have UUID strings, PWA has integer timestamps
        let isIOSFormat: Bool
        if let sets = json["sets"] as? [[String: Any]], let firstSet = sets.first {
            if let idValue = firstSet["id"] {
                // iOS uses UUID strings, PWA uses integers
                isIOSFormat = idValue is String
            } else {
                isIOSFormat = false
            }
        } else {
            isIOSFormat = json["appVersion"] != nil && (json["appVersion"] as? String)?.contains("iOS") == true
        }
        
        print("📱 Detected format: \(isIOSFormat ? "iOS App" : "PWA")")
        
        // Parse sets
        if let sets = json["sets"] as? [[String: Any]] {
            for setJson in sets {
                if let parsed = parseSet(json: setJson, isIOSFormat: isIOSFormat) {
                    parsedSets.append(parsed)
                }
            }
        }
        
        // Parse workouts
        if let workouts = json["workouts"] as? [[String: Any]] {
            for workoutJson in workouts {
                if let parsed = parseWorkout(json: workoutJson, isIOSFormat: isIOSFormat) {
                    parsedWorkouts.append(parsed)
                }
            }
        }
        
        // Parse templates
        if let templates = json["templates"] as? [[String: Any]] {
            for templateJson in templates {
                if let parsed = parseTemplate(json: templateJson) {
                    parsedTemplates.append(parsed)
                }
            }
        }
        
        // Parse settings
        if let settingsJson = json["settings"] as? [String: Any] {
            parsedSettings = parseSettings(json: settingsJson)
            
            // Extract gyms from settings
            if let savedGyms = settingsJson["savedGyms"] as? [String] {
                parsedGyms.append(contentsOf: savedGyms)
            }
            if let defaultGym = settingsJson["defaultGym"] as? String, !defaultGym.isEmpty {
                if !parsedGyms.contains(defaultGym) {
                    parsedGyms.insert(defaultGym, at: 0)
                }
            }
        }
        
        return ParsedImportData(
            sets: parsedSets,
            workouts: parsedWorkouts,
            templates: parsedTemplates,
            settings: parsedSettings,
            gyms: parsedGyms
        )
    }
    
    // MARK: - Individual Parsers (Flexible type handling)
    
    private func parseSet(json: [String: Any], isIOSFormat: Bool) -> ParsedSet? {
        // Required fields - try multiple possible keys
        let exerciseId = json["exerciseId"] as? String ?? ""
        let exerciseName = json["exerciseName"] as? String ?? json["exercise"] as? String ?? "Unknown"
        let primaryMuscle = json["primaryMuscle"] as? String ?? "other"
        let equipment = json["equipment"] as? String ?? "other"
        let category = json["category"] as? String ?? "compound"
        let split = json["split"] as? String ?? "other"
        
        // Weight and reps - could be Int or Double
        let weight: Double
        if let w = json["weight"] as? Double {
            weight = w
        } else if let w = json["weight"] as? Int {
            weight = Double(w)
        } else {
            weight = 0
        }
        
        let reps: Int
        if let r = json["reps"] as? Int {
            reps = r
        } else if let r = json["reps"] as? Double {
            reps = Int(r)
        } else {
            reps = 0
        }
        
        // Optional fields with flexible parsing
        let muscleGroups = json["muscleGroups"] as? [String] ?? [primaryMuscle]
        let setType = json["setType"] as? String ?? "standard"
        let toFailure = json["toFailure"] as? Bool ?? false
        let setGroup = flexibleInt(json["setGroup"]) ?? 0
        let dropIndex = flexibleInt(json["dropIndex"]) ?? 0
        let superSetOrder = flexibleInt(json["superSetOrder"])
        let workoutId = json["workoutId"] as? String ?? ""
        let exerciseNote = json["exerciseNote"] as? String
        
        // SuperSetId - could be Int, String, or nil
        let superSetId: String?
        if let sid = json["superSetId"] as? Int {
            superSetId = String(sid)
        } else if let sid = json["superSetId"] as? String {
            superSetId = sid
        } else {
            superSetId = nil
        }
        
        // Timestamp - could be Date, Int, or String
        let timestamp: Date
        if let t = json["timestamp"] as? Double {
            timestamp = Date(timeIntervalSince1970: t / 1000)
        } else if let t = json["timestamp"] as? Int {
            timestamp = Date(timeIntervalSince1970: Double(t) / 1000)
        } else if let t = json["timestamp"] as? String {
            timestamp = parseFlexibleDate(t) ?? Date()
        } else {
            timestamp = Date()
        }
        let gym = json["gym"] as? String

        return ParsedSet(
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            primaryMuscle: primaryMuscle,
            muscleGroups: muscleGroups,
            equipment: equipment,
            category: category,
            split: split,
            weight: weight,
            reps: reps,
            setType: setType,
            toFailure: toFailure,
            setGroup: setGroup,
            dropIndex: dropIndex,
            superSetId: superSetId,
            superSetOrder: superSetOrder,
            timestamp: timestamp,
            workoutId: workoutId,
            exerciseNote: exerciseNote,
            gym: gym
        )
    }
    
    private func parseWorkout(json: [String: Any], isIOSFormat: Bool) -> ParsedWorkout? {
        let id = json["id"] as? String ?? Foundation.UUID().uuidString
        
        // Date - could be Date, String, or timestamp
        let date: Date
        if let d = json["date"] as? String {
            date = parseFlexibleDate(d) ?? Date()
        } else if let d = json["date"] as? Double {
            date = Date(timeIntervalSince1970: d / 1000)
        } else if let d = json["date"] as? Int {
            date = Date(timeIntervalSince1970: Double(d) / 1000)
        } else {
            date = Date()
        }
        
        // StartedAt
        let startedAt: Date
        if let s = json["startedAt"] as? String {
            startedAt = parseFlexibleDate(s) ?? date
        } else if let s = json["startedAt"] as? Double {
            startedAt = Date(timeIntervalSince1970: s / 1000)
        } else if let s = json["startedAt"] as? Int {
            startedAt = Date(timeIntervalSince1970: Double(s) / 1000)
        } else {
            startedAt = date
        }
        
        // EndedAt
        let endedAt: Date?
        if let e = json["endedAt"] as? String {
            endedAt = parseFlexibleDate(e)
        } else if let e = json["endedAt"] as? Double {
            endedAt = Date(timeIntervalSince1970: e / 1000)
        } else if let e = json["endedAt"] as? Int {
            endedAt = Date(timeIntervalSince1970: Double(e) / 1000)
        } else {
            endedAt = nil
        }
        
        let gym = json["gym"] as? String
        let duration = flexibleInt(json["duration"])
        let exerciseNames = json["exerciseNames"] as? [String] ?? json["exercises"] as? [String] ?? []
        let totalSets = flexibleInt(json["totalSets"]) ?? 0
        let totalVolume = json["totalVolume"] as? Double ?? 0
        let notes = json["notes"] as? String ?? json["note"] as? String
        let rpe = flexibleInt(json["rpe"])
        let density = json["density"] as? Double
        let workoutType = json["workoutType"] as? String ?? json["type"] as? String
        
        return ParsedWorkout(
            id: id,
            date: date,
            startedAt: startedAt,
            endedAt: endedAt,
            gym: gym,
            duration: duration,
            exerciseNames: exerciseNames,
            totalSets: totalSets,
            totalVolume: totalVolume,
            notes: notes,
            rpe: rpe,
            density: density,
            workoutType: workoutType
        )
    }
    
    private func parseTemplate(json: [String: Any]) -> ParsedTemplate? {
        let id = json["id"] as? String ?? Foundation.UUID().uuidString
        let name = json["name"] as? String ?? "Imported Template"
        
        var exercises: [ParsedTemplateExercise] = []
        if let exercisesJson = json["exercises"] as? [[String: Any]] {
            for (index, exJson) in exercisesJson.enumerated() {
                let exerciseId = exJson["exerciseId"] as? String ?? ""
                let exerciseName = exJson["exerciseName"] as? String ?? exJson["name"] as? String ?? "Unknown"
                let equipment = exJson["equipment"] as? String ?? "other"
                let primaryMuscle = exJson["primaryMuscle"] as? String ?? "other"
                let targetSets = flexibleInt(exJson["targetSets"]) ?? flexibleInt(exJson["sets"]) ?? 3
                let setType = exJson["setType"] as? String ?? "standard"
                let order = flexibleInt(exJson["order"]) ?? index
                let warmupSets = flexibleInt(exJson["warmupSets"]) ?? 0
                let supersetExerciseId = exJson["supersetExerciseId"] as? String
                let supersetExerciseName = exJson["supersetExerciseName"] as? String
                let supersetPrimaryMuscle = exJson["supersetPrimaryMuscle"] as? String
                let supersetEquipment = exJson["supersetEquipment"] as? String
                
                exercises.append(ParsedTemplateExercise(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    primaryMuscle: primaryMuscle,
                    targetSets: targetSets,
                    setType: setType,
                    order: order,
                    warmupSets: warmupSets,
                    supersetExerciseId: supersetExerciseId,
                    supersetExerciseName: supersetExerciseName,
                    supersetPrimaryMuscle: supersetPrimaryMuscle,
                    supersetEquipment: supersetEquipment
                ))
            }
        }
        
        // CreatedAt
        let createdAt: Date
        if let c = json["createdAt"] as? String {
            createdAt = parseFlexibleDate(c) ?? Date()
        } else if let c = json["createdAt"] as? Double {
            createdAt = Date(timeIntervalSince1970: c / 1000)
        } else if let c = json["createdAt"] as? Int {
            createdAt = Date(timeIntervalSince1970: Double(c) / 1000)
        } else {
            createdAt = Date()
        }
        
        // LastUsed
        let lastUsed: Date?
        if let l = json["lastUsed"] as? String {
            lastUsed = parseFlexibleDate(l)
        } else if let l = json["lastUsed"] as? Double {
            lastUsed = Date(timeIntervalSince1970: l / 1000)
        } else if let l = json["lastUsed"] as? Int {
            lastUsed = Date(timeIntervalSince1970: Double(l) / 1000)
        } else {
            lastUsed = nil
        }
        
        return ParsedTemplate(
            id: id,
            name: name,
            exercises: exercises,
            createdAt: createdAt,
            lastUsed: lastUsed
        )
    }
    
    private func parseSettings(json: [String: Any]) -> ParsedSettings {
        return ParsedSettings(
            restTime: flexibleInt(json["restTime"]),
            defaultSets: flexibleInt(json["defaultSets"]),
            weightUnit: json["weightUnit"] as? String,
            themeColor: json["themeColor"] as? String,
            showConfetti: json["showConfetti"] as? Bool,
            autoStartTimer: json["autoStartTimer"] as? Bool,
            vibrateOnTimer: json["vibrateOnTimer"] as? Bool,
            soundOnTimer: json["soundOnTimer"] as? Bool,
            defaultGym: json["defaultGym"] as? String,
            savedGyms: json["savedGyms"] as? [String]
        )
    }
    
    // MARK: - Helper Functions
    
    private func flexibleInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String { return Int(s) }
        return nil
    }
    
    private func parseFlexibleDate(_ string: String) -> Date? {
        // Try ISO8601 with fractional seconds
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: string) {
            return date
        }
        
        // Try ISO8601 without fractional seconds
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: string) {
            return date
        }
        
        // Try simple date format
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd"
        if let date = simple.date(from: string) {
            return date
        }
        
        // Try as timestamp (milliseconds)
        if let timestamp = Double(string) {
            return Date(timeIntervalSince1970: timestamp / 1000)
        }
        
        return nil
    }
    
    // MARK: - Parsed Data Structures (Internal use only)
    
    struct ParsedImportData {
        let sets: [ParsedSet]
        let workouts: [ParsedWorkout]
        let templates: [ParsedTemplate]
        let settings: ParsedSettings?
        let gyms: [String]
    }
    
    struct ParsedSet {
        let exerciseId: String
        let exerciseName: String
        let primaryMuscle: String
        let muscleGroups: [String]
        let equipment: String
        let category: String
        let split: String
        let weight: Double
        let reps: Int
        let setType: String
        let toFailure: Bool
        let setGroup: Int
        let dropIndex: Int
        let superSetId: String?
        let superSetOrder: Int?
        let timestamp: Date
        let workoutId: String
        let exerciseNote: String?
        let gym: String?  // <-- ADD THIS
    }
    
    struct ParsedWorkout {
        let id: String
        let date: Date
        let startedAt: Date
        let endedAt: Date?
        let gym: String?
        let duration: Int?
        let exerciseNames: [String]
        let totalSets: Int
        let totalVolume: Double
        let notes: String?
        let rpe: Int?
        let density: Double?
        let workoutType: String?
    }
    
    struct ParsedTemplate {
        let id: String
        let name: String
        let exercises: [ParsedTemplateExercise]
        let createdAt: Date
        let lastUsed: Date?
    }
    
    struct ParsedTemplateExercise {
        let exerciseId: String
        let exerciseName: String
        let equipment: String
        let primaryMuscle: String
        let targetSets: Int
        let setType: String
        let order: Int
        let warmupSets: Int
        let supersetExerciseId: String?
        let supersetExerciseName: String?
        let supersetPrimaryMuscle: String?
        let supersetEquipment: String?
    }
    
    struct ParsedSettings {
        let restTime: Int?
        let defaultSets: Int?
        let weightUnit: String?
        let themeColor: String?
        let showConfetti: Bool?
        let autoStartTimer: Bool?
        let vibrateOnTimer: Bool?
        let soundOnTimer: Bool?
        let defaultGym: String?
        let savedGyms: [String]?
    }
    
    // MARK: - Perform Import (Updated to use ParsedImportData)
    
   private func performImport(merge: Bool) {
        guard let data = importData else { return }
        
        var importedWorkouts = 0
        var importedSets = 0
        var importedTemplates = 0
        
        if !merge {
            for workout in workouts { modelContext.delete(workout) }
            for set in workoutSets { modelContext.delete(set) }
            for template in templates { modelContext.delete(template) }
        }
        
        let existingWorkoutIds = Set(workouts.map { $0.id })
        let existingTemplateIds = Set(templates.map { $0.id })
        
        // Build a lookup dictionary for workout gym locations
        var workoutGymLookup: [String: String] = [:]
        for workoutData in data.workouts {
            if let gym = workoutData.gym {
                workoutGymLookup[workoutData.id] = gym
            }
        }
        
        // Import workouts
        for workoutData in data.workouts {
            if merge && existingWorkoutIds.contains(workoutData.id) { continue }
            
            let workout = Workout(
                id: workoutData.id,
                date: workoutData.date,
                startedAt: workoutData.startedAt,
                endedAt: workoutData.endedAt,
                gym: workoutData.gym,
                duration: workoutData.duration,
                exerciseNames: workoutData.exerciseNames,
                totalSets: workoutData.totalSets,
                totalVolume: workoutData.totalVolume,
                notes: workoutData.notes,
                rpe: workoutData.rpe,
                density: workoutData.density,
                workoutType: workoutData.workoutType
            )
            modelContext.insert(workout)
            importedWorkouts += 1
        }
        
        // Import sets - look up gym from workout if not on set
        for setData in data.sets {
            // Use gym from set if available, otherwise look up from workout
            let gym = setData.gym ?? workoutGymLookup[setData.workoutId]
            
            let workoutSet = WorkoutSet(
                exerciseId: setData.exerciseId,
                exerciseName: setData.exerciseName,
                primaryMuscle: setData.primaryMuscle,
                muscleGroups: setData.muscleGroups,
                equipment: setData.equipment,
                category: setData.category,
                split: setData.split,
                weight: setData.weight,
                reps: setData.reps,
                setType: SetType(rawValue: setData.setType) ?? .standard,
                toFailure: setData.toFailure,
                setGroup: setData.setGroup,
                dropIndex: setData.dropIndex,
                superSetId: setData.superSetId,
                superSetOrder: setData.superSetOrder,
                workoutId: setData.workoutId,
                gym: gym,  // <-- NOW USES WORKOUT GYM AS FALLBACK
                exerciseNote: setData.exerciseNote
            )
            workoutSet.timestamp = setData.timestamp
            
            modelContext.insert(workoutSet)
            importedSets += 1
        }
        // Import settings
        if let importedSettings = data.settings {
            if let v = importedSettings.restTime { settings.restTime = v }
            if let v = importedSettings.defaultSets { settings.defaultSets = v }
            if let v = importedSettings.weightUnit { settings.weightUnit = v }
            if let v = importedSettings.themeColor {
                settings.themeColor = v
                themeManager.themeColorName = v
            }
            if let v = importedSettings.showConfetti { settings.showConfetti = v }
            if let v = importedSettings.autoStartTimer { settings.autoStartTimer = v }
            if let v = importedSettings.vibrateOnTimer { settings.vibrateOnTimer = v }
            if let v = importedSettings.soundOnTimer { settings.soundOnTimer = v }
        }
        
        // Import gym locations
        for gymName in data.gyms {
            if !gyms.contains(where: { $0.name == gymName }) {
                let isDefault = gyms.isEmpty && gymName == data.gyms.first
                let newGym = GymLocation(name: gymName, isDefault: isDefault)
                modelContext.insert(newGym)
            }
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        calculateStorageUsed()
        
        importSuccessMessage = "Successfully imported \(importedWorkouts) workouts, \(importedSets) sets, and \(importedTemplates) templates!"
        showImportSuccess = true
        
        importData = nil
        importURL = nil
    }
    
    // MARK: - Export Data Sheet
    struct ExportDataSheet: View {
        @Environment(\.dismiss) private var dismiss
        @StateObject private var themeManager = ThemeManager.shared
        
        let workouts: [Workout]
        let sets: [WorkoutSet]
        let templates: [WorkoutTemplate]
        let gyms: [GymLocation]
        let settings: AppSettings
        
        @State private var isExporting = false
        @State private var exportURL: URL?
        @State private var showShareSheet = false
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 24) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Export Your Data")
                        .font(.title2.bold())
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ExportStatRow(icon: "figure.strengthtraining.traditional", label: "Workouts", count: workouts.count)
                        ExportStatRow(icon: "number.square", label: "Sets", count: sets.count)
                        ExportStatRow(icon: "list.clipboard", label: "Templates", count: templates.count)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    Text("Your data will be exported as a JSON file that can be imported into another device or used as a backup.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("Export Data")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isExporting)
                }
                .padding()
                .navigationTitle("Export")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    if let url = exportURL {
                        ShareSheet(activityItems: [url])
                    }
                }
            }
        }
        
        private func exportData() {
            isExporting = true
            
            let exportSets = sets.map { set in
                ExportSet(
                    id: set.id,
                    workoutId: set.workoutId,
                    exerciseId: set.exerciseId,
                    exerciseName: set.exerciseName,
                    primaryMuscle: set.primaryMuscle,
                    muscleGroups: set.muscleGroups,
                    equipment: set.equipment,
                    category: set.category,
                    split: set.split,
                    weight: set.weight,
                    reps: set.reps,
                    setType: set.setType.rawValue,
                    toFailure: set.toFailure,
                    setGroup: set.setGroup,
                    dropIndex: set.dropIndex,
                    superSetId: set.superSetId,
                    superSetOrder: set.superSetOrder,
                    timestamp: set.timestamp,
                    gym: set.gym,
                    exerciseNote: set.exerciseNote
                )
            }
            
            let exportWorkouts = workouts.map { workout in
                ExportWorkout(
                    id: workout.id,
                    date: workout.date,
                    startedAt: workout.startedAt,
                    endedAt: workout.endedAt,
                    gym: workout.gym,
                    duration: workout.duration,
                    exerciseNames: workout.exerciseNames,
                    totalSets: workout.totalSets,
                    totalVolume: workout.totalVolume,
                    notes: workout.notes,
                    rpe: workout.rpe,
                    density: workout.density,
                    workoutType: workout.workoutType
                )
            }
            
            let exportTemplates = templates.map { template in
                ExportTemplate(
                    id: template.id,
                    name: template.name,
                    exercises: template.exercises.map { ex in
                        ExportTemplateExercise(
                            exerciseId: ex.exerciseId,
                            exerciseName: ex.exerciseName,
                            equipment: ex.equipment,
                            primaryMuscle: ex.primaryMuscle,
                            targetSets: ex.targetSets,
                            setType: ex.setType,
                            order: ex.order,
                            warmupSets: ex.warmupSets,
                            supersetExerciseId: ex.supersetExerciseId,
                            supersetExerciseName: ex.supersetExerciseName,
                            supersetPrimaryMuscle: ex.supersetPrimaryMuscle,
                            supersetEquipment: ex.supersetEquipment
                        )
                    },
                    createdAt: template.createdAt,
                    lastUsed: template.lastUsed
                )
            }
            
            let exportData = ExportDataStructure(
                sets: exportSets,
                workouts: exportWorkouts,
                templates: exportTemplates,
                settings: ExportSettings(
                    restTime: settings.restTime,
                    defaultSets: settings.defaultSets,
                    weightUnit: settings.weightUnit,
                    themeColor: settings.themeColor,
                    showConfetti: settings.showConfetti,
                    autoStartTimer: settings.autoStartTimer,
                    vibrateOnTimer: settings.vibrateOnTimer,
                    soundOnTimer: settings.soundOnTimer
                ),
                exportDate: ISO8601DateFormatter().string(from: Date()),
                appVersion: "AMRAP iOS v1.0"
            )
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(exportData)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let fileName = "amrap-backup-\(dateFormatter.string(from: Date())).json"
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)
                
                exportURL = tempURL
                showShareSheet = true
            } catch {
                print("Export error: \(error)")
            }
            
            isExporting = false
        }
    }
    
    // MARK: - Export Stat Row
    struct ExportStatRow: View {
        let icon: String
        let label: String
        let count: Int
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text(label)
                Spacer()
                Text("\(count)")
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Export Data Structures
    struct ExportDataStructure: Codable {
        let sets: [ExportSet]
        let workouts: [ExportWorkout]
        let templates: [ExportTemplate]
        let settings: ExportSettings
        let exportDate: String
        let appVersion: String
    }
    
    struct ExportSet: Codable {
        let id: UUID
        let workoutId: String
        let exerciseId: String
        let exerciseName: String
        let primaryMuscle: String
        let muscleGroups: [String]
        let equipment: String
        let category: String
        let split: String
        let weight: Double
        let reps: Int
        let setType: String
        let toFailure: Bool
        let setGroup: Int
        let dropIndex: Int
        let superSetId: String?
        let superSetOrder: Int?
        let timestamp: Date
        let gym: String?
        let exerciseNote: String?
    }
    
    struct ExportWorkout: Codable {
        let id: String
        let date: Date
        let startedAt: Date
        let endedAt: Date?
        let gym: String?
        let duration: Int?
        let exerciseNames: [String]
        let totalSets: Int
        let totalVolume: Double
        let notes: String?
        let rpe: Int?
        let density: Double?
        let workoutType: String?
    }
    
    struct ExportTemplate: Codable {
        let id: String
        let name: String
        let exercises: [ExportTemplateExercise]
        let createdAt: Date
        let lastUsed: Date?
    }
    
    struct ExportTemplateExercise: Codable {
        let exerciseId: String
        let exerciseName: String
        let equipment: String
        let primaryMuscle: String
        let targetSets: Int
        let setType: String
        let order: Int
        let warmupSets: Int
        let supersetExerciseId: String?
        let supersetExerciseName: String?
        let supersetPrimaryMuscle: String?
        let supersetEquipment: String?
    }
    
    struct ExportSettings: Codable {
        let restTime: Int
        let defaultSets: Int
        let weightUnit: String
        let themeColor: String
        let showConfetti: Bool
        let autoStartTimer: Bool
        let vibrateOnTimer: Bool
        let soundOnTimer: Bool
    }
    
    // MARK: - Share Sheet
    struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }
        
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
    
    
}
// Add to your SettingsView or create a data cleanup function
func cleanupOrphanedSets(modelContext: ModelContext, workouts: [Workout], allSets: [WorkoutSet]) {
    let validWorkoutIds = Set(workouts.map { $0.id })
    
    var deletedCount = 0
    for set in allSets {
        if !validWorkoutIds.contains(set.workoutId) {
            modelContext.delete(set)
            deletedCount += 1
        }
    }
    
    if deletedCount > 0 {
        try? modelContext.save()
        print("🧹 Cleaned up \(deletedCount) orphaned sets")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Workout.self, WorkoutSet.self, WorkoutTemplate.self, GymLocation.self, AppSettings.self], inMemory: true)
}
