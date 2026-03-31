import SwiftUI

struct TimerBannerView: View {
    @Binding var selectedTab: Int
    
    // Access the shared timer manager - using computed property for @Observable
    private var timerManager: TimerManager { TimerManager.shared }
    
    var body: some View {
        if timerManager.isRunning || timerManager.timerCompleted {
            timerContent
                .background(timerManager.timerCompleted ? Color.red : Color.green.opacity(0.95))
                .onTapGesture {
                    if timerManager.timerCompleted {
                        timerManager.timerCompleted = false
                    }
                    selectedTab = 0 // Go to workout tab
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: timerManager.isRunning)
                .animation(.easeInOut(duration: 0.3), value: timerManager.timerCompleted)
        }
    }
    
    private var timerContent: some View {
        HStack(spacing: 16) {
            // Timer Display
            HStack(spacing: 8) {
                if timerManager.timerCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Time for next set!")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .trim(from: 0, to: 1 - timerManager.progress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timerManager.progress)
                        
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    Text(timerManager.formattedTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.5), value: timerManager.remainingSeconds)
                }
            }
            
            Spacer()
            
            if !timerManager.timerCompleted {
                // Quick Actions
                HStack(spacing: 8) {
                    // Add 30 seconds
                    Button {
                        timerManager.addTime(30)
                    } label: {
                        Text("+30s")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    
                    // Skip/Stop
                    Button {
                        timerManager.skipTimer()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.caption)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
            } else {
                // Dismiss completed state
                Button {
                    timerManager.timerCompleted = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

#Preview {
    VStack {
        TimerBannerView(selectedTab: .constant(0))
        Spacer()
    }
}
