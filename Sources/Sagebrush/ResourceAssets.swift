import SwiftUI

enum SagebrushAssets {
    static func image(_ name: String) -> Image {
        #if canImport(UIKit)
        if UIImage(named: name, in: .module, with: nil) != nil {
            return Image(name, bundle: .module)
        }
        #elseif canImport(AppKit)
        if Bundle.module.image(forResource: name) != nil {
            return Image(name, bundle: .module)
        }
        #endif
        // Fallback for test contexts where bundle assets resolve to empty
        switch name {
        case "SagebrushLogo":
            return Image(systemName: "building.2.fill")
        default:
            return Image(name, bundle: .module)
        }
    }

    static func color(_ name: String) -> Color {
        switch name {
        case "SagebrushGreen":
            return Color(
                light: Color(hex: 0x006400),
                dark: Color(hex: 0x208020)
            )
        case "DesertGold":
            return Color(hex: 0xDAA520)
        default:
            return Color(name, bundle: .module)
        }
    }
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}
