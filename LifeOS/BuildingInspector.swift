import LifeCore
import SwiftUI

/// Details for the selected building. Stats are placeholders until the life modules exist.
struct BuildingInspector: View {
    let building: BuildingDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(building.name).font(.title3.bold())
            Text(building.districtName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(building.tint.opacity(0.3), in: .capsule)
            LabeledContent("Feature", value: building.featureID).font(.callout)
            LabeledContent("Level", value: "Level 1 of \(building.maxLevel)").font(.callout)
            Divider()
            Text("Sample data").font(.caption).foregroundStyle(.secondary)
            LabeledContent("Activity", value: "12 this week").font(.callout)
            LabeledContent("Streak", value: "4 days").font(.callout)
            LabeledContent("Progress", value: "20%").font(.callout)
            Button("Open") { }
                .disabled(true)
                .help("Coming in a later phase")
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
    }
}
