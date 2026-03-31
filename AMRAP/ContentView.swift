import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    // Access the shared timer manager
    private var timerManager: TimerManager { TimerManager.shared }
    
    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                WorkoutView()
                    .tabItem {
                        Label("Workout", systemImage: "dumbbell.fill")
                    }
                    .tag(0)
                
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "calendar")
                    }
                    .tag(1)
                
                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar.fill")
                    }
                    .tag(2)
                
                TemplatesView()
                    .tabItem {
                        Label("Templates", systemImage: "list.clipboard")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .safeAreaInset(edge: .top) {
                TimerBannerView(selectedTab: $selectedTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartRestTimer"))) { notification in
            if let seconds = notification.object as? Int {
                timerManager.startTimer(seconds: seconds)
            } else {
                timerManager.startTimer()
            }
        }
    }
}

#Preview {
    ContentView()
}
