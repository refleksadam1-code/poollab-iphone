import Foundation

// Eigenständige Zwei-Kugel-Physikdemo; keine Verbindung zu Drittanbieter-Spielen.
struct V2 {
    var x: Double
    var y: Double
    static let zero = V2(x: 0, y: 0)
    static func + (a: V2, b: V2) -> V2 { V2(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: V2, b: V2) -> V2 { V2(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: V2, s: Double) -> V2 { V2(x: a.x * s, y: a.y * s) }
    static func / (a: V2, s: Double) -> V2 { V2(x: a.x / s, y: a.y / s) }
    var length: Double { sqrt(x * x + y * y) }
    var normalized: V2 { length > 1e-9 ? self / length : V2(x: 1, y: 0) }
    func dot(_ b: V2) -> Double { x * b.x + y * b.y }
}

struct BallState {
    var p: V2
    var v: V2 = .zero
    var pocketed: Bool = false
}

struct Prediction {
    var end: V2
    var collides: Bool
    var afterImpact: V2?
}

struct PoolWorld {
    static let tableWidth = 1.0
    static let tableHeight = 0.55
    static let radius = 0.024
    static let pocketRadius = 0.037
    static let pockets: [V2] = [
        V2(x: 0, y: 0), V2(x: 0.5, y: 0), V2(x: 1, y: 0),
        V2(x: 0, y: 0.55), V2(x: 0.5, y: 0.55), V2(x: 1, y: 0.55)
    ]

    var cue = BallState(p: V2(x: 0.23, y: 0.36))
    var target = BallState(p: V2(x: 0.67, y: 0.31))
    var shots = 0

    var isMoving: Bool { cue.v.length > 0.003 || target.v.length > 0.003 }

    // Ghost-ball-Vorschlag für einen geraden Taschenstoß.
    func recommendedAngle() -> Double {
        if target.pocketed { return 0 }
        var best = target.p - cue.p
        var bestScore = Double.infinity
        for pocket in Self.pockets {
            let towardPocket = (pocket - target.p).normalized
            let ghost = target.p - towardPocket * (Self.radius * 2)
            guard ghost.x > Self.radius, ghost.x < 1 - Self.radius,
                  ghost.y > Self.radius, ghost.y < Self.tableHeight - Self.radius else { continue }
            let distance = (ghost - cue.p).length + (pocket - target.p).length * 0.3
            if distance < bestScore {
                bestScore = distance
                best = ghost - cue.p
            }
        }
        return atan2(best.y, best.x) * 180 / .pi
    }

    func prediction(angleDegrees: Double) -> Prediction {
        let a = angleDegrees * Double.pi / 180
        let dir = V2(x: cos(a), y: sin(a))
        let wall = wallHit(from: cue.p, direction: dir, r: Self.radius)
        guard !target.pocketed else { return Prediction(end: wall, collides: false, afterImpact: nil) }
        let towardBall = target.p - cue.p
        let projection = towardBall.dot(dir)
        let minDistance = Self.radius * 2
        let square = towardBall.dot(towardBall) - projection * projection
        let discriminant = minDistance * minDistance - square
        if projection > 0, discriminant >= 0 {
            let t = projection - sqrt(discriminant)
            if t >= 0, t < (wall - cue.p).length {
                let impact = cue.p + dir * t
                let normal = (target.p - impact).normalized
                let next = wallHit(from: target.p, direction: normal, r: Self.radius)
                return Prediction(end: impact, collides: true, afterImpact: next)
            }
        }
        return Prediction(end: wall, collides: false, afterImpact: nil)
    }

    func wallHit(from p: V2, direction: V2, r: Double) -> V2 {
        var times: [Double] = []
        if direction.x > 1e-8 { times.append((Self.tableWidth - r - p.x) / direction.x) }
        if direction.x < -1e-8 { times.append((r - p.x) / direction.x) }
        if direction.y > 1e-8 { times.append((Self.tableHeight - r - p.y) / direction.y) }
        if direction.y < -1e-8 { times.append((r - p.y) / direction.y) }
        let t = times.filter { $0 > 0 }.min() ?? 0
        return p + direction * t
    }

    mutating func shoot(angleDegrees: Double, power: Double) {
        guard !isMoving, !cue.pocketed else { return }
        shots += 1
        let rad = angleDegrees * Double.pi / 180
        cue.v = V2(x: cos(rad), y: sin(rad)) * (0.42 + power * 1.3)
    }

    mutating func tick(dt: Double) {
        cue.p = cue.p + cue.v * dt
        target.p = target.p + target.v * dt
        let friction = exp(-1.2 * dt)
        cue.v = cue.v * friction
        target.v = target.v * friction
        Self.bounce(&cue)
        Self.bounce(&target)

        if !cue.pocketed && !target.pocketed {
            let delta = target.p - cue.p
            let minDist = Self.radius * 2
            if delta.length > 1e-9 && delta.length < minDist {
                let n = delta.normalized
                let overlap = minDist - delta.length
                cue.p = cue.p - n * (overlap * 0.5)
                target.p = target.p + n * (overlap * 0.5)
                let closing = (cue.v - target.v).dot(n)
                if closing > 0 {
                    let impulse = n * (closing * 0.94)
                    cue.v = cue.v - impulse
                    target.v = target.v + impulse
                }
            }
        }
        if !target.pocketed && Self.pockets.contains(where: { ($0 - target.p).length < Self.pocketRadius }) {
            target.pocketed = true
            target.v = .zero
        }
        if !cue.pocketed && Self.pockets.contains(where: { ($0 - cue.p).length < Self.pocketRadius }) {
            cue.pocketed = true
            cue.v = .zero
        }
        if cue.v.length < 0.003 { cue.v = .zero }
        if target.v.length < 0.003 { target.v = .zero }
    }

    private static func bounce(_ ball: inout BallState) {
        guard !ball.pocketed else { return }
        let r = Self.radius
        if ball.p.x < r { ball.p.x = r; ball.v.x = abs(ball.v.x) * 0.84 }
        if ball.p.x > Self.tableWidth - r { ball.p.x = Self.tableWidth - r; ball.v.x = -abs(ball.v.x) * 0.84 }
        if ball.p.y < r { ball.p.y = r; ball.v.y = abs(ball.v.y) * 0.84 }
        if ball.p.y > Self.tableHeight - r { ball.p.y = Self.tableHeight - r; ball.v.y = -abs(ball.v.y) * 0.84 }
    }
}
