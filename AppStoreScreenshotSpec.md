# MemorizeIt App Store Screenshot Specification

## Overview
This document provides complete specifications for creating App Store screenshots for MemorizeIt.

---

## Required Screenshot Sizes

| Device | Size (pixels) | Requirement |
|--------|---------------|-------------|
| iPhone 6.9" (16 Pro Max) | 1320 x 2868 | Required |
| iPhone 6.5" (14 Plus/15 Plus) | 1284 x 2778 | Required |
| iPad Pro 13" | 2048 x 2732 | Required |
| iPad Pro 11" | 1668 x 2388 | Optional |

---

## Color Palette

### Primary Backgrounds
```
Deep Navy (Hero shots)
  HEX: #1A3366
  RGB: 26, 51, 102

App Primary Blue
  HEX: #3366CC
  RGB: 51, 102, 204

Light Blue (Gradients)
  HEX: #6699FF
  RGB: 102, 153, 255

Pure White (Light mode)
  HEX: #FFFFFF

Dark Background (Dark mode)
  HEX: #0D1B2A
  RGB: 13, 27, 42
```

### Category Colors
```
Bible Verses (Purple-Blue)
  HEX: #6680E6
  RGB: 102, 128, 230

Poems (Rose Pink)
  HEX: #D973A6
  RGB: 217, 115, 166

Speeches (Teal)
  HEX: #4DB399
  RGB: 77, 179, 153
```

### Accent Colors
```
Success/Mastered Green
  HEX: #34C759
  RGB: 52, 199, 89

Warning/In Progress Orange
  HEX: #FF9500
  RGB: 255, 149, 0

New Item Gold
  HEX: #FFD60A
  RGB: 255, 214, 10
```

---

## Typography

### Headlines (on screenshot backgrounds)
- **Font:** SF Pro Display Bold (or SF Pro Rounded Bold for friendlier feel)
- **Size:** 72-90pt for iPhone, 100-120pt for iPad
- **Color:** #FFFFFF (white) on colored backgrounds
- **Line Height:** 1.1
- **Alignment:** Center or Left

### Subheadlines
- **Font:** SF Pro Display Medium
- **Size:** 36-48pt for iPhone, 54-72pt for iPad
- **Color:** #FFFFFF with 85% opacity
- **Line Height:** 1.3

---

## Screenshot Layouts

### Layout A: Device Centered
```
┌─────────────────────────┐
│                         │
│      HEADLINE TEXT      │
│      Subheadline        │
│                         │
│    ┌───────────────┐    │
│    │               │    │
│    │    Device     │    │
│    │   Mockup      │    │
│    │               │    │
│    │               │    │
│    └───────────────┘    │
│                         │
└─────────────────────────┘
```

### Layout B: Device Offset (for longer screens)
```
┌─────────────────────────┐
│                         │
│  HEADLINE     ┌───────┐ │
│  TEXT         │       │ │
│               │Device │ │
│  Subheadline  │Mockup │ │
│               │       │ │
│               │       │ │
│               └───────┘ │
│                         │
└─────────────────────────┘
```

### Layout B: Two Devices (comparison)
```
┌─────────────────────────┐
│                         │
│      HEADLINE TEXT      │
│                         │
│   ┌─────┐   ┌─────┐     │
│   │     │   │     │     │
│   │ A   │   │ B   │     │
│   │     │   │     │     │
│   └─────┘   └─────┘     │
│   Label A   Label B     │
│                         │
└─────────────────────────┘
```

---

## The 6 Screenshots

### Screenshot 1: Hero
**Filename:** `01_hero.png`

| Element | Specification |
|---------|---------------|
| Background | Gradient: #1A3366 → #3366CC (top to bottom) |
| Headline | "Memorize Scripture" |
| Subheadline | "One Verse at a Time" |
| Device Screen | Home/Dashboard with loaded demo data |
| Layout | Device Centered |

**What to show in app:**
- Dashboard with 12-day streak visible
- "Due for Review" section with 2-3 items
- Category cards showing item counts

---

### Screenshot 2: Practice Mode
**Filename:** `02_practice.png`

| Element | Specification |
|---------|---------------|
| Background | Solid: #3366CC |
| Headline | "Type to Learn" |
| Subheadline | "See Progress Instantly" |
| Device Screen | MemorizeView mid-practice |
| Layout | Device Centered |

**What to show in app:**
- A verse partially typed (e.g., John 3:16)
- Real-time character highlighting (green for correct)
- Progress indicator visible
- Full Text mode selected

---

### Screenshot 3: Difficulty Modes
**Filename:** `03_difficulty.png`

| Element | Specification |
|---------|---------------|
| Background | Gradient: #6680E6 → #8899EE |
| Headline | "Three Ways to Practice" |
| Subheadline | "From Guided to Memory" |
| Device Screen | Show difficulty selector or 3 small previews |
| Layout | Device Centered or Three Small Devices |

**What to show in app:**
- Option A: Difficulty picker expanded
- Option B: Three device frames showing same verse in each mode:
  - Full Text (all visible)
  - Hidden Words (some blanked)
  - Blank Canvas (empty)

---

### Screenshot 4: Progress & Stats
**Filename:** `04_progress.png`

| Element | Specification |
|---------|---------------|
| Background | Solid: #4DB399 (Teal) |
| Headline | "Track Your Journey" |
| Subheadline | "Watch Mastery Grow" |
| Device Screen | Stats view or verse list with progress |
| Layout | Device Centered |

**What to show in app:**
- Statistics view with:
  - 12-day streak
  - 47 practice sessions
  - Mastered/In Progress/New counts
  - Weekly activity chart
- OR: Bible Verses category filtered to show mastered items with green badges

---

### Screenshot 5: Add Verses
**Filename:** `05_add_verse.png`

| Element | Specification |
|---------|---------------|
| Background | Solid: #D973A6 (Rose Pink) |
| Headline | "Any Verse, Any Translation" |
| Subheadline | "Add in Seconds" |
| Device Screen | AddNewItemView with search results |
| Layout | Device Centered |

**What to show in app:**
- Bible Verses tab selected
- Search field with "Romans 8:28" typed
- Verse preview showing the text
- Translation picker showing "NIV" selected

---

### Screenshot 6: Organization
**Filename:** `06_categories.png`

| Element | Specification |
|---------|---------------|
| Background | #FFFFFF (Light) or #0D1B2A (Dark) |
| Headline | "Verses, Poems & Speeches" |
| Subheadline | "All in One Place" |
| Device Screen | Home view or sidebar (iPad) |
| Layout | Device Centered |

**What to show in app:**
- Light mode OR dark mode (pick one for contrast)
- All three category cards visible
- Item counts showing content
- Maybe favorites section visible

---

## iPad-Specific Screenshots

For iPad, show the NavigationSplitView sidebar:

### iPad Screenshot 1: Sidebar Navigation
- Show sidebar expanded with all sections
- Detail pane showing Bible Verses category
- Emphasize the grid layout

### iPad Screenshot 2: Practice on iPad
- Show the split practice view
- Reference panel on left, typing on right
- Highlight the larger workspace

---

## Design Tips

### Do's
- Use device mockups (not flat screenshots)
- Add subtle shadows under devices (10-15% black, 20px blur)
- Keep text large enough to read at thumbnail size
- Use consistent margins (80-120px on iPhone sizes)
- Show real app content, not placeholder text

### Don'ts
- Don't show status bar time as something odd
- Don't include personal data or real names
- Don't use more than 2 text sizes per screenshot
- Don't add busy backgrounds or patterns
- Don't crop the device awkwardly

---

## Tools for Creation

### Free
- **Figma** - figma.com (free tier works)
- **Canva** - canva.com (has App Store templates)
- **Previewed** - previewed.app (device mockups)

### Paid
- **Rotato** - rotato.app ($99, best 3D mockups)
- **Screenshots Pro** - screenshots.pro (subscription)
- **Mockup Studio** - mockup.studio

### Device Frames
- Apple Design Resources: https://developer.apple.com/design/resources/
- Facebook Devices: https://design.facebook.com/toolsandresources/devices/

---

## Export Checklist

- [ ] Screenshot 1: Hero (iPhone 6.9", 6.5", iPad 13")
- [ ] Screenshot 2: Practice (iPhone 6.9", 6.5", iPad 13")
- [ ] Screenshot 3: Difficulty (iPhone 6.9", 6.5", iPad 13")
- [ ] Screenshot 4: Progress (iPhone 6.9", 6.5", iPad 13")
- [ ] Screenshot 5: Add Verse (iPhone 6.9", 6.5", iPad 13")
- [ ] Screenshot 6: Categories (iPhone 6.9", 6.5", iPad 13")
- [ ] All exported as PNG
- [ ] No alpha/transparency
- [ ] sRGB color space

---

## App Preview Video (Optional)

If creating a video preview:
- **Length:** 15-30 seconds
- **Resolution:** Same as screenshot sizes
- **Format:** H.264, 30fps
- **Content flow:**
  1. Open app, show dashboard (3s)
  2. Tap a verse, start practicing (5s)
  3. Complete with celebration (3s)
  4. Show stats/progress (3s)
  5. Add a new verse quickly (4s)
  6. End on home screen with tagline (2s)

---

## Quick Reference: All Headlines

| # | Headline | Subheadline |
|---|----------|-------------|
| 1 | Memorize Scripture | One Verse at a Time |
| 2 | Type to Learn | See Progress Instantly |
| 3 | Three Ways to Practice | From Guided to Memory |
| 4 | Track Your Journey | Watch Mastery Grow |
| 5 | Any Verse, Any Translation | Add in Seconds |
| 6 | Verses, Poems & Speeches | All in One Place |
