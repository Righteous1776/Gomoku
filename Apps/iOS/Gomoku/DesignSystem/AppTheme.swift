import SwiftUI
import Foundation

/// VeilLink visual system.
///
/// The language is intentionally not "generic cyberpunk": near-black veils hide information,
/// identity is represented by deterministic local glyphs, warm metal only appears around trust
/// and action, and motion has three meanings only: Reveal, Transit and Resolve.
enum VeilTheme {
    private static var p: VeilThemePalette { VeilAppearanceController.shared.palette }
    static var background: Color { p.background }
    static var backgroundLift: Color { p.backgroundLift }
    static var elevated: Color { p.elevated }
    static var panel: Color { p.panel }
    static var panelSoft: Color { p.panelSoft }
    static var obsidian: Color { p.obsidian }
    static var veil: Color { p.veil }
    static var gold: Color { p.gold }
    static var goldBright: Color { p.goldBright }
    static var goldDeep: Color { p.goldDeep }
    static var mutedGold: Color { p.mutedGold }
    static var paleMetal: Color { p.paleMetal }
    static var text: Color { p.text }
    static var secondaryText: Color { p.secondaryText }
    static var tertiaryText: Color { p.tertiaryText }
    static var hairline: Color { p.hairline }
    /// Low-emphasis fills and strokes must invert with the active palette. Using translucent
    /// white directly made controls disappear in Day mode while looking correct at night.
    static var subtleFill: Color { text.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.045 : 0.060) }
    static var subtleFillStrong: Color { text.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.075 : 0.095) }
    static var subtleStroke: Color { text.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.105 : 0.125) }
    static var danger: Color { p.danger }
    static var success: Color { p.success }
    static var goldGradient: LinearGradient {
        VeilAppearanceController.shared.isPlainline
            ? LinearGradient(colors: [gold, gold], startPoint: .topLeading, endPoint: .bottomTrailing)
            : VeilAppearanceController.shared.isForge
            ? LinearGradient(colors: [goldBright, gold], startPoint: .leading, endPoint: .trailing)
            : VeilAppearanceController.shared.isIslet
            ? LinearGradient(colors: [goldBright, gold], startPoint: .topLeading, endPoint: .bottomTrailing)
            : VeilAppearanceController.shared.isAppleSoft
            ? LinearGradient(colors: [goldBright, gold], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [goldBright, gold, goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var metalGradient: LinearGradient {
        VeilAppearanceController.shared.isPlainline
            ? LinearGradient(colors: [panel, panel], startPoint: .topLeading, endPoint: .bottomTrailing)
            : VeilAppearanceController.shared.isForge
            ? LinearGradient(colors: [p.metalTop, panel, p.metalBottom], startPoint: .top, endPoint: .bottom)
            : VeilAppearanceController.shared.isIslet
            ? LinearGradient(colors: [panelSoft, panel], startPoint: .top, endPoint: .bottom)
            : VeilAppearanceController.shared.isAppleSoft
            ? LinearGradient(colors: [panelSoft, panel], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color.white.opacity(0.72), paleMetal, gold.opacity(0.78), goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var surfaceGradient: LinearGradient {
        VeilAppearanceController.shared.isPlainline
            ? LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)
            : VeilAppearanceController.shared.isForge
            ? LinearGradient(colors: [paleMetal.opacity(0.10), Color.clear], startPoint: .top, endPoint: .bottom)
            : VeilAppearanceController.shared.isIslet
            ? LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
            : VeilAppearanceController.shared.isAppleSoft
            ? LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.015)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color.white.opacity(0.040), Color.white.opacity(0.010)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var incomingBubbleGradient: LinearGradient { LinearGradient(colors: [panelSoft, panel, obsidian], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

/// Rhythm tokens: the 4pt baseline grid observed across the shipping surfaces. The visual
/// language itself is already tokenized (color/motion/shape); spacing and type were not, which
/// let one-off values (padding 9/13/14, font 9.5/10.5/13.5) drift between sibling components.
/// Additive layer: call sites migrate one by one so every adoption stays individually reviewable.
enum VeilSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
struct VeilPanelShape: Shape {
    var cut: CGFloat = 16
    var radius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        if VeilAppearanceController.shared.isAppleSoft {
            return RoundedRectangle(cornerRadius: max(18, radius * 2.4), style: .continuous).path(in: rect)
        }
        if VeilAppearanceController.shared.isInstrument {
            return RoundedRectangle(cornerRadius: max(12, radius * 1.8), style: .continuous).path(in: rect)
        }
        let c = min(cut, min(rect.width, rect.height) * 0.28)
        let r = min(VeilAppearanceController.shared.isForge ? 2 : radius, c * 0.7)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
