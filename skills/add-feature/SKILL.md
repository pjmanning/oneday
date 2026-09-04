---
name: add-feature
description: Scaffold a new feature module (View + @Observable view model + flag + optional tab) that stays deletable. Use when adding a new screen or section to the app.
---

# Add a feature module

A feature is a folder under `SwiftUITemplate/Features/`, a compile-time flag,
and — if it deserves a tab — one case in `AppTab`. Nothing else.

## 1. Flag

Add the token to `FEATURE_FLAGS` in `Config/Base.xcconfig`:

```
FEATURE_FLAGS = ... FEATURE_JOURNAL
```

Mirror it in `SwiftUITemplate/App/FeatureFlags.swift`:

```swift
#if FEATURE_JOURNAL
static let journal = true
#else
static let journal = false
#endif
```

and add `("Journal", journal)` to `FeatureFlags.all`.

## 2. Folder

Create `SwiftUITemplate/Features/Journal/`. No project file edit — the target
uses synchronized folders and picks up new `.swift` files automatically.

`JournalViewModel.swift`:

```swift
import Foundation

@MainActor
@Observable
final class JournalViewModel {
    enum LoadState {
        case idle, loading
        case loaded([JournalEntry])
        case failed(String)
    }

    private(set) var state: LoadState = .idle

    func observe(using backend: BackendService) async {
        state = .loading
        do {
            for try await entries in backend.subscribe(to: "journal:list", as: [JournalEntry].self) {
                state = .loaded(entries)
            }
        } catch is CancellationError {
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
```

`JournalView.swift`:

```swift
import SwiftUI

struct JournalView: View {
    @Environment(BackendService.self) private var backend
    @State private var model = JournalViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Journal")
        }
        .task { await model.observe(using: backend) }
        .accessibilityIdentifier("journal")
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let entries) where entries.isEmpty:
            ContentUnavailableView("No entries yet", systemImage: "book")
        case .loaded(let entries):
            List(entries) { entry in Text(entry.title) }
        case .failed(let message):
            ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(message))
        }
    }
}
```

## 3. Tab (only if it needs one)

In `App/AppTab.swift`, add the case and its three switch arms — each wrapped in
`#if FEATURE_JOURNAL`:

```swift
#if FEATURE_JOURNAL
case journal
#endif
```

`MainTabView` needs a matching arm, also guarded:

```swift
#if FEATURE_JOURNAL
case .journal: JournalView()
#endif
```

## Rules that make it deletable

- Import nothing from a sibling feature. Need another feature's UI? Embed its
  entry view inside `#if FEATURE_OTHER`, one line.
- Import no SDK. Go through `Services/`.
- Shared UI belongs in `Core/DesignSystem`, not in your feature folder.
- Navigate by talking to `RootRouter`, not by presenting another feature's root.
- `accessibilityIdentifier` on every interactive control, named `journal.addEntry`.

## Verify

Build once with the flag on, then remove the token from `FEATURE_FLAGS`, delete
the folder, and build again. Both must succeed — see the `verify-build` skill.
