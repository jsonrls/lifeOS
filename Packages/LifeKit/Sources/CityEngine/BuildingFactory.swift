import AppKit
import LifeCore
import RealityKit

public extension DistrictType {
    /// Signage/trim color, linear RGB 0...1.
    var accent: SIMD3<Float> {
        switch self {
        case .productivity: [0.20, 0.45, 0.90]  // blue
        case .finance: [0.10, 0.65, 0.45]  // emerald
        case .health: [0.95, 0.40, 0.35]  // coral
        case .spirituality: [0.55, 0.35, 0.85]  // violet
        case .personal: [0.95, 0.60, 0.20]  // warm orange
        }
    }
}

/// Shared matte materials, one per color.
@MainActor enum Mat {
    private static var cache: [SIMD4<Float>: PhysicallyBasedMaterial] = [:]

    static func matte(_ c: SIMD3<Float>, roughness: Float = 0.9) -> PhysicallyBasedMaterial {
        let key = SIMD4(c, roughness)
        if let m = cache[key] { return m }
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1))
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: 0)
        cache[key] = m
        return m
    }

    static let concrete = matte([0.80, 0.78, 0.74])
    static let warmWhite = matte([0.90, 0.88, 0.83])
    static let brick = matte([0.72, 0.52, 0.42])
    static let roof = matte([0.36, 0.34, 0.36])
    static let glass = matte([0.50, 0.66, 0.76], roughness: 0.2)
    static let bronze = matte([0.55, 0.45, 0.30])
}

@MainActor public enum BuildingFactory {
    private struct Ctx {
        let w: Float, d: Float, h: Float
        let trim: PhysicallyBasedMaterial
    }

    public static func makeEntity(for def: BuildingDefinition, accent: SIMD3<Float>?) -> Entity {
        let root = Entity()
        root.name = Picking.entityName(for: def.id)
        let c = def.footprint.center
        root.position = [c.x, 0, c.z]
        // Inset so adjacent 6x6 footprints keep a visible gap.
        let ctx = Ctx(w: Float(def.footprint.width) - 1, d: Float(def.footprint.depth) - 1, h: def.heightUnits,
                      trim: accent.map { Mat.matte($0) } ?? Mat.bronze)
        switch def.style {
        case .tower: tower(root, ctx)
        case .slab: slab(root, ctx)
        case .steppedTower: steppedTower(root, ctx)
        case .dome: dome(root, ctx)
        case .pavilion: pavilion(root, ctx)
        case .pagoda: pagoda(root, ctx)
        case .gabled: gabled(root, ctx)
        case .campus: campus(root, ctx)
        case .hall: hall(root, ctx)
        case .garden: garden(root, ctx)
        }
        let size: SIMD3<Float> = [ctx.w, ctx.h, ctx.d]
        var collision = CollisionComponent(shapes: [.generateBox(size: size).offsetBy(translation: [0, ctx.h / 2, 0])])
        collision.filter = CollisionFilter(group: [], mask: [])  // pick-only, no physics
        root.components.set(collision)
        root.components.set(InputTargetComponent())
        return root
    }

    // MARK: primitives

    /// Box whose bottom face sits at `y`.
    private static func box(_ s: SIMD3<Float>, x: Float = 0, y: Float, z: Float = 0,
                            _ m: PhysicallyBasedMaterial) -> ModelEntity {
        let r = min(0.06, min(s.x, s.y, s.z) * 0.4)
        let e = ModelEntity(mesh: .generateBox(size: s, cornerRadius: r), materials: [m])
        e.position = [x, y + s.y / 2, z]
        return e
    }

    private static func cylinder(height: Float, radius: Float, x: Float = 0, y: Float, z: Float = 0,
                                 _ m: PhysicallyBasedMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [m])
        e.position = [x, y + height / 2, z]
        return e
    }

    /// Accent sign on the front (+z) face.
    private static func sign(_ c: Ctx, width: Float, y: Float, depth: Float) -> ModelEntity {
        box([width, 0.35, 0.08], y: y, z: depth / 2 + 0.03, c.trim)
    }

    // MARK: styles

    private static func tower(_ r: Entity, _ c: Ctx) {
        let podium: Float = min(1.2, c.h * 0.15), cap: Float = 0.3
        let sw = c.w * 0.7, sd = c.d * 0.7, shaft = c.h - podium - cap
        r.addChild(box([c.w, podium, c.d], y: 0, Mat.concrete))
        r.addChild(box([sw, shaft, sd], y: podium, Mat.glass))
        r.addChild(box([sw + 0.1, 0.18, sd + 0.1], y: podium + shaft - 0.3, c.trim))
        r.addChild(box([sw * 0.6, cap, sd * 0.6], y: c.h - cap, Mat.roof))
        r.addChild(sign(c, width: c.w * 0.5, y: podium * 0.35, depth: c.d))
    }

    private static func slab(_ r: Entity, _ c: Ctx) {
        let sd = c.d * 0.6
        r.addChild(box([c.w, c.h, sd], y: 0, Mat.concrete))
        r.addChild(box([c.w * 0.86, c.h * 0.7, 0.06], y: c.h * 0.12, z: sd / 2, Mat.glass))
        r.addChild(box([c.w + 0.1, 0.2, sd + 0.1], y: c.h - 0.2, c.trim))
        r.addChild(sign(c, width: c.w * 0.4, y: 0.2, depth: sd))
    }

    private static func steppedTower(_ r: Entity, _ c: Ctx) {
        let tiers: [(Float, Float)] = [(1.0, 0.5), (0.72, 0.3), (0.46, 0.2)]
        var y: Float = 0
        for (i, t) in tiers.enumerated() {
            let (w, d, h) = (c.w * t.0, c.d * t.0, c.h * t.1)
            r.addChild(box([w, h, d], y: y, i == 2 ? Mat.glass : Mat.warmWhite))
            r.addChild(box([w + 0.1, 0.15, d + 0.1], y: y + h - 0.15, c.trim))
            y += h
        }
        r.addChild(sign(c, width: c.w * 0.4, y: 0.3, depth: c.d))
    }

    private static func dome(_ r: Entity, _ c: Ctx) {
        let rad = min(c.w, c.d) * 0.45, baseH = c.h - rad
        r.addChild(cylinder(height: baseH, radius: rad, y: 0, Mat.warmWhite))
        r.addChild(cylinder(height: 0.2, radius: rad + 0.05, y: baseH - 0.3, c.trim))
        let ball = ModelEntity(mesh: .generateSphere(radius: rad), materials: [Mat.glass])
        ball.position = [0, baseH, 0]
        r.addChild(ball)
        r.addChild(sign(c, width: c.w * 0.4, y: 0.3, depth: rad * 2))
    }

    private static func pavilion(_ r: Entity, _ c: Ctx) {
        let roofT: Float = 0.3
        r.addChild(box([c.w, 0.2, c.d], y: 0, Mat.concrete))
        for sx: Float in [-1, 1] {
            for sz: Float in [-1, 1] {
                r.addChild(box([0.3, c.h - roofT - 0.2, 0.3], x: sx * (c.w / 2 - 0.4), y: 0.2,
                               z: sz * (c.d / 2 - 0.4), Mat.warmWhite))
            }
        }
        r.addChild(box([c.w, roofT, c.d], y: c.h - roofT, Mat.roof))
        r.addChild(box([c.w + 0.06, 0.1, c.d + 0.06], y: c.h - roofT - 0.1, c.trim))
    }

    private static func pagoda(_ r: Entity, _ c: Ctx) {
        let base: Float = 0.25, spire: Float = 0.8
        let th = (c.h - base - spire) / 3
        r.addChild(box([c.w, base, c.d], y: 0, Mat.concrete))
        for i in 0..<3 {
            let f = 0.62 - 0.14 * Float(i), y = base + Float(i) * th
            r.addChild(box([c.w * f, th - 0.2, c.d * f], y: y, Mat.brick))
            r.addChild(box([c.w * f + 1.0, 0.2, c.d * f + 1.0], y: y + th - 0.2, i == 0 ? c.trim : Mat.roof))
        }
        let top = ModelEntity(mesh: .generateCone(height: spire, radius: 0.22), materials: [c.trim])
        top.position = [0, c.h - spire / 2, 0]
        r.addChild(top)
    }

    private static func gabled(_ r: Entity, _ c: Ctx) {
        let bw = c.w * 0.8, bd = c.d * 0.7, wallH = c.h * 0.55, rise = c.h - wallH
        r.addChild(box([bw, wallH, bd], y: 0, Mat.warmWhite))
        let angle = atan2(rise, bw / 2), len = hypot(bw / 2, rise) + 0.1
        for side: Float in [-1, 1] {
            let slope = box([len, 0.15, bd + 0.3], x: side * bw / 4, y: wallH + rise / 2 - 0.1, Mat.roof)
            slope.orientation = simd_quatf(angle: -side * angle, axis: [0, 0, 1])
            r.addChild(slope)
        }
        r.addChild(box([0.7, wallH * 0.6, 0.08], x: -bw * 0.2, y: 0, z: bd / 2 + 0.02, c.trim))
    }

    private static func campus(_ r: Entity, _ c: Ctx) {
        r.addChild(box([c.w, 0.2, c.d], y: 0, Mat.concrete))
        r.addChild(box([c.w * 0.5, c.h, c.d * 0.42], x: -c.w * 0.22, y: 0.2, z: -c.d * 0.25, Mat.warmWhite))
        r.addChild(box([c.w * 0.42, c.h * 0.7, c.d * 0.5], x: c.w * 0.25, y: 0.2, z: c.d * 0.2, Mat.concrete))
        r.addChild(box([c.w * 0.5, 0.15, 0.7], x: 0, y: c.h * 0.4, z: -c.d * 0.02, Mat.glass))
        r.addChild(box([c.w * 0.5 + 0.1, 0.15, c.d * 0.42 + 0.1], x: -c.w * 0.22, y: c.h + 0.05, z: -c.d * 0.25, c.trim))
        r.addChild(sign(c, width: c.w * 0.3, y: 0.3, depth: c.d))
    }

    private static func hall(_ r: Entity, _ c: Ctx) {
        let step: Float = 0.3, tall = c.h >= 12
        let mh = tall ? c.h * 0.7 : c.h - 0.4
        r.addChild(box([c.w, step, c.d], y: 0, Mat.concrete))
        r.addChild(box([c.w * 0.9, mh - step, c.d * 0.75], y: step, z: -c.d * 0.08, Mat.warmWhite))
        for i in 0..<4 {
            let x = (Float(i) - 1.5) * c.w * 0.22
            r.addChild(cylinder(height: mh - step - 0.3, radius: 0.18, x: x, y: step, z: c.d * 0.36, Mat.warmWhite))
        }
        r.addChild(box([c.w, 0.3, c.d * 0.9], y: mh, z: -c.d * 0.02, Mat.roof))
        r.addChild(box([c.w + 0.05, 0.12, c.d * 0.9 + 0.05], y: mh - 0.12, z: -c.d * 0.02, c.trim))
        guard tall else { return }
        let towerH = c.h - mh - 0.3 - 1.0
        r.addChild(box([c.w * 0.3, towerH, c.d * 0.3], y: mh + 0.3, Mat.warmWhite))
        let spire = ModelEntity(mesh: .generateCone(height: 1.0, radius: c.w * 0.2), materials: [c.trim])
        spire.position = [0, c.h - 0.5, 0]
        r.addChild(spire)
    }

    private static func garden(_ r: Entity, _ c: Ctx) {
        r.addChild(box([c.w, 0.06, c.d], y: 0, Mat.matte([0.45, 0.62, 0.38])))
        let t: Float = 0.2, wh: Float = 0.5
        r.addChild(box([c.w, wh, t], y: 0, z: -(c.d - t) / 2, Mat.concrete))
        r.addChild(box([c.w, wh, t], y: 0, z: (c.d - t) / 2, Mat.concrete))
        r.addChild(box([t, wh, c.d - 2 * t], x: -(c.w - t) / 2, y: 0, Mat.concrete))
        r.addChild(box([t, wh, c.d - 2 * t], x: (c.w - t) / 2, y: 0, Mat.concrete))
        let spots: [SIMD2<Float>] = [[-1.4, -1.2], [1.3, -1.4], [0, 0.1], [-1.3, 1.3], [1.4, 1.2]]
        for (i, p) in spots.enumerated() {
            let tree = TreeKit.make(height: c.h * (0.7 + 0.1 * Float(i % 3)), variant: i)
            tree.position = [p.x, 0.06, p.y]
            r.addChild(tree)
        }
        r.addChild(sign(c, width: 1.2, y: 0.55, depth: c.d - 0.1))
    }
}
