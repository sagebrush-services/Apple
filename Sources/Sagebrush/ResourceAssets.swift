import SwiftUI

enum SagebrushAssets {
    static func image(_ name: String) -> Image {
        // Asset catalog images compile into a .car inside Bundle.module.
        // On macOS (NSHostingView screenshots) the .car lookup silently returns
        // an empty image, so we also ship a loose PNG copy in Resources/ and
        // load it directly as a fallback.
        #if canImport(AppKit)
        if let url = Bundle.module.url(forResource: "\(name)@2x", withExtension: "png"),
            let nsImage = NSImage(contentsOf: url)
        {
            nsImage.size = NSSize(
                width: nsImage.size.width / 2,
                height: nsImage.size.height / 2
            )
            return Image(nsImage: nsImage)
        }
        #endif
        return Image(name, bundle: .module)
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

extension Color {
    fileprivate init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    fileprivate init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(dark) : UIColor(light)
            }
        )
        #elseif canImport(AppKit)
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                    ? NSColor(dark) : NSColor(light)
            }
        )
        #else
        self = light
        #endif
    }
}
