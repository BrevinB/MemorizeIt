//
//  PracticeQueueView.swift
//  MemorizeIt
//
//  Hosts a back-to-back practice session over a list of due verses. Drives
//  MemorizeView with a queueAdvance callback so the user can chain verses
//  with one tap. Ends in a small celebration summary.
//

import SwiftUI

struct PracticeQueueView: View {
    let items: [MemorizeItemModel]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var completedCount: Int = 0
    @State private var showSummary: Bool = false

    var body: some View {
        Group {
            if showSummary || currentIndex >= items.count {
                summary
            } else {
                MemorizeView(
                    item: items[currentIndex],
                    queueProgress: (currentIndex + 1, items.count),
                    queueAdvance: advance
                )
                // Force a fresh MemorizeView per verse so internal @State resets
                .id(items[currentIndex].id)
            }
        }
    }

    private func advance() {
        completedCount += 1
        if currentIndex + 1 >= items.count {
            showSummary = true
        } else {
            currentIndex += 1
        }
    }

    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: completedCount == items.count ? "checkmark" : "flag.checkered")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Theme.primary)
            }

            VStack(spacing: 8) {
                Text(completedCount == items.count ? "Session complete!" : "Nice work!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("You practiced \(completedCount) verse\(completedCount == 1 ? "" : "s").")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Practice Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            HapticManager.shared.notification(type: .success)
        }
    }
}
