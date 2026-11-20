import Combine
import SwiftUI
import UIKit

enum VeilColorMode: String, CaseIterable, Identifiable, Codable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var subtitle: String {
        switch self {
        case .automatic: return "跟随 iOS 外观"
        case .light: return "始终使用白天配色"
        case .dark: return "始终使用夜间配色"
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func resolvesDark(systemIsDark: Bool) -> Bool {
        switch self {
        case .automatic: return systemIsDark
        case .light: return false
        case .dark: return true
        }
    }
}

enum VeilAppearanceSelection: String, CaseIterable, Identifiable, Codable {
    case veilOriginal
    case appleSoft
    case instrumentAuto
    case forge
    case plainline
    case islet

    var id: String { rawValue }

    /// Experimental styles are gated behind an authorization row in Settings and stay
    /// out of the regular picker.
    var isExperimental: Bool { self == .plainline }

    /// The styles offered directly in the appearance picker.
    static var switchableCases: [VeilAppearanceSelection] { allCases.filter { !$0.isExperimental } }
    var title: String {
        switch self {
        case .veilOriginal: return "Veil 原生"
        case .appleSoft: return "Apple Soft"
        case .instrumentAuto: return "拟物仪器"
        case .forge: return "FORGE · 锻造"
        case .plainline: return "白描"
        case .islet: return "浮屿"
        }
    }
    var subtitle: String {
        switch self {
        case .veilOriginal: return "保留现有黑金、切角面板与 Veil 动效。"
        case .appleSoft: return "苹果式软质拟物；iOS 26 自动接入底层 Liquid Glass。"
        case .instrumentAuto: return "柔和仪器拟物；完整支持浅色、深色与跟随系统。"
        case .forge: return "工业硬核｜橙色控制台、金属切角面板与状态驱动的机械仪表。"
        case .plainline: return "极简字排版面：无材质无阴影，仅留白、发丝线与文字。"
        case .islet: return "深海极光上的浮岛：内容浮起，导航收成一枚罗经胶囊。"
        }
    }

    var previewSystemImage: String {
        switch self {
        case .veilOriginal: return "sparkles"
        case .appleSoft: return "circle.grid.2x2.fill"
        case .instrumentAuto: return "dial.medium.fill"
        case .forge: return "gearshape.2.fill"
        case .plainline: return "text.alignleft"
        case .islet: return "circle.hexagongrid"
        }
    }

    var previewSurfaceColor: Color {
        switch self {
        case .veilOriginal: return Color(red: 0.02, green: 0.02, blue: 0.03)
        case .appleSoft: return Color(red: 0.91, green: 0.93, blue: 0.97)
        case .instrumentAuto: return Color(red: 0.38, green: 0.38, blue: 0.40)
        case .forge: return Color(red: 0.085, green: 0.095, blue: 0.11)
        case .plainline: return Color(red: 0.96, green: 0.955, blue: 0.94)
        case .islet: return Color(red: 0.05, green: 0.09, blue: 0.14)
        }
    }
}

struct VeilThemePalette {
    let background: Color
    let backgroundLift: Color
    let elevated: Color
    let panel: Color
    let panelSoft: Color
    let obsidian: Color
    let veil: Color
    let gold: Color
    let goldBright: Color
    let goldDeep: Color
    let mutedGold: Color
    let paleMetal: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let hairline: Color
    let danger: Color
    let success: Color
    let metalTop: Color
    let metalBottom: Color
    let recess: Color
    let keycapTop: Color
    let keycapBottom: Color
    let indicator: Color
}

final class VeilAppearanceController: ObservableObject {
    @MainActor static let shared = VeilAppearanceController()
    private enum Key {
        static let colorMode = "appearance.color.mode.v1"
    }

    let selection: VeilAppearanceSelection = .instrumentAuto
    @Published var colorMode: VeilColorMode {
        didSet {
            UserDefaults.standard.set(colorMode.rawValue, forKey: Key.colorMode)
            synchronizeSystemAppearance()
        }
    }
    @Published private(set) var systemIsDark = true

    private init() {
        colorMode = UserDefaults.standard.string(forKey: Key.colorMode)
            .flatMap(VeilColorMode.init(rawValue:)) ?? .automatic
        systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        synchronizeSystemAppearance()
    }

    /// Environment updates are authoritative only in Auto mode. A forced Light/Dark mode must not
    /// be overwritten by an intermediate UIKit trait while a scene or lock screen is transitioning.
    func update(colorScheme: ColorScheme) {
        guard colorMode == .automatic else { return }
        let next = colorScheme == .dark
        if systemIsDark != next { systemIsDark = next }
    }

    func synchronizeSystemAppearance() {
        guard colorMode == .automatic else { return }
        let style = UITraitCollection.current.userInterfaceStyle
        guard style != .unspecified else { return }
        let next = style == .dark
        if systemIsDark != next { systemIsDark = next }
    }

    func setColorMode(_ mode: VeilColorMode) {
        guard colorMode != mode else { return }
        colorMode = mode
    }

    var preferredColorScheme: ColorScheme? { colorMode.preferredColorScheme }
    var isDarkAppearance: Bool { colorMode.resolvesDark(systemIsDark: systemIsDark) }
    var isInstrument: Bool { selection == .instrumentAuto }
    var isForge: Bool { selection == .forge }
    var isAppleSoft: Bool { selection == .appleSoft }
    var isPlainline: Bool { selection == .plainline }
    var isIslet: Bool { selection == .islet }
    var appearanceLabel: String {
        let phase = isDarkAppearance ? "NIGHT" : "DAY"
        switch selection {
        case .veilOriginal: return "VEIL ORIGINAL · \(phase)"
        case .appleSoft: return "APPLE SOFT · \(phase)"
        case .instrumentAuto: return "INSTRUMENT · \(phase)"
        case .forge: return "FORGE // \(phase)"
        case .plainline: return "PLAINLINE · \(phase)"
        case .islet: return "ISLET · \(phase)"
        }
    }

    var palette: VeilThemePalette {
        isDarkAppearance ? Self.instrumentNight : Self.instrumentDay
    }

    static let instrumentDay = VeilThemePalette(
        background: Color(red: 0.934, green: 0.931, blue: 0.910),
        backgroundLift: Color(red: 0.977, green: 0.974, blue: 0.958),
        elevated: Color(red: 0.910, green: 0.908, blue: 0.890),
        panel: Color(red: 0.882, green: 0.879, blue: 0.858),
        panelSoft: Color(red: 0.956, green: 0.953, blue: 0.936),
        obsidian: Color(red: 0.10, green: 0.10, blue: 0.105),
        veil: Color(red: 0.846, green: 0.842, blue: 0.820),
        gold: Color(red: 1.00, green: 0.38, blue: 0.10),
        goldBright: Color(red: 1.0, green: 0.47, blue: 0.14),
        goldDeep: Color(red: 0.72, green: 0.20, blue: 0.03),
        mutedGold: Color(red: 0.44, green: 0.40, blue: 0.34),
        paleMetal: Color(red: 0.92, green: 0.92, blue: 0.90),
        text: Color.black.opacity(0.88),
        secondaryText: Color.black.opacity(0.56),
        tertiaryText: Color.black.opacity(0.34),
        hairline: Color.black.opacity(0.085),
        danger: Color(red: 0.78, green: 0.08, blue: 0.06),
        success: Color(red: 0.10, green: 0.62, blue: 0.28),
        metalTop: Color(red: 0.970, green: 0.968, blue: 0.952),
        metalBottom: Color(red: 0.862, green: 0.858, blue: 0.838),
        recess: Color.black.opacity(0.16),
        keycapTop: Color(red: 0.968, green: 0.966, blue: 0.950),
        keycapBottom: Color(red: 0.884, green: 0.880, blue: 0.858),
        indicator: Color(red: 1.0, green: 0.28, blue: 0.03)
    )

    static let instrumentNight = VeilThemePalette(
        background: Color(red: 0.035, green: 0.036, blue: 0.038),
        backgroundLift: Color(red: 0.10, green: 0.10, blue: 0.105),
        elevated: Color(red: 0.12, green: 0.12, blue: 0.125),
        panel: Color(red: 0.16, green: 0.16, blue: 0.165),
        panelSoft: Color(red: 0.20, green: 0.20, blue: 0.205),
        obsidian: Color(red: 0.015, green: 0.015, blue: 0.018),
        veil: Color(red: 0.08, green: 0.08, blue: 0.085),
        gold: Color(red: 1.0, green: 0.34, blue: 0.05),
        goldBright: Color(red: 1.0, green: 0.50, blue: 0.12),
        goldDeep: Color(red: 0.55, green: 0.11, blue: 0.01),
        mutedGold: Color(red: 0.57, green: 0.51, blue: 0.43),
        paleMetal: Color(red: 0.72, green: 0.73, blue: 0.74),
        text: Color.white.opacity(0.93),
        secondaryText: Color.white.opacity(0.58),
        tertiaryText: Color.white.opacity(0.34),
        hairline: Color.white.opacity(0.10),
        danger: Color(red: 0.96, green: 0.18, blue: 0.12),
        success: Color(red: 0.18, green: 0.82, blue: 0.40),
        metalTop: Color(red: 0.25, green: 0.25, blue: 0.26),
        metalBottom: Color(red: 0.075, green: 0.075, blue: 0.08),
        recess: Color.black.opacity(0.65),
        keycapTop: Color(red: 0.27, green: 0.27, blue: 0.28),
        keycapBottom: Color(red: 0.10, green: 0.10, blue: 0.11),
        indicator: Color(red: 1.0, green: 0.31, blue: 0.04)
    )
}
