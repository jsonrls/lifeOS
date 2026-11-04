import AppKit
import LifeCore
import RealityKit

/// Trees share three meshes and a few materials.
@MainActor enum TreeKit {
    private static let trunk = MeshResource.generateCylinder(height: 0.5, radius: 0.07)
    private static let cone = MeshResource.generateCone(height: 1.0, radius: 0.4)
    private static let ball = MeshResource.generateSphere(radius: 0.45)

    /// Unit tree is 1.5 tall; `height` scales it uniformly.
    static func make(height: Float, variant: Int) -> Entity {
        let e = Entity()
        let leaf = Mat.matte(variant % 2 == 0 ? [0.30, 0.52, 0.30] : [0.38, 0.58, 0.32])
        let t = ModelEntity(mesh: trunk, materials: [Mat.matte([0.45, 0.33, 0.25])])
        t.position = [0, 0.25, 0]
        let crown = ModelEntity(mesh: variant % 3 == 0 ? ball : cone, materials: [leaf])
        crown.position = [0, variant % 3 == 0 ? 0.95 : 1.0, 0]
        e.addChild(t)
        e.addChild(crown)
        e.scale = .init(repeating: height / 1.5)
        return e
    }
}

@MainActor public enum CitySceneBuilder {
    private static let extent: Float = 28

    public static func makeScene() -> Entity {
        let scene = Entity()
        scene.name = "city"
        scene.addChild(ground())
        scene.addChild(roads())
        scene.addChild(plaza())
        for d in CityCatalog.buildings where d.district != nil {
            scene.addChild(BuildingFactory.makeEntity(for: d, accent: d.district?.accent))
        }
        scene.addChild(trees())
        for l in lights() { scene.addChild(l) }
        return scene
    }

    private static func slab(_ w: Float, _ h: Float, _ d: Float, x: Float, z: Float, top: Float,
                             _ m: PhysicallyBasedMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateBox(size: [w, h, d]), materials: [m])
        e.position = [x, top - h / 2, z]
        return e
    }

    private static func ground() -> Entity {
        let g = Entity()
        g.name = "ground"
        g.addChild(slab(extent * 2, 0.4, extent * 2, x: 0, z: 0, top: 0, Mat.matte([0.62, 0.70, 0.55])))
        for def in CityCatalog.districts {
            let b = def.bounds, c = b.center
            let tint = Mat.matte(0.88 * [0.62, 0.70, 0.55] + 0.12 * def.id.accent)
            g.addChild(slab(Float(b.width), 0.04, Float(b.depth), x: c.x, z: c.z, top: 0.02, tint))
        }
        return g
    }

    private static func roads() -> Entity {
        let r = Entity()
        r.name = "roads"
        let asphalt = Mat.matte([0.34, 0.35, 0.38]), len = extent * 2, w: Float = 4
        for p: Float in [-10, 10] {
            r.addChild(slab(len, 0.06, w, x: 0, z: p, top: 0.04, asphalt))
            r.addChild(slab(w, 0.06, len, x: p, z: 0, top: 0.04, asphalt))
        }
        return r
    }

    private static func plaza() -> Entity {
        let p = Entity()
        p.name = "plaza"
        let b = CityCatalog.plazaBounds
        p.addChild(slab(Float(b.width), 0.1, Float(b.depth), x: 0, z: 0, top: 0.08, Mat.matte([0.86, 0.83, 0.78])))
        p.addChild(BuildingFactory.makeEntity(for: CityCatalog.cityHall, accent: nil))
        // Progress monument: stepped plinth, obelisk, bronze tip.
        p.addChild(slab(1.6, 0.3, 1.6, x: 0, z: 5, top: 0.38, Mat.concrete))
        p.addChild(slab(0.7, 3.0, 0.7, x: 0, z: 5, top: 3.38, Mat.warmWhite))
        let tip = ModelEntity(mesh: .generateCone(height: 0.6, radius: 0.35), materials: [Mat.bronze])
        tip.position = [0, 3.68, 5]
        p.addChild(tip)
        return p
    }

    private static func trees() -> Entity {
        let t = Entity()
        t.name = "trees"
        var pts: [SIMD2<Float>] = []
        for def in CityCatalog.districts {  // 8 per district: corners + edge midpoints
            let b = def.bounds, x0 = Float(b.x) + 0.5, z0 = Float(b.z) + 0.5
            let x1 = Float(b.x + b.width) - 0.5, z1 = Float(b.z + b.depth) - 0.5
            let xm = (x0 + x1) / 2, zm = (z0 + z1) / 2
            pts += [[x0, z0], [xm, z0], [x1, z0], [x0, zm], [x1, zm], [x0, z1], [xm, z1], [x1, z1]]
        }
        pts += [[-6.3, -6.3], [6.3, -6.3], [-6.3, 6.3], [6.3, 6.3], [-6.3, 0], [6.3, 0]]  // plaza
        for (i, p) in pts.enumerated() {
            let tree = TreeKit.make(height: 1.8 + 0.3 * Float(i % 3), variant: i)
            tree.position = [p.x, 0, p.y]
            t.addChild(tree)
        }
        return t
    }

    private static func lights() -> [Entity] {
        let sun = DirectionalLight()
        sun.light.intensity = 2800
        sun.shadow = DirectionalLightComponent.Shadow()
        sun.look(at: .zero, from: [-30, 45, -25], relativeTo: nil)
        let fill = DirectionalLight()  // weak, shadowless ambient fill from the opposite side
        fill.light.intensity = 700
        fill.look(at: .zero, from: [30, 25, 30], relativeTo: nil)
        return [sun, fill]
    }
}
