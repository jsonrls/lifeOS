import LifeCore
import SwiftUI

extension DistrictType {
    /// Navigator order, which is also ⌘2...⌘6.
    static let navigatorOrder: [DistrictType] = [.productivity, .finance, .health, .personal, .spirituality]
}

/// What the navigator lists, apart from the views. City Hall has no district, so it gets a fixed row.
enum NavigatorRows {
    enum Action: Equatable { case focus(DistrictType), goTo(String) }
    struct Row: Equatable { let title: String, label: String, action: Action, color: DistrictType?, indented: Bool }

    static func rows(focused: DistrictType?) -> [Row] {
        let hall = CityCatalog.cityHall
        var out = [Row(title: hall.name, label: "\(hall.name), \(hall.districtName)", action: .goTo(hall.id), color: nil, indented: false)]
        for d in DistrictType.navigatorOrder {
            out.append(Row(title: d.displayName, label: "\(d.displayName) district", action: .focus(d), color: d, indented: false))
            if focused == d {
                out += CityCatalog.buildings(in: d).map {
                    Row(title: $0.name, label: "\($0.name), \($0.districtName)", action: .goTo($0.id), color: nil, indented: true)
                }
            }
        }
        return out
    }
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
            ForEach(NavigatorRows.rows(focused: store.focusedDistrict), id: \.label) { r in
                row(r).padding(.leading, r.indented ? 18 : 0)
            }
        }
        .padding(8)
    }

    private func selected(_ r: NavigatorRows.Row) -> Bool {
        switch r.action {
        case .goTo(let id): store.selectedBuildingID == id
        case .focus(let d): store.focusedDistrict == d && store.selectedBuildingID == nil
        }
    }

    /// District rows announce whether their buildings are listed; other rows have no expanded state.
    private func expansion(_ r: NavigatorRows.Row) -> String {
        guard case .focus(let d) = r.action else { return "" }
        return store.focusedDistrict == d ? "expanded" : "collapsed"
    }

    private func perform(_ r: NavigatorRows.Row) {
        switch r.action {
        case .focus(let d): store.focus(d)
        case .goTo(let id): store.goTo(id)
        }
    }

    private func row(_ r: NavigatorRows.Row) -> some View {
        Button { perform(r) } label: {
            HStack(spacing: 8) {
                if let d = r.color { Circle().fill(d.color).frame(width: 9, height: 9) }
                Text(r.title).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .contentShape(.rect)
            .background(selected(r) ? Color.primary.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(r.label)
        .accessibilityAddTraits(selected(r) ? .isSelected : [])
        .accessibilityValue(expansion(r))
    }
}
