/// Tile layout: +x east, +z south. Plaza 14x14 at origin, 6-tile roads, districts 14x14.
public enum CityCatalog {
    public static let plazaBounds = TileRect(x: -7, z: -7, width: 14, depth: 14)

    public static let districts: [DistrictDefinition] = [
        .init(id: .spirituality, bounds: TileRect(x: -27, z: -27, width: 14, depth: 14)),
        .init(id: .productivity, bounds: TileRect(x: 13, z: -27, width: 14, depth: 14)),
        .init(id: .health, bounds: TileRect(x: -27, z: 13, width: 14, depth: 14)),
        .init(id: .finance, bounds: TileRect(x: 13, z: 13, width: 14, depth: 14)),
        .init(id: .personal, bounds: TileRect(x: -7, z: 13, width: 14, depth: 14)),
    ]

    public static let cityHall = BuildingDefinition(
        id: "city-hall", district: nil, name: "City Hall", featureID: "city-hall",
        footprint: TileRect(x: -3, z: -3, width: 6, depth: 6),
        heightUnits: 14, style: .hall, maxLevel: 5)

    // Each district holds a 2x2 grid of 6x6 footprints; slot 0..3 = NW, NE, SW, SE.
    private static func b(_ d: DistrictType, _ slug: String, _ name: String, _ slot: Int,
                          _ style: BuildingStyle, _ h: Float) -> BuildingDefinition {
        let o = districts.first { $0.id == d }!.bounds
        let id = "\(d.rawValue).\(slug)"
        return BuildingDefinition(
            id: id, district: d, name: name, featureID: id,
            footprint: TileRect(x: o.x + 1 + (slot % 2) * 6, z: o.z + 1 + (slot / 2) * 6, width: 6, depth: 6),
            heightUnits: h, style: style, maxLevel: 5)
    }

    public static let buildings: [BuildingDefinition] = [
        b(.productivity, "office-tower", "Office Tower", 0, .tower, 12),
        b(.productivity, "coworking-hub", "Co-working Hub", 1, .campus, 5),
        b(.productivity, "planning-center", "Planning Center", 2, .slab, 7),
        b(.productivity, "innovation-lab", "Innovation Lab", 3, .dome, 6),

        b(.finance, "central-bank", "Central Bank", 0, .hall, 8),
        b(.finance, "investment-tower", "Investment Tower", 1, .steppedTower, 11),
        b(.finance, "savings-building", "Savings Building", 2, .slab, 6),
        b(.finance, "marketplace", "Marketplace", 3, .pavilion, 4),

        b(.health, "medical-center", "Medical Center", 0, .campus, 7),
        b(.health, "fitness-center", "Fitness Center", 1, .hall, 5),
        b(.health, "nutrition-hub", "Nutrition Hub", 2, .gabled, 4),
        b(.health, "wellness-center", "Wellness Center", 3, .garden, 3),

        b(.spirituality, "sanctuary", "Sanctuary", 0, .pagoda, 10),
        b(.spirituality, "meditation-pavilion", "Meditation Pavilion", 1, .pavilion, 4),
        b(.spirituality, "reflection-garden", "Reflection Garden", 2, .garden, 3),
        b(.spirituality, "wisdom-hall", "Wisdom Hall", 3, .hall, 6),

        b(.personal, "personal-residence", "Personal Residence", 0, .gabled, 4),
        b(.personal, "family-house", "Family House", 1, .gabled, 5),
        b(.personal, "community-center", "Community Center", 2, .campus, 5),
        b(.personal, "life-administration-office", "Life Administration Office", 3, .slab, 6),

        cityHall,
    ]

    public static func building(id: String) -> BuildingDefinition? {
        buildings.first { $0.id == id }
    }

    public static func buildings(in district: DistrictType) -> [BuildingDefinition] {
        buildings.filter { $0.district == district }
    }
}
