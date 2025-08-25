import SwiftUI

struct CaptureTheme {
    struct Palette {
        static let background = Color(hex: "#ffffff")
        static let primary = Color(hex: "#030213")
        static let foregroundLight = Color(hex: "#0") // unused placeholder for oklch
        static let card = Color(hex: "#ffffff")
        static let muted = Color(hex: "#ececf0")
        static let mutedForeground = Color(hex: "#717182")
        static let accent = Color(hex: "#e9ebef")
        static let border = Color.black.opacity(0.1)

        // Habit category colors
        static let fitness = Color(hex: "#ef4444")
        static let wellness = Color(hex: "#22c55e")
        static let learning = Color(hex: "#3b82f6")
        static let nutrition = Color(hex: "#f97316")
        static let productivity = Color(hex: "#8b5cf6")
        static let health = Color(hex: "#ec4899")
        static let social = Color(hex: "#eab308")
    }
    
    // Utility function to get consistent category colors from database color strings
    static func categoryColor(from colorString: String?) -> Color {
        guard let colorString = colorString else { return .gray }
        
        switch colorString.lowercased() {
        case "red", "fitness":
            return Palette.fitness
        case "green", "wellness":
            return Palette.wellness
        case "blue", "learning":
            return Palette.learning
        case "orange", "nutrition":
            return Palette.nutrition
        case "purple", "productivity":
            return Palette.productivity
        case "pink", "health":
            return Palette.health
        case "yellow", "social":
            return Palette.social
        default:
            return .gray
        }
    }

    struct Gradients {
        static let header = LinearGradient(
            colors: [Color(hex: "#ffffff"), Palette.accent.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static func categoryBackground(_ category: String) -> LinearGradient {
            switch category.lowercased() {
            case "fitness":
                return LinearGradient(colors: [Color(hex: "#fef2f2"), Color(hex: "#fee2e2")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "wellness":
                return LinearGradient(colors: [Color(hex: "#f8fdf9"), Color(hex: "#f0f9f0")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "learning":
                return LinearGradient(colors: [Color(hex: "#eff6ff"), Color(hex: "#dbeafe")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "nutrition":
                return LinearGradient(colors: [Color(hex: "#fff7ed"), Color(hex: "#fed7aa")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "productivity":
                return LinearGradient(colors: [Color(hex: "#faf5ff"), Color(hex: "#e9d5ff")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "health":
                return LinearGradient(colors: [Color(hex: "#fdf2f8"), Color(hex: "#fce7f3")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "social":
                return LinearGradient(colors: [Color(hex: "#fefce8"), Color(hex: "#fef3c7")], startPoint: .topLeading, endPoint: .bottomTrailing)
            default:
                return LinearGradient(colors: [Palette.card, Palette.accent.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    struct Typography {
        static func titleGradient() -> LinearGradient {
            LinearGradient(colors: [Palette.primary, Palette.mutedForeground.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .background(CaptureTheme.Palette.card)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(CaptureTheme.Palette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

extension Color {
    init(hex: String) {
        let r, g, b, a: Double
        var hexColor = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexColor.hasPrefix("#") {
            hexColor.removeFirst()
        }
        var hexNumber: UInt64 = 0
        if Scanner(string: hexColor).scanHexInt64(&hexNumber) {
            switch hexColor.count {
            case 8:
                r = Double((hexNumber & 0xff000000) >> 24) / 255
                g = Double((hexNumber & 0x00ff0000) >> 16) / 255
                b = Double((hexNumber & 0x0000ff00) >> 8) / 255
                a = Double(hexNumber & 0x000000ff) / 255
            case 6:
                r = Double((hexNumber & 0xff0000) >> 16) / 255
                g = Double((hexNumber & 0x00ff00) >> 8) / 255
                b = Double(hexNumber & 0x0000ff) / 255
                a = 1.0
            default:
                r = 0; g = 0; b = 0; a = 1
            }
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        } else {
            self = .clear
        }
    }
}
