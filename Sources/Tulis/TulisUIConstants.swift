#if canImport(UIKit)
import CoreGraphics
import Foundation
import PencilKit
import TulisCore
import UIKit

public enum TulisPalette {
    public static let paper = 0xFFF6F0E2
    public static let card = 0xFFFBF7EC
    public static let ink: Int32 = -13949372 // 0xFF2B2724
    public static let inkSoft: Int32 = -10792118 // 0xFF5B534A
    public static let red: Int32 = -4048097 // 0xFFC23B1F
    public static let yellow: Int32 = -666297 // 0xFFF5D547
    public static let blue: Int32 = -13804120 // 0xFF2D5DA8
    public static let green: Int32 = -12681905 // 0xFF3E7D4F
    public static let orange: Int32 = -2064356 // 0xFFE0801C
    public static let purple: Int32 = -8761437 // 0xFF7A4FA3
    public static let kraft = 0xFFE9E0CB
    public static let canvas = 0xFFFBF8EF
    public static let desk = 0xFFE6DDC8
    public static let sheet = 0xFFFFFDF6

    public static let colors: [Int32] = [
        ink,
        red,
        blue,
        green,
        orange,
        purple
    ]

    public static func colorName(for argb: Int32) -> String {
        switch argb {
        case ink: return "Hitam"
        case red: return "Merah"
        case blue: return "Biru"
        case green: return "Hijau"
        case orange: return "Oranye"
        case purple: return "Ungu"
        case yellow: return "Kuning"
        default: return "Warna"
        }
    }

    public static let uiCanvas = UIColor(red: 251/255, green: 248/255, blue: 239/255, alpha: 1.0)
    public static let uiCard = UIColor(red: 251/255, green: 247/255, blue: 236/255, alpha: 1.0)
    public static let uiInk = UIColor(red: 43/255, green: 39/255, blue: 36/255, alpha: 1.0)
    public static let uiInkSoft = UIColor(red: 91/255, green: 83/255, blue: 74/255, alpha: 1.0)
    public static let uiYellow = UIColor(red: 245/255, green: 213/255, blue: 71/255, alpha: 1.0)
}

public struct ToolPreferences {
    private static let keyPenWidth = "tulis_width_pen"
    private static let keyMarkerWidth = "tulis_width_marker"
    private static let keyHighlighterWidth = "tulis_width_highlighter"

    private static let keyPenColor = "tulis_color_pen"
    private static let keyMarkerColor = "tulis_color_marker"
    private static let keyHighlighterColor = "tulis_color_highlighter"

    public static func width(for tool: Tool) -> Float {
        let defaults = UserDefaults.standard
        switch tool {
        case .pen:
            let val = defaults.float(forKey: keyPenWidth)
            return val > 0 ? min(max(val, 1.0), 16.0) : 4.0
        case .marker:
            let val = defaults.float(forKey: keyMarkerWidth)
            return val > 0 ? min(max(val, 2.0), 28.0) : 8.0
        case .highlighter:
            let val = defaults.float(forKey: keyHighlighterWidth)
            return val > 0 ? min(max(val, 6.0), 48.0) : 20.0
        default:
            return 4.0
        }
    }

    public static func setWidth(_ width: Float, for tool: Tool) {
        let defaults = UserDefaults.standard
        switch tool {
        case .pen:
            defaults.set(min(max(width, 1.0), 16.0), forKey: keyPenWidth)
        case .marker:
            defaults.set(min(max(width, 2.0), 28.0), forKey: keyMarkerWidth)
        case .highlighter:
            defaults.set(min(max(width, 6.0), 48.0), forKey: keyHighlighterWidth)
        default:
            break
        }
    }

    public static func color(for tool: Tool) -> Int32 {
        let defaults = UserDefaults.standard
        switch tool {
        case .pen:
            let val = defaults.integer(forKey: keyPenColor)
            return val != 0 ? Int32(val) : TulisPalette.ink
        case .marker:
            let val = defaults.integer(forKey: keyMarkerColor)
            return val != 0 ? Int32(val) : TulisPalette.ink
        case .highlighter:
            let val = defaults.integer(forKey: keyHighlighterColor)
            return val != 0 ? Int32(val) : TulisPalette.yellow
        default:
            return TulisPalette.ink
        }
    }

    public static func setColor(_ color: Int32, for tool: Tool) {
        let defaults = UserDefaults.standard
        switch tool {
        case .pen:
            defaults.set(Int(color), forKey: keyPenColor)
        case .marker:
            defaults.set(Int(color), forKey: keyMarkerColor)
        case .highlighter:
            defaults.set(Int(color), forKey: keyHighlighterColor)
        default:
            break
        }
    }

    public static func widthRange(for tool: Tool) -> ClosedRange<Float> {
        switch tool {
        case .pen: return 1.0...16.0
        case .marker: return 2.0...28.0
        case .highlighter: return 6.0...48.0
        default: return 1.0...20.0
        }
    }
}
#endif
