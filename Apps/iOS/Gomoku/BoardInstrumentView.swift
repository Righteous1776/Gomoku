import SwiftUI

struct BoardInstrumentView: View {
    let board: [UInt8]
    let enabled: Bool
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let inset: CGFloat = 18
            let step = (side - inset * 2) / 14
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(red: 0.68, green: 0.61, blue: 0.48).gradient)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                Canvas { context, _ in
                    var lines = Path()
                    for i in 0..<15 {
                        let p = inset + CGFloat(i) * step
                        lines.move(to: CGPoint(x: p, y: inset))
                        lines.addLine(to: CGPoint(x: p, y: side - inset))
                        lines.move(to: CGPoint(x: inset, y: p))
                        lines.addLine(to: CGPoint(x: side - inset, y: p))
                    }
                    context.stroke(lines, with: .color(.black.opacity(0.55)), lineWidth: 0.75)
                    for r in [3, 7, 11] {
                        for c in [3, 7, 11] {
                            let point = CGPoint(x: inset + CGFloat(c) * step, y: inset + CGFloat(r) * step)
                            context.fill(Path(ellipseIn: CGRect(x: point.x-2.4, y: point.y-2.4, width: 4.8, height: 4.8)), with: .color(.black.opacity(0.8)))
                        }
                    }
                }
                ForEach(0..<225, id: \.self) { index in
                    let piece: UInt8 = index < board.count ? board[index] : 0
                    let x = inset + CGFloat(index % 15) * step
                    let y = inset + CGFloat(index / 15) * step
                    Button { onTap(index) } label: {
                        ZStack {
                            if piece != 0 {
                                Circle()
                                    .fill(piece == 1 ? Color(white: 0.09).gradient : Color(white: 0.95).gradient)
                                    .overlay(Circle().strokeBorder(piece == 1 ? .white.opacity(0.12) : .black.opacity(0.13)))
                                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                            } else { Circle().fill(.clear) }
                        }
                        .frame(width: step * 0.84, height: step * 0.84)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled || piece != 0)
                    .accessibilityLabel("Row \(index / 15 + 1), column \(index % 15 + 1), \(piece == 1 ? "black" : piece == 2 ? "white" : "empty")")
                    .position(x: x, y: y)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
