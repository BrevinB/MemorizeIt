# MemorizeIt

An iOS app for memorizing Scripture through **active recall** — you type the verse from memory
rather than flipping a flashcard and deciding you knew it.

📱 **[Download on the App Store](https://apps.apple.com/us/app/memorizeit-bible-verse-learn/id6755984758)**

## Features

- **Typing-based practice** that forces real recall instead of recognition
- **Voice practice** for reciting verses out loud
- **Categories and favorites** to organize what you're working on
- **Streaks, badges, and stats** to keep the habit going
- **Practice queue** with daily reminders
- **iPad dashboard** with a dedicated split-view layout

## Tech

| Area | Stack |
|---|---|
| UI | SwiftUI (iPhone + iPad layouts) |
| Verse data | Bible API integration (`BibleAPIService`, `APIBibleService`) |
| Audio | AVFoundation for voice practice |
| Notifications | UserNotifications for practice reminders |
| Monetization | StoreKit 2 / RevenueCat paywall |

## Notes

Published to show how the app is built; the App Store release is the supported way to use MemorizeIt.
