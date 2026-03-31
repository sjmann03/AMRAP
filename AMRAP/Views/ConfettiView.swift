import SwiftUI

struct ConfettiView: View {
    @Binding var isShowing: Bool
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    
    var body: some View {
        if isShowing {
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<100, id: \.self) { index in
                        ConfettiPiece(
                            color: colors[index % colors.count],
                            screenWidth: geometry.size.width,
                            screenHeight: geometry.size.height
                        )
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    
    @State private var xPosition: CGFloat = 0
    @State private var yPosition: CGFloat = -20
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    private let size: CGFloat = CGFloat.random(in: 8...15)
    private let animationDuration: Double = Double.random(in: 2.0...3.5)
    private let delay: Double = Double.random(in: 0...0.5)
    private let horizontalDrift: CGFloat = CGFloat.random(in: -100...100)
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size * CGFloat.random(in: 0.5...1.5))
            .position(x: xPosition, y: yPosition)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                xPosition = CGFloat.random(in: 0...screenWidth)
                
                withAnimation(
                    .easeOut(duration: animationDuration)
                    .delay(delay)
                ) {
                    yPosition = screenHeight + 50
                    xPosition += horizontalDrift
                    rotation = Double.random(in: 360...720)
                }
                
                withAnimation(
                    .easeIn(duration: 0.5)
                    .delay(animationDuration - 0.5 + delay)
                ) {
                    opacity = 0
                }
            }
    }
}

// A simpler alternative using SF Symbols
struct SimpleConfettiView: View {
    @Binding var isShowing: Bool
    
    let emojis = ["🎉", "🎊", "⭐️", "💪", "🏆", "🔥", "💥", "✨"]
    
    var body: some View {
        if isShowing {
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<50, id: \.self) { index in
                        ConfettiEmoji(
                            emoji: emojis[index % emojis.count],
                            screenWidth: geometry.size.width,
                            screenHeight: geometry.size.height
                        )
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

struct ConfettiEmoji: View {
    let emoji: String
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    
    @State private var xPosition: CGFloat = 0
    @State private var yPosition: CGFloat = -50
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.5
    
    private let animationDuration: Double = Double.random(in: 2.0...3.5)
    private let delay: Double = Double.random(in: 0...0.8)
    private let horizontalDrift: CGFloat = CGFloat.random(in: -80...80)
    
    var body: some View {
        Text(emoji)
            .font(.system(size: CGFloat.random(in: 20...40)))
            .position(x: xPosition, y: yPosition)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                xPosition = CGFloat.random(in: 0...screenWidth)
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(delay)) {
                    scale = 1
                }
                
                withAnimation(
                    .easeOut(duration: animationDuration)
                    .delay(delay)
                ) {
                    yPosition = screenHeight + 50
                    xPosition += horizontalDrift
                    rotation = Double.random(in: -180...180)
                }
                
                withAnimation(
                    .easeIn(duration: 0.5)
                    .delay(animationDuration - 0.3 + delay)
                ) {
                    opacity = 0
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SimpleConfettiView(isShowing: .constant(true))
    }
}
