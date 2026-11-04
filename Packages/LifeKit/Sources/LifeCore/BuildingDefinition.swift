public enum BuildingStyle: String, Sendable {
    case tower, slab, steppedTower, dome, pavilion, pagoda, gabled, campus, hall, garden
}

public struct BuildingDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    /// nil only for City Hall.
    public let district: DistrictType?
    public let name: String
    public let featureID: String
    public let footprint: TileRect
    public let heightUnits: Float
    public let style: BuildingStyle
    public let maxLevel: Int
}

public struct DistrictDefinition: Identifiable, Sendable {
    public let id: DistrictType
    public let bounds: TileRect
}
