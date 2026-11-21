import SwiftUI

struct VeilInstrumentBackground: View {
    @ObservedObject private var appearance = VeilAppearanceController.shared
    private var palette: VeilThemePalette { appearance.palette }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundLift, palette.background],
                startPoint: .top, endPoint: .bottomTrailing
            )
            // A restrained reflection of the machined bronze edge. Never
            // a moving particle field: no display-link, no hit interception.
            RadialGradient(
                colors: [palette.gold.opacity(appearance.isDarkAppearance ? 0.085 : 0.045),
                         Color.clear],
                center: .topTrailing,
                startRadius: 18,
                endRadius: 490
            )
            LinearGradient(
                colors: [Color.white.opacity(appearance.isDarkAppearance ? 0.025 : 0.30), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            Rectangle()
                .fill(Color.black.opacity(appearance.isDarkAppearance ? 0.11 : 0.025))
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct VeilInstrumentPlate<S: Shape>: View {
    @ObservedObject private var appearance = VeilAppearanceController.shared
    let shape: S
    var emphasized = false
    private var palette: VeilThemePalette { appearance.palette }

    var body: some View {
        shape
            .fill(LinearGradient(colors: [palette.metalTop, palette.metalBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(Color.white.opacity(appearance.isDarkAppearance ? 0.07 : 0.55), lineWidth: 0.8))
            .overlay(shape.stroke(Color.black.opacity(0.24), lineWidth: emphasized ? 1.3 : 0.7).padding(1))
            .shadow(
                color: Color.black.opacity(VeilMotionPolicy.allowsFullSpatialEffects ? (appearance.isDarkAppearance ? 0.46 : 0.26) : 0),
                radius: VeilMotionPolicy.allowsFullSpatialEffects ? (emphasized ? 12 : 7) : 0,
                x: 0,
                y: VeilMotionPolicy.allowsFullSpatialEffects ? (emphasized ? 8 : 4) : 0
            )
    }
}

struct VeilPhysicalButtonStyle: ButtonStyle {
    var accent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let palette = VeilAppearanceController.shared.palette
        configuration.label
            .foregroundColor(accent ? Color.white : palette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: accent ? [palette.goldBright, palette.goldDeep] : [palette.keycapTop, palette.keycapBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(configuration.isPressed ? 0.05 : 0.26), lineWidth: 0.8))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.32), lineWidth: 1).padding(2))
            .offset(y: configuration.isPressed && !reduceMotion ? 2.5 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .shadow(
                color: Color.black.opacity(VeilMotionPolicy.allowsFullSpatialEffects ? (configuration.isPressed ? 0.14 : 0.44) : 0),
                radius: VeilMotionPolicy.allowsFullSpatialEffects ? (configuration.isPressed ? 2 : 6) : 0,
                x: 0,
                y: VeilMotionPolicy.allowsFullSpatialEffects ? (configuration.isPressed ? 1 : 5) : 0
            )
            .animation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion), value: configuration.isPressed)
    }
}

struct VeilIndicatorLamp: View {
    let active: Bool
    var color: Color? = nil

    var body: some View {
        let c = color ?? VeilAppearanceController.shared.palette.indicator
        Circle()
            .fill(active ? c : Color.black.opacity(0.30))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.6))
            .shadow(
                color: active && VeilMotionPolicy.allowsFullSpatialEffects ? c.opacity(0.75) : .clear,
                radius: VeilMotionPolicy.allowsFullSpatialEffects ? 5 : 0
            )
    }
}

struct VeilSpeakerGrille: View {
    var columns = 9
    var rows = 6

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { _ in
                        Circle()
                            .fill(Color.black.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.66 : 0.55))
                            .frame(width: 3.6, height: 3.6)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct VeilLCDDisplay: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .opacity(0.55)
            Text(value)
                .font(.system(size: 19, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundColor(VeilAppearanceController.shared.isDarkAppearance ? Color(red: 0.71, green: 0.82, blue: 0.74) : Color(red: 0.12, green: 0.19, blue: 0.16))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VeilAppearanceController.shared.isDarkAppearance ? Color(red: 0.08, green: 0.10, blue: 0.09) : Color(red: 0.76, green: 0.80, blue: 0.74))
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.38), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.38), radius: 3, x: 0, y: 2)
    }
}

struct VeilAmbientBackground: View {
    var body: some View { VeilInstrumentBackground() }
}

extension View {
    func veilCard(emphasized: Bool = false) -> some View {
        padding(VeilSpacing.md)
            .background(VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: emphasized ? 22 : 18, style: .continuous),
                emphasized: emphasized
            ))
    }
}

enum VeilMotionPolicy {
    enum Semantic { case resolve }

    static var allowsFullSpatialEffects: Bool {
        let process = ProcessInfo.processInfo
        return !process.isLowPowerModeEnabled
            && process.thermalState != .serious && process.thermalState != .critical
    }

    static func animation(_ semantic: Semantic, reduceMotionRequested: Bool) -> Animation? {
        guard !reduceMotionRequested else { return nil }
        return allowsFullSpatialEffects
            ? .spring(response: 0.42, dampingFraction: 0.72)
            : .easeOut(duration: 0.18)
    }
}
