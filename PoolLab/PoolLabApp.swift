import SwiftUI
import CryptoKit

@main
struct PoolLabApp: App {
    var body: some Scene { WindowGroup { PoolHome().preferredColorScheme(.dark) } }
}

struct PoolHome: View {
    @AppStorage("poollab.key") private var licenseKey = ""
    @State private var input = ""
    @State private var world = PoolWorld()
    @State private var angle = -6.0
    @State private var power = 0.6
    @State private var aimLine = true
    @State private var prediction = true
    @State private var autoAim = true
    @State private var moving = false
    private let bg = Color(red: 0.045, green: 0.06, blue: 0.11)

    var unlocked: Bool { licenseKey == "POOLLAB-DEMO-2026" }
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text("POOL LAB").font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.cyan)
                    Text("Eigenständige Billard-Testumgebung").foregroundStyle(.secondary)
                    if !unlocked {
                        VStack(spacing: 12) {
                            Label("Demo-Key eingeben", systemImage: "key.fill")
                            TextField("Lizenz-Key", text: $input)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            Button("Freischalten") { if input == "POOLLAB-DEMO-2026" { licenseKey = input } }
                                .buttonStyle(.borderedProminent)
                            Text("Demo-Key: POOLLAB-DEMO-2026").font(.caption).foregroundStyle(.secondary)
                            Text("Dieser Demo-Key ist öffentlich und kein sicheres Lizenzsystem.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        table
                        VStack(spacing: 12) {
                            HStack { Text("Winkel"); Spacer(); Text("\(Int(angle))°") }
                            Slider(value: $angle, in: -180...180)
                            HStack { Text("Stoßkraft"); Spacer(); Text("\(Int(power * 100)) %") }
                            Slider(value: $power, in: 0.1...1)
                            HStack {
                                Button("Auto Aim") { angle = world.recommendedAngle() }
                                    .disabled(!autoAim || moving)
                                Spacer()
                                Button("Stoß") { shoot() }
                                    .disabled(moving || world.cue.pocketed || world.target.pocketed)
                            }.buttonStyle(.borderedProminent)
                            Button("Zurücksetzen") { world = PoolWorld(); angle = -6 }
                                .disabled(moving).buttonStyle(.bordered)
                        }.padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        VStack(spacing: 15) {
                            Toggle("Extended Aim Line", isOn: $aimLine)
                            Toggle("Ball Prediction", isOn: $prediction)
                            Toggle("Auto Aim aktiv", isOn: $autoAim)
                            Button("Demo-Key entfernen") { licenseKey = ""; input = "" }
                                .foregroundStyle(.red)
                        }.tint(.cyan).padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                    }
                    Text("Keine Modifikation von 8 Ball Pool und keine Spielfunktionen im Miniclip-Spiel.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(18)
            }
        }
    }

    private var table: some View {
        VStack(spacing: 8) {
            Text("Stöße: \(world.shots)").font(.caption).foregroundStyle(.secondary)
            Canvas { context, size in
                let w = size.width - 20.0
                let h = w * PoolWorld.tableHeight
                let origin = CGPoint(x: 10, y: (size.height - h) / 2)
                func loc(_ p: V2) -> CGPoint { CGPoint(x: origin.x + p.x * w, y: origin.y + p.y * w) }
                context.fill(Path(roundedRect: CGRect(x: origin.x, y: origin.y, width: w, height: h), cornerRadius: 12), with: .color(Color(red: 0.04, green: 0.32, blue: 0.27)))
                for p in PoolWorld.pockets {
                    let q = loc(p), r = w * PoolWorld.pocketRadius
                    context.fill(Path(ellipseIn: CGRect(x: q.x-r, y: q.y-r, width: 2*r, height: 2*r)), with: .color(.black))
                }
                if aimLine && !moving && !world.cue.pocketed {
                    let p = world.prediction(angleDegrees: angle)
                    var path = Path()
                    path.move(to: loc(world.cue.p)); path.addLine(to: loc(p.end))
                    context.stroke(path, with: .color(.cyan), style: StrokeStyle(lineWidth: 2, dash: [6,4]))
                    if prediction, let end = p.afterImpact {
                        var path = Path(); path.move(to: loc(world.target.p)); path.addLine(to: loc(end))
                        context.stroke(path, with: .color(.yellow), style: StrokeStyle(lineWidth: 2, dash: [6,4]))
                    }
                }
                func ball(_ b: BallState, _ color: Color) {
                    if b.pocketed { return }
                    let p = loc(b.p), r = w * PoolWorld.radius
                    context.fill(Path(ellipseIn: CGRect(x:p.x-r,y:p.y-r,width:2*r,height:2*r)), with: .color(color))
                }
                ball(world.target,.orange); ball(world.cue,.white)
            }.frame(height: 220)
            if world.target.pocketed { Text("Zielball versenkt!").foregroundStyle(.green) }
        }.padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }
    private func shoot() {
        guard !moving else { return }
        world.shoot(angleDegrees: angle, power: power)
        moving = true
        Task { @MainActor in
            for _ in 0..<360 {
                try? await Task.sleep(for: .milliseconds(17))
                world.tick(dt: 1.0/60.0)
                if !world.isMoving { break }
            }
            moving = false
        }
    }
}
