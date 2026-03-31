import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes
struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalSeconds: Int
        var endTime: Date
        
        var formattedTime: String {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        var progress: Double {
            guard totalSeconds > 0 else { return 0 }
            return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        }
    }
    
    var exerciseName: String
}

// MARK: - Live Activity Widget
struct AMRAPTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock Screen / Banner View
            LockScreenTimerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View
                DynamicIslandExpandedRegion(.center) {
                    ExpandedTimerView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("AMRAP Rest Timer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.green)
            } compactTrailing: {
                // USE SYSTEM TIMER - Updates automatically every second!
                Text(context.state.endTime, style: .timer)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(isLowTime(context.state.endTime) ? .red : .green)
                    .monospacedDigit()
                    .frame(minWidth: 45)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(.green)
            }
        }
    }
    
    private func isLowTime(_ endTime: Date) -> Bool {
        return endTime.timeIntervalSinceNow <= 10
    }
}

// MARK: - Lock Screen View
struct LockScreenTimerView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    
    private var isLowTime: Bool {
        context.state.endTime.timeIntervalSinceNow <= 10
    }
    
    private var progress: Double {
        let remaining = context.state.endTime.timeIntervalSinceNow
        let total = Double(context.state.totalSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, (total - remaining) / total))
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Timer circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 1 - progress)
                    .stroke(
                        isLowTime ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isLowTime ? .red : .green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Rest Timer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // USE SYSTEM TIMER - Updates automatically!
                Text(context.state.endTime, style: .timer)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(isLowTime ? .red : .primary)
                    .monospacedDigit()
            }
            
            Spacer()
            
            VStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("AMRAP")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Expanded Dynamic Island View
struct ExpandedTimerView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    
    private var isLowTime: Bool {
        context.state.endTime.timeIntervalSinceNow <= 10
    }
    
    private var progress: Double {
        let remaining = context.state.endTime.timeIntervalSinceNow
        let total = Double(context.state.totalSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, (total - remaining) / total))
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 1 - progress)
                    .stroke(
                        isLowTime ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .foregroundColor(isLowTime ? .red : .green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // USE SYSTEM TIMER - Updates automatically!
                Text(context.state.endTime, style: .timer)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(isLowTime ? .red : .white)
                    .monospacedDigit()
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Previews
#Preview("Expanded", as: .dynamicIsland(.expanded), using: RestTimerAttributes(exerciseName: "Rest")) {
    AMRAPTimerLiveActivity()
} contentStates: {
    RestTimerAttributes.ContentState(remainingSeconds: 90, totalSeconds: 90, endTime: Date().addingTimeInterval(90))
}

#Preview("Compact", as: .dynamicIsland(.compact), using: RestTimerAttributes(exerciseName: "Rest")) {
    AMRAPTimerLiveActivity()
} contentStates: {
    RestTimerAttributes.ContentState(remainingSeconds: 45, totalSeconds: 90, endTime: Date().addingTimeInterval(45))
}

#Preview("Lock Screen", as: .content, using: RestTimerAttributes(exerciseName: "Rest")) {
    AMRAPTimerLiveActivity()
} contentStates: {
    RestTimerAttributes.ContentState(remainingSeconds: 90, totalSeconds: 90, endTime: Date().addingTimeInterval(90))
}
