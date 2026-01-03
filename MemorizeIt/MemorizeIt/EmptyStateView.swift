//
//  EmptyStateView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    @State private var isAnimating = false

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                Circle()
                    .fill(Theme.primary.opacity(0.05))
                    .frame(width: 140, height: 140)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.2), value: isAnimating)

                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(Theme.primary.opacity(0.8))
            }
            .padding(.bottom, 8)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    action()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    static func noFavorites(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "star.slash",
            title: "No Favorites Yet",
            message: "Mark verses as favorites to see them here for quick access",
            actionTitle: "Add Verse",
            action: action
        )
    }

    static func noRecents() -> EmptyStateView {
        EmptyStateView(
            icon: "clock",
            title: "No Recent Activity",
            message: "Your recently practiced verses will appear here"
        )
    }

    static func noVerses(category: String, action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "doc.text",
            title: "No \(category) Yet",
            message: "Add your first \(category.lowercased()) to start memorizing",
            actionTitle: "Add New",
            action: action
        )
    }

    static func nothingToShow() -> EmptyStateView {
        EmptyStateView(
            icon: "tray",
            title: "Nothing Here",
            message: "Get started by adding your first verse or text to memorize"
        )
    }
}

#Preview {
    EmptyStateView.noFavorites(action: {})
}
