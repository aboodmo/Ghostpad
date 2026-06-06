//
//  Theme.swift
//  Ghostpad
//
//  Color themes for the panel. Each theme supplies a base background color
//  (the opacity slider is applied on top) and a primary text color; all other
//  tints (sidebar veil, selection, hairlines) derive from the text color so a
//  single choice works for both dark and light themes.
//
//  Palettes are taken from the canonical sources of well-known editor/terminal
//  themes (Dracula, Nord, Tokyo Night, Catppuccin, Gruvbox, Solarized, One Dark,
//  Everforest, Rosé Pine, Monokai).
//

import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    // Dark
    case vapor
    case charcoal
    case dracula
    case nord
    case tokyoNight
    case catppuccinMocha
    case gruvbox
    case solarizedDark
    case oneDark
    case everforest
    case rosePine
    case monokai
    // Light
    case solarizedLight
    case catppuccinLatte
    case sepia
    case light

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vapor:           return "Vapor"
        case .charcoal:        return "Charcoal"
        case .dracula:         return "Dracula"
        case .nord:            return "Nord"
        case .tokyoNight:      return "Tokyo Night"
        case .catppuccinMocha: return "Catppuccin Mocha"
        case .gruvbox:         return "Gruvbox"
        case .solarizedDark:   return "Solarized Dark"
        case .oneDark:         return "One Dark"
        case .everforest:      return "Everforest"
        case .rosePine:        return "Rosé Pine"
        case .monokai:         return "Monokai"
        case .solarizedLight:  return "Solarized Light"
        case .catppuccinLatte: return "Catppuccin Latte"
        case .sepia:           return "Sepia"
        case .light:           return "Light"
        }
    }

    /// Base panel background; the opacity slider's value is applied on top.
    var background: Color {
        switch self {
        case .vapor:           return Color(hex: 0x0E1116)
        case .charcoal:        return .black
        case .dracula:         return Color(hex: 0x282A36)
        case .nord:            return Color(hex: 0x2E3440)
        case .tokyoNight:      return Color(hex: 0x1A1B26)
        case .catppuccinMocha: return Color(hex: 0x1E1E2E)
        case .gruvbox:         return Color(hex: 0x282828)
        case .solarizedDark:   return Color(hex: 0x002B36)
        case .oneDark:         return Color(hex: 0x282C34)
        case .everforest:      return Color(hex: 0x2D353B)
        case .rosePine:        return Color(hex: 0x191724)
        case .monokai:         return Color(hex: 0x272822)
        case .solarizedLight:  return Color(hex: 0xFDF6E3)
        case .catppuccinLatte: return Color(hex: 0xEFF1F5)
        case .sepia:           return Color(hex: 0xF4ECD8)
        case .light:           return .white
        }
    }

    /// Whether the theme reads as dark (drives system-control appearance in the
    /// Settings window). The four light palettes are the exceptions.
    var isDark: Bool {
        switch self {
        case .solarizedLight, .catppuccinLatte, .sepia, .light: return false
        default: return true
        }
    }

    /// Accent for the rare, meaningful highlight (the active note). Most themes
    /// stay monochrome (accent == text); Vapor gets its cold electric blue.
    var accent: Color {
        switch self {
        case .vapor: return Color(hex: 0x6EA8FF)
        default:     return text
        }
    }

    /// Primary text/content color. Secondary tints derive from this.
    var text: Color {
        switch self {
        case .vapor:           return Color(hex: 0xE8ECF2)
        case .charcoal:        return .white
        case .dracula:         return Color(hex: 0xF8F8F2)
        case .nord:            return Color(hex: 0xD8DEE9)
        case .tokyoNight:      return Color(hex: 0xC0CAF5)
        case .catppuccinMocha: return Color(hex: 0xCDD6F4)
        case .gruvbox:         return Color(hex: 0xEBDBB2)
        case .solarizedDark:   return Color(hex: 0x93A1A1)
        case .oneDark:         return Color(hex: 0xABB2BF)
        case .everforest:      return Color(hex: 0xD3C6AA)
        case .rosePine:        return Color(hex: 0xE0DEF4)
        case .monokai:         return Color(hex: 0xF8F8F2)
        case .solarizedLight:  return Color(hex: 0x657B83)
        case .catppuccinLatte: return Color(hex: 0x4C4F69)
        case .sepia:           return Color(hex: 0x5B4636)
        case .light:           return Color(hex: 0x1E1E24)
        }
    }
}

extension Color {
    /// Initialize from a 0xRRGGBB integer.
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
