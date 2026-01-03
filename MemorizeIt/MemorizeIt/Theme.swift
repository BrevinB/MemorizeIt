//
//  Theme.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI

struct Theme {
    // MARK: - Adaptive Primary Colors (support dark mode)
    static var primary: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)  // Lighter blue for dark mode
                : UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)  // Original blue for light mode
        })
    }

    static var primaryLight: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
                : UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
        })
    }

    static var primaryDark: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
                : UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
        })
    }

    // MARK: - Semantic Colors (automatically adapt to dark mode)
    static var background: Color {
        Color(uiColor: .systemBackground)
    }

    static var secondaryBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    static var tertiaryBackground: Color {
        Color(uiColor: .tertiarySystemBackground)
    }

    static var label: Color {
        Color(uiColor: .label)
    }

    static var secondaryLabel: Color {
        Color(uiColor: .secondaryLabel)
    }

    // MARK: - Status Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    // MARK: - Category Colors (slightly adjusted for better dark mode visibility)
    static var bibleVerse: Color {
        Color(red: 0.4, green: 0.5, blue: 0.9)
    }

    static var poem: Color {
        Color(red: 0.85, green: 0.45, blue: 0.65)
    }

    static var speech: Color {
        Color(red: 0.3, green: 0.7, blue: 0.6)
    }

    // MARK: - Category Helpers
    static func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "bible verses":
            return "book.closed.fill"
        case "poems":
            return "text.quote"
        case "speeches":
            return "mic.fill"
        default:
            return "doc.text.fill"
        }
    }

    static func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "bible verses":
            return bibleVerse
        case "poems":
            return poem
        case "speeches":
            return speech
        default:
            return primary
        }
    }

    // MARK: - Text Styles with Dynamic Type support
    struct TextStyle {
        static func largeTitle() -> Font {
            .largeTitle.weight(.bold)
        }

        static func title() -> Font {
            .title2.weight(.bold)
        }

        static func headline() -> Font {
            .headline
        }

        static func body() -> Font {
            .body
        }

        static func caption() -> Font {
            .caption
        }
    }

    // MARK: - Spacing constants
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    // MARK: - Corner Radius constants
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
    }
}

// MARK: - Accessibility modifiers
extension View {
    /// Adds standard accessibility label and hint
    func accessibleCard(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }

    /// Makes a button more accessible
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Adaptive Layout Helpers for iPad
struct AdaptiveLayout {
    /// Returns adaptive grid columns based on horizontal size class
    static func gridColumns(
        for sizeClass: UserInterfaceSizeClass?,
        minWidth: CGFloat = 160,
        maxWidth: CGFloat = 200
    ) -> [GridItem] {
        if sizeClass == .regular {
            return [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: 16)]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    /// Returns number of columns for a fixed grid based on size class
    static func columnCount(for sizeClass: UserInterfaceSizeClass?) -> Int {
        sizeClass == .regular ? 4 : 2
    }

    /// Returns appropriate content padding for device
    static func contentPadding(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 24 : 16
    }

    /// Returns whether the device is in regular width (iPad)
    static func isRegularWidth(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular
    }
}

// MARK: - Adaptive Sheet Presentation
extension View {
    /// Presents a sheet with appropriate sizing for iPad
    func adaptiveSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            content()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - iPad Hover Effect
extension View {
    /// Adds hover effect for iPad pointer support
    func iPadHoverEffect() -> some View {
        self.hoverEffect(.lift)
    }
}
