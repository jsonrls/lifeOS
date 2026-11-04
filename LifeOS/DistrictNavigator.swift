import LifeCore
import SwiftUI

extension DistrictType {
    /// Navigator order, which is also ⌘2...⌘6.
    static let navigatorOrder: [DistrictType] = [.productivity, .finance, .health, .personal, .spirituality]
}

/// Districts on the left; the focused district lists its buildings.
struct DistrictNavigator: View {
    let store: CityStore

    var body: some View {
        ViewThatFits(in: .vertical) {
            list
            ScrollView { list }.scrollIndicators(.never)
        }
        .frame(width: 220)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(DistrictType.navigatorOrder, id: \.self) { d in
                row(d.displayName, color: d.color, selected: store.focusedDistrict == d && store.selectedBuildingID == nil,
                    label: "\(d.displayName) district") { store.focus(d) }
                if store.focusedDistrict == d {
                    ForEach(CityCatalog.buildings(in: d)) { b in
                        row(b.name, color: nil, selected: store.selectedBuildingID == b.id,
                            label: "\(b.name), \(b.districtName)") { store.goTo(b.id) }
                            .padding(.leading, 18)
                    }
                }
            }
        }
        .padding(8)
    }

    private func row(_ title: String, color: Color?, selected: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let color { Circle().fill(color).frame(width: 9, height: 9) }
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .contentShape(.rect)
            .background(selected ? Color.primary.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
