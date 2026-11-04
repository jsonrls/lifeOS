import Foundation

public struct CameraStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults, key: String = "lifeos.camera") {
        self.defaults = defaults; self.key = key
    }

    public func load() -> CameraState {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(CameraState.self, from: data) else { return .cityView }
        return s == s.clamped() ? s : .cityView
    }

    public func save(_ s: CameraState) {
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: key) }
    }
}
