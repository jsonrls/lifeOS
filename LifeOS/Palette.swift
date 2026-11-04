import CityEngine
import LifeCore
import SwiftUI

/// UI colors come from the 3D city's own `DistrictType.accent`, so chips match the buildings.
extension DistrictType {
    var color: Color {
        let a = accent
        return Color(.sRGB, red: Double(a.x), green: Double(a.y), blue: Double(a.z))
    }
}

extension BuildingDefinition {
    var districtName: String { district?.displayName ?? "Central Plaza" }
    var tint: Color { district?.color ?? Color(red: 0.72, green: 0.53, blue: 0.20) }  // City Hall bronze
}
