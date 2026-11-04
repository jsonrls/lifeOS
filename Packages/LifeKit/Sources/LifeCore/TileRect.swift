/// Axis-aligned rectangle on the tile grid. x/z is the min corner.
public struct TileRect: Equatable, Hashable, Sendable {
    public var x, z, width, depth: Int

    public init(x: Int, z: Int, width: Int, depth: Int) {
        self.x = x; self.z = z; self.width = width; self.depth = depth
    }

    /// Touching edges do not intersect.
    public func intersects(_ o: TileRect) -> Bool {
        x < o.x + o.width && o.x < x + width && z < o.z + o.depth && o.z < z + depth
    }

    public func contains(_ o: TileRect) -> Bool {
        o.x >= x && o.z >= z && o.x + o.width <= x + width && o.z + o.depth <= z + depth
    }

    public var center: (x: Float, z: Float) {
        (Float(x) + Float(width) / 2, Float(z) + Float(depth) / 2)
    }
}
