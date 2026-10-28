//
//  Theme.swift
//  7Zip iOS Strict Dark Minimalist Theme
//

import SwiftUI
import UIKit

public struct AppTheme {
    // Exact colors specified in Section 4 of requirements
    public static let background = Color.black // #000000
    public static let cardBackground = Color(red: 14/255.0, green: 14/255.0, blue: 14/255.0) // #0E0E0E
    public static let cardBackgroundSecondary = Color(red: 18/255.0, green: 18/255.0, blue: 18/255.0) // #121212
    public static let divider = Color(red: 31/255.0, green: 31/255.0, blue: 31/255.0) // #1F1F1F
    public static let textPrimary = Color(red: 242/255.0, green: 242/255.0, blue: 242/255.0) // #F2F2F2
    public static let textSecondary = Color(red: 142/255.0, green: 142/255.0, blue: 147/255.0) // #8E8E93
    public static let accent = Color.white // #FFFFFF
    public static let error = Color(red: 255/255.0, green: 69/255.0, blue: 58/255.0) // #FF453A
    public static let success = Color(red: 52/255.0, green: 199/255.0, blue: 89/255.0) // #34C759
    public static let warning = Color(red: 255/255.0, green: 214/255.0, blue: 10/255.0) // #FFD60A

    public static let cornerRadius: CGFloat = 14.0

    public static func triggerHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        if UserDefaults.standard.object(forKey: "enable_haptics") as? Bool ?? true {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }

    public static func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        if UserDefaults.standard.object(forKey: "enable_haptics") as? Bool ?? true {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}

public struct CardModifier: ViewModifier {
    var padding: CGFloat = 14.0

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
    }
}

public extension View {
    func appCardStyle(padding: CGFloat = 14.0) -> some View {
        self.modifier(CardModifier(padding: padding))
    }

    func appBackground() -> some View {
        self.background(AppTheme.background.ignoresSafeArea())
    }
}
