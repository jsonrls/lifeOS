/// Maps catalog building ids to RealityKit entity names and back.
public enum Picking {
    static let prefix = "building:"

    public static func entityName(for buildingID: String) -> String { prefix + buildingID }

    public static func buildingID(fromEntityName name: String) -> String? {
        guard name.hasPrefix(prefix), name.count > prefix.count else { return nil }
        return String(name.dropFirst(prefix.count))
    }
}
