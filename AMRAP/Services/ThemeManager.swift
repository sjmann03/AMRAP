//
//  ThemeManager.swift
//  AMRAP
//

import SwiftUI
import Combine


// MARK: - Theme Manager (Use throughout the app)
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("themeColor") var themeColorName: String = "green" {
        didSet { objectWillChange.send() }
    }
    
    var accentColor: Color {
        switch themeColorName {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        default: return .green
        }
    }
    
    var gradientColors: [Color] {
        switch themeColorName {
        case "blue": return [.blue, .blue.opacity(0.7)]
        case "purple": return [.purple, .purple.opacity(0.7)]
        case "orange": return [.orange, .orange.opacity(0.7)]
        case "red": return [.red, .red.opacity(0.7)]
        case "pink": return [.pink, .pink.opacity(0.7)]
        default: return [.green, .green.opacity(0.7)]
        }
    }
    
    init() {}
}

// MARK: - View Extension for Easy Access
extension View {
    var themeColor: Color {
        ThemeManager.shared.accentColor
    }
    
    var themeGradient: LinearGradient {
        LinearGradient(
            colors: ThemeManager.shared.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
