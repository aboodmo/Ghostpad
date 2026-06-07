# Ghostpad

A macOS menu bar app: transparent, always-on-top notes overlay for use during meetings/interviews. Phone version possibly later — keep the model layer platform-agnostic.

## Stack
- SwiftUI + AppKit (NSPanel for the floating window)
- macOS 14+, Swift 5.9+
- Model layer lives in the `NotesCore` local Swift package (macOS 14 / iOS 17), depended on by the app target
- Notes persisted as one `.md` file per note in `Application Support/Ghostpad/notes/`, each with a small `<uuid>.json` sidecar for timestamps

## Design language — "Vapor"
Calm, cool, premium; built to look good both at low opacity over a busy call and at high opacity standalone. **Genuinely transparent (no blur)** so the person behind stays visible; **serif** editor (New York) with SF Rounded chrome; cool palette with a cold-blue accent used sparingly. Vapor is the default theme.

## Current state
- Floating transparent NSPanel; top toolbar = sidebar toggle (beside the traffic lights) + fog dial + New Note. 580×520 launch, sidebar open by default
- **Fog dial** (`FogDial`): custom opacity control (0.1–1.0, default 0.6) — a frosted capsule whose fill recedes as opacity drops, % shows on hover/drag; ⌘↑/⌘↓ nudge ±0.05. Persisted via `@AppStorage`
- **Breathing focus**: content/border ease back when the panel isn't key, sharpen when it is
- **Auto-titling editor**: first line renders as a large serif title, rest is the body with a placeholder — both stored in the single `body` string, so the `Note` model is untouched
- Notes persisted to disk as Markdown + JSON sidecar (see Stack); edits debounced 500ms before save
- Multiple notes via `NoteStore` (`@MainActor ObservableObject` in `NotesCore`, injected with a `NoteStorage`): tracks `notes` + `activeNoteID`
- Collapsible left sidebar (⌘B, open by default): rows show title + preview, an accent edge-marker on the active note, hover lift; new note (⌘N), delete (⌘⌫) with confirmation. Settings gear sits at the sidebar's foot
- Pinned notes (`Note.isPinned`, backward-compatible Codable): pinned-first sort, right-click Pin/Unpin, small accent `pin.fill`
- Lives in the menu bar (`LSUIElement`, no Dock icon): status-item menu for Show/Hide, New Note, Settings…, Quit; closing the panel hides it instead of quitting
- Settings window (sidebar gear, menu, or `⌘,`): theme, opacity, font size, always-on-top; Vapor-styled. Hosted in an AppDelegate-owned `NSWindow` (not the SwiftUI `Settings` scene) so it opens programmatically and sits above the always-on-top panel; `@AppStorage`, applied live
- Color themes (`Theme` enum; canonical palettes — Dracula, Nord, Tokyo Night, Catppuccin Mocha/Latte, Gruvbox, Solarized Dark/Light, One Dark, Everforest, Rosé Pine, Monokai, plus Vapor/Charcoal/Sepia/Light): each defines `background` + `text` (+ optional `accent`, + `isDark`); `EditorView` derives all tints from the active theme so dark and light both work
- **Global show/hide hotkey** (default ⌥⌘G): system-wide via Carbon `RegisterEventHotKey` (`GlobalHotKey`, no dependency, no Accessibility permission). User-configurable in Settings → Shortcuts via a recorder; the panel re-registers it live. Conflict handling is best-effort: hard sanity rules (needs a real modifier), a **warn-but-allow** notice for known macOS system shortcuts (curated list — macOS exposes no API to enumerate all global shortcuts) and built-in overlaps, plus Reset to default. Built-in editor shortcuts (⌘N/⌘B/⌘⌫/⌘↑/⌘↓) are listed read-only
- The panel remembers its size/position across launches (`setFrameAutosaveName`); first-run default is 760×640
- App layout: `App/`, `Views/`, `Window/`, `Storage/` in the app target (`FileNoteStorage` + `InMemoryNoteStorage` for previews/tests); `Note` + `NoteStorage` + `NoteStore` in `NotesCore`

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
6. Global hotkey to show/hide — ✅ done (configurable in Settings → Shortcuts)
7. Screen-share auto-hide
8. Click-through mode
