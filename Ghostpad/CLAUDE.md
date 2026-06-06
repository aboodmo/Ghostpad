# Ghostpad

A macOS menu bar app: transparent, always-on-top notes overlay for use during meetings/interviews. Phone version possibly later — keep the model layer platform-agnostic.

## Stack
- SwiftUI + AppKit (NSPanel for the floating window)
- macOS 14+, Swift 5.9+
- Model layer lives in the `NotesCore` local Swift package (macOS 14 / iOS 17), depended on by the app target
- Notes persisted as one `.md` file per note in `Application Support/Ghostpad/notes/`, each with a small `<uuid>.json` sidecar for timestamps

## Current state
- Floating transparent NSPanel hosting a SwiftUI TextEditor
- Live opacity slider (0.1–1.0, default 0.6) at the top; persisted via `@AppStorage`; ⌘↑/⌘↓ nudge ±0.05
- Notes persisted to disk as Markdown + JSON sidecar (see Stack); single active note loaded on launch, edits debounced 500ms before save
- MVVM layout: `App/`, `ViewModels/`, `Views/`, `Window/`, `Storage/` in the app target; `Note` + `NoteStorage` in `NotesCore`
- No sidebar/multi-note, settings, or global hotkeys yet

## Conventions
- Small commits, one logical change each. Conventional commit prefixes (feat:, fix:, chore:, refactor:).
- Never `import AppKit` in model code — only in window/view code
- Prefer SwiftUI; drop to AppKit only when SwiftUI can't do it (window styling, global hotkeys)
- Show me diffs before applying. I review every change.
- Explain non-obvious decisions in 1-2 sentences before writing code.

## Roadmap (rough)
1. Opacity slider (live adjustable) — ✅ done
2. Persist notes to disk as .md files — ✅ done
3. Multiple notes + sidebar/picker — 🚧 in progress
4. Menu bar extra (app lives in menu bar, no dock icon)
5. Global hotkey to show/hide
6. Settings window
7. Screen-share auto-hide
8. Click-through mode
