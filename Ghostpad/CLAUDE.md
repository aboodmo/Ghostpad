# Ghostpad

A macOS menu bar app: a transparent, always-on-top notes overlay for use during meetings/interviews — "the calm in a tense moment." A phone version is possible later, so the model layer is kept platform-agnostic.

## Stack & requirements
- SwiftUI + AppKit. The floating window is an AppKit `NSPanel`; everything inside it is SwiftUI.
- macOS 14+, Swift 5.9+. Bundle id `com.aboodmo.Ghostpad`. **App is sandboxed.**
- `LSUIElement` agent app: no Dock icon, lives in the menu bar.
- Model layer lives in the `NotesCore` local Swift package (`Packages/NotesCore`, platforms macOS 14 / iOS 17), depended on by the app target. **No third-party dependencies** — pure SwiftUI + AppKit + Carbon.
- Notes persist as one `.md` file per note (pure Markdown) plus a `<uuid>.json` sidecar holding timestamps + pin state.

## Architecture & data flow
- **`NotesCore` (platform-agnostic, Foundation only — never import AppKit/SwiftUI here):**
  - `Note` — `Identifiable, Codable, Equatable` struct: `id`, `body`, `createdAt`, `modifiedAt`, `isPinned`. `title` is computed as the first non-empty line. Custom `init(from:)` decodes `isPinned` with `decodeIfPresent` for backward compatibility.
  - `NoteStorage` — protocol: `loadAll()`, `save(_:)`, `delete(id:)`.
  - `NoteStore` — `@MainActor ObservableObject`: holds `@Published notes` + `activeNoteID`, injected with a `NoteStorage`. Edits are applied in memory immediately, disk writes **debounced 500ms** via a Combine `PassthroughSubject`. Pin changes persist immediately (not debounced).
- **App target (`Ghostpad/`):**
  - `App/GhostpadApp.swift` — `@main` `App` (an empty `Settings` scene) + `AppDelegate` (the real entry point). The `AppDelegate` owns the `NoteStore`, the `FloatingPanel`, the menu-bar status item, the settings `NSWindow`, and the global hotkey. It reads `@AppStorage`-backed `UserDefaults` and applies settings live via a `UserDefaults.didChangeNotification` observer.
  - `Views/` — all SwiftUI: `EditorView` (the panel content), `SettingsView`, `Theme`.
  - `Window/` — AppKit glue: `FloatingPanel` (the `NSPanel` subclass) and `GlobalHotKey` (Carbon hotkey + the `Shortcut` model).
  - `Storage/` — `FileNoteStorage` (disk) and `InMemoryNoteStorage` (previews/tests).
- **Settings flow:** `SettingsView` writes `@AppStorage` keys; both `EditorView` and the `AppDelegate` read the same keys. The `AppDelegate`'s defaults observer re-applies window level, capture exclusion, click-through, and re-registers the hotkey on any change (each guarded/idempotent so frequent changes like opacity drags are cheap).

## File map
- `Ghostpad/App/GhostpadApp.swift` — entry point, `AppDelegate`, menu bar, settings window hosting, live-settings application, global hotkey registration.
- `Ghostpad/Views/EditorView.swift` — the panel: toolbar, sidebar, editor. Contains `FogDial`, `NonWindowDragging`, `NoteRow`, and the title/body split bindings. `init(store:showSidebar:)` defaults `showSidebar` to **false**, but the `AppDelegate` constructs it with `showSidebar: true` (sidebar open by default).
- `Ghostpad/Views/SettingsView.swift` — Vapor-styled settings (grouped cards). Contains the `ShortcutRecorder` view and the read-only built-in shortcut list.
- `Ghostpad/Views/Theme.swift` — `Theme` enum (palettes) + `Color(hex:)` helper. Each case provides `background`, `text`, optional `accent` (only Vapor differs; others default to `text`), and `isDark`.
- `Ghostpad/Window/FloatingPanel.swift` — `NSPanel` subclass: `.nonactivatingPanel`, transparent, no shadow, `.floating` level, `canJoinAllSpaces`, movable by background, `canBecomeKey = true`.
- `Ghostpad/Window/GlobalHotKey.swift` — `GlobalHotKey` (Carbon `RegisterEventHotKey` + one shared event handler) and the `Shortcut` struct (Carbon keyCode + modifier mask + display label, display glyphs, and the curated `systemReserved` conflict list).
- `Ghostpad/Storage/FileNoteStorage.swift` — `.md` + `.json` sidecar per note in Application Support.
- `Ghostpad/Storage/InMemoryNoteStorage.swift` — for `#Preview`s and tests.
- `Packages/NotesCore/Sources/NotesCore/` — `Note.swift`, `NoteStorage.swift`, `NoteStore.swift`.

## Design language — "Vapor"
Calm, cool, premium; built to read well both at low opacity over a busy call and at high opacity standalone.
- **Genuinely transparent (no blur).** The panel background is `theme.background.opacity(panelOpacity)` only — the person/screen behind stays clearly visible. Text keeps full strength (only the backing fades). (An `NSVisualEffectView` blur was tried and removed because it frosted the background and hid the person on the call — do not reintroduce blur.)
- **Type:** editor title + body use the system **serif** (New York); chrome glyphs are SF Rounded; numerals monospaced.
- **Palette:** cool near-black `0x0E1116` / cool white `0xE8ECF2`, with the cold-blue accent `0x6EA8FF` used rarely and meaningfully (active-note marker, focus, controls). Vapor is the default theme.
- **Signature interactions:** the **fog dial** (opacity) and **breathing focus** (panel exhales when inactive, sharpens when key).

## Feature reference
- **Window:** transparent `NSPanel`, 16pt continuous corners. **760×640 first-run size**, then remembers size/position across launches via `setFrameAutosaveName("GhostpadPanel")` (the contentRect is only the first-run default). Sidebar open by default.
- **Toolbar:** sidebar toggle (left, beside the traffic lights — `.padding(.leading, 76)` reserves room) · `FogDial` · New Note.
- **Fog dial** (`FogDial` in `EditorView.swift`): custom opacity control (0.1–1.0, default 0.6) — a frosted capsule whose fill recedes as opacity drops, with a spring knob and a monospaced % that surfaces only on hover/drag. ⌘↑/⌘↓ nudge ±0.05. Persisted via `@AppStorage("panelOpacity")`. Backed by `NonWindowDragging` (an `NSView` returning `mouseDownCanMoveWindow = false`) so dragging it slides the value instead of moving the background-movable panel.
- **Breathing focus:** via `@Environment(\.controlActiveState)`, content opacity + border ease back when the panel isn't key and sharpen when it is.
- **Auto-titling editor:** the note's first line renders as a large serif title (`TextField`); the rest is the body (`TextEditor`) with a "Start typing…" placeholder. Both write back into the single stored `body` string (split on the first newline), so the `Note` model is untouched; Return moves focus title→body. Scroll indicator hidden for a clean edge.
- **Sidebar** (`NoteRow`): title + preview line; the active note has a cold-blue accent edge-marker (reserved width, no layout shift) + soft fill; rows lift on hover. New note ⌘N, delete ⌘⌫ (only while the sidebar is open, so it doesn't shadow delete-to-line-start) with a confirmation alert. The **settings gear lives at the sidebar's bottom-right** (only visible while the sidebar is open).
- **Pinned notes** (`Note.isPinned`): pinned-first sort, right-click Pin/Unpin, a small rotated `pin.fill` in the accent color.
- **Menu bar** (`LSUIElement`): status-item menu — Show/Hide Ghostpad (title + key-equivalent mirror the configured hotkey), New Note, Click-Through (checkable), Settings…, Quit. Closing the panel (red button) hides it instead of quitting; the app stays alive with no windows.
- **Settings window** (sidebar gear, menu, or `⌘,`): Vapor-styled grouped cards (Appearance / Shortcuts / Window) with an icon per row, a serif title, and a version footer. Hosted in an **AppDelegate-owned `NSWindow`** (not the SwiftUI `Settings` scene) so it can open programmatically and sit one level above the always-on-top panel. All values are `@AppStorage`, applied live.
- **Themes** (`Theme` enum; canonical palettes — Vapor, Charcoal, Dracula, Nord, Tokyo Night, Catppuccin Mocha/Latte, Gruvbox, Solarized Dark/Light, One Dark, Everforest, Rosé Pine, Monokai, Sepia, Light): each defines `background` + `text` (+ optional `accent`, + `isDark`); `EditorView` derives all tints from the active theme so dark and light both work.
- **Global show/hide hotkey** (default ⌥⌘G, `GlobalHotKey` via Carbon `RegisterEventHotKey` — no dependency, no Accessibility permission): toggles the panel from any app, re-registered live from `@AppStorage`. **Configurable** in Settings → Shortcuts via a recorder (`ShortcutRecorder`: click → press combo, Esc cancels, swallows the keystroke, requires a real modifier). Conflict handling is **best-effort** (macOS exposes no API to enumerate all global shortcuts): a **warn-but-allow** notice for known macOS system shortcuts (a curated `Shortcut.systemReserved` list) and built-in overlaps, plus Reset to default. Built-in editor shortcuts (⌘B/⌘N/⌘⌫/⌘↑/⌘↓) are listed read-only.
- **Hide from screen sharing** (`hideFromCapture`, **on by default**): sets `NSWindow.sharingType = .none`, excluding the panel from all screen recording/sharing/screenshots at the OS level — no detection, no permissions. Toggle in Settings → Window. ⚠️ This also hides the panel from *intentional* screenshots — see Gotchas.
- **Click-through** (`clickThrough`, off by default): sets `ignoresMouseEvents` so clicks pass through to the app behind. Because the panel can't be clicked in this mode, it's reversible from a **global hotkey** (default ⌥⌘T, also configurable in Settings → Shortcuts) and the checkable **menu-bar "Click-Through"** item / Settings → Window.
- **Two configurable global hotkeys** live in Settings → Shortcuts (Show/Hide ⌥⌘G, Toggle Click-Through ⌥⌘T). The `AppDelegate` keeps them in `hotKeys`/`appliedHotKeys` dictionaries keyed by the `@AppStorage` prefix (`hotkey.showHide` / `hotkey.clickThrough`); `registerHotKey(_:action:)` re-registers per-prefix when changed. The recorder warns (but allows) when a combo matches the other Ghostpad hotkey, a system shortcut, or a built-in.

## Settings / `@AppStorage` keys
All registered as defaults in `AppDelegate.applicationDidFinishLaunching`. Keep `@AppStorage` defaults in the views in sync with these.

| Key | Type | Default | Read by / applied where |
| --- | --- | --- | --- |
| `panelOpacity` | Double | 0.6 | EditorView panel tint + FogDial; ⌘↑/⌘↓ |
| `editorFontSize` | Double | 15 | EditorView title (+8) and body |
| `theme` | String | `Theme.vapor.rawValue` | EditorView + SettingsView tints |
| `alwaysOnTop` | Bool | true | `applyWindowLevel()` → panel `.floating`/`.normal` |
| `hideFromCapture` | Bool | true | `applyCaptureExclusion()` → `sharingType` |
| `clickThrough` | Bool | false | `applyClickThrough()` → `ignoresMouseEvents`; menu checkmark |
| `hotkey.showHide.{keyCode,modifiers,label}` | Int/Int/String | G, ⌘⌥, "G" | `registerHotKey("hotkey.showHide")` + menu key-equivalent + recorder |
| `hotkey.clickThrough.{keyCode,modifiers,label}` | Int/Int/String | T, ⌘⌥, "T" | `registerHotKey("hotkey.clickThrough")` + menu key-equivalent + recorder |

Panel frame is stored separately by AppKit under `UserDefaults` key `NSWindow Frame GhostpadPanel` (via `setFrameAutosaveName`).

## Build & run
- `xcodebuild -scheme Ghostpad -configuration Debug -derivedDataPath ./build build`
- Launch the built app: `open "$PWD/build/Build/Products/Debug/Ghostpad.app"` (use `killall Ghostpad` first; it's a single-instance menu-bar app).
- The Xcode project is **old-style** (`objectVersion = 56`), **not** a file-system-synchronized group. **Adding a new Swift file requires editing `Ghostpad.xcodeproj/project.pbxproj` by hand** in four places, mirroring an existing file (e.g. `FloatingPanel.swift`): a `PBXBuildFile` entry, a `PBXFileReference` entry, the file's group `children` list, and the `PBXSourcesBuildPhase` `files` list. The placeholder ids follow the `AA000000000000000000000xx` pattern (`Bx` for file refs, `Cx` for build files).

## Gotchas for future sessions (things that cost time)
- **Sandbox paths.** Notes live in the container, not `~/Library` directly: `~/Library/Containers/com.aboodmo.Ghostpad/Data/Library/Application Support/Ghostpad/notes/`. The defaults domain is `com.aboodmo.Ghostpad` (`defaults read/write com.aboodmo.Ghostpad <key>`).
- **Screenshotting the panel.** It's a `.nonactivatingPanel` on `LSUIElement`; a full-screen `screencapture` can race or miss it, and may land on a different Space. Most reliable: enumerate windows via `CGWindowListCopyWindowInfo` (the panel is **layer 3**; the status item is layer ~25) and capture by window id with `screencapture -l<id>`. Note window-id capture shows only the window's own layer (no see-through background).
- **Capture exclusion blocks screenshots.** With `hideFromCapture` **on (the default)**, `sharingType = .none` means the panel is **absent from every screenshot** and window-id capture **fails** ("could not create image from window"). To screenshot the panel during development, temporarily disable it: `defaults write com.aboodmo.Ghostpad hideFromCapture -bool false` then relaunch (and reset with `defaults delete … hideFromCapture` after). The Settings window is a separate `NSWindow` and is always capturable.
- **Screen Recording permission.** `screencapture` only includes window contents if the controlling terminal has Screen Recording permission; otherwise captures return just the wallpaper + menu bar. Granting it requires quitting & reopening the terminal app.
- **Showing the sidebar / Settings for a screenshot.** Sidebar: the panel launches with it open. Settings: it only opens on user action — to capture it, temporarily add `openSettings()` after `setupStatusItem()` (revert after). To capture content below the scroll fold, temporarily raise the `SettingsView` `.frame` height.
- **Resetting panel size in dev:** `defaults delete com.aboodmo.Ghostpad "NSWindow Frame GhostpadPanel"`.
- **Live settings are applied via a `UserDefaults.didChangeNotification` observer** in the `AppDelegate`; external `defaults write` from the CLI may not notify the running app — relaunch to be sure. In-app `@AppStorage` writes always notify.

## Conventions
- Small commits, one logical change each. No commit-type prefixes (no feat:/fix:/chore:/refactor:). Group related work into notable commits rather than splitting every tiny change.
- I (the user) run the commits myself — Claude stages/prepares and suggests a message, but does not commit.
- Never `import AppKit` in model code (`NotesCore`) — only in window/view code.
- Prefer SwiftUI; drop to AppKit/Carbon only when SwiftUI can't do it (window styling, global hotkeys, capture exclusion).
- Show me diffs before applying. I review every change.
- Explain non-obvious decisions in 1-2 sentences before writing code.
- After each notable feature, build + run and (when possible) screenshot to verify; keep this CLAUDE.md current.

## Roadmap
1. Opacity slider (live adjustable) — ✅ done
2. Persist notes to disk as .md files — ✅ done
3. Multiple notes + sidebar/picker — ✅ done
4. Menu bar extra (app lives in menu bar, no dock icon) — ✅ done
5. Settings window — ✅ done
6. Global hotkey to show/hide — ✅ done (configurable in Settings → Shortcuts)
7. Screen-share auto-hide — ✅ done (excluded from capture via `sharingType = .none`)
8. Click-through mode — ✅ done (`ignoresMouseEvents`, toggle via menu bar / Settings)

Original roadmap complete. Possible next directions (not yet planned): Markdown rendering in the editor, iCloud/file sync, quick-capture from the hotkey, multi-window notes, a polish pass.
