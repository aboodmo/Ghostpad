# Ghostpad

A macOS menu bar app: transparent, always-on-top notes overlay for use during meetings/interviews. Phone version possibly later — keep the model layer platform-agnostic.

## Stack
- SwiftUI + AppKit (NSPanel for the floating window)
- macOS 14+, Swift 5.9+
- No external dependencies yet
- Notes stored as `.md` files on disk (location TBD)
- Model layer will live in a `NotesCore` Swift package (not added yet)

## Current state
- One floating transparent NSPanel with a basic SwiftUI TextEditor
- Hardcoded 0.6 opacity, single in-memory note
- No persistence, no sidebar, no settings, no hotkeys yet

## Conventions
- Small commits, one logical change each. Conventional commit prefixes (feat:, fix:, chore:, refactor:).
- Never `import AppKit` in model code — only in window/view code
- Prefer SwiftUI; drop to AppKit only when SwiftUI can't do it (window styling, global hotkeys)
- Show me diffs before applying. I review every change.
- Explain non-obvious decisions in 1-2 sentences before writing code.

## Roadmap (rough)
1. Opacity slider (live adjustable)
2. Persist notes to disk as .md files
3. Multiple notes + sidebar/picker
4. Menu bar extra (app lives in menu bar, no dock icon)
5. Global hotkey to show/hide
6. Settings window
7. Screen-share auto-hide
8. Click-through mode
