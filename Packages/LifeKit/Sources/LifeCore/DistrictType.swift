public enum DistrictType: String, CaseIterable, Codable, Sendable {
    case productivity, finance, health, spirituality, personal

    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}
