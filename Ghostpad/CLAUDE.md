# Ghostpad

A macOS menu bar app: transparent, always-on-top notes overlay for use during meetings/interviews. Phone version possibly later — keep the model layer platform-agnostic.

## Stack
- SwiftUI + AppKit (NSPanel for the floating window)
- macOS 14+, Swift 5.9+
- Model layer lives in the `NotesCore` local Swift package (macOS 14 / iOS 17), depended on by the app target
- Notes persisted as one `.md` file per note in `Application Support/Ghostpad/notes/`, each with a small `<uuid>.json` sidecar for timestamps

## Current state
- Floating transparent NSPanel with an Apple Notes-style top toolbar (sidebar toggle sits beside the traffic-light buttons)
- Live opacity slider (0.1–1.0, default 0.6) in the top toolbar; persisted via `@AppStorage`; ⌘↑/⌘↓ nudge ±0.05
- Notes persisted to disk as Markdown + JSON sidecar (see Stack); edits debounced 500ms before save
- Multiple notes via `NoteStore` (`@MainActor ObservableObject` in `NotesCore`, injected with a `NoteStorage`): tracks `notes` + `activeNoteID`
- Collapsible left sidebar (toolbar toggle or ⌘B, hidden by default): rows show title + preview line, click to switch, new note (⌘N / toolbar), delete (⌘⌫ / context menu) with confirmation
- Pinned notes (`Note.isPinned`, backward-compatible Codable): pinned-first sort, right-click Pin/Unpin, subtle ◆ indicator
- Lives in the menu bar (`LSUIElement`, no Dock icon): status-item menu for Show/Hide, New Note, Settings…, Quit; closing the panel hides it instead of quitting
- Settings window (toolbar gear, menu, or `⌘,`): theme, opacity, editor font size, always-on-top; `SettingsView` is hosted in an AppDelegate-owned `NSWindow` (not the SwiftUI `Settings` scene, so it can open programmatically and sit above the always-on-top panel); values stored via `@AppStorage` and applied live
- Color themes (`Theme` enum in the view layer; palettes from canonical sources — Dracula, Nord, Tokyo Night, Catppuccin Mocha/Latte, Gruvbox, Solarized Dark/Light, One Dark, Everforest, Rosé Pine, Monokai, plus Charcoal/Sepia/Light): each defines a background + text color (`Color(hex:)` helper); `EditorView` derives all tints from the active theme so dark and light themes both work
- App layout: `App/`, `Views/`, `Window/`, `Storage/` in the app target (`FileNoteStorage` + `InMemoryNoteStorage` for previews/tests); `Note` + `NoteStorage` + `NoteStore` in `NotesCore`
- No global (system-wide) hotkeys yet

## Conventions
- Small commits, one logical change each. No commit-type prefixes (no feat:/fix:/chore:/refactor:).
- I (the user) run the commits myself — Claude stages/prepares and suggests a message, but does not commit.
- Never `import AppKit` in model code — only in window/view code
- Prefer SwiftUI; drop to AppKit only when SwiftUI can't do it (window styling, global hotkeys)
- Show me diffs before applying. I review every change.
- Explain non-obvious decisions in 1-2 sentences before writing code.

## Roadmap (rough)
1. Opacity slider (live adjustable) — ✅ done
2. Persist notes to disk as .md files — ✅ done
3. Multiple notes + sidebar/picker — ✅ done
4. Menu bar extra (app lives in menu bar, no dock icon) — ✅ done
5. Settings window — ✅ done
6. Global hotkey to show/hide
7. Screen-share auto-hide
8. Click-through mode
