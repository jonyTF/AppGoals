import Foundation

struct MetricsConnection: Codable, Equatable {
    var provider: MetricsProvider
    var resourceID: String

    static func load(from defaults: UserDefaults = AppGroupConfig.defaults) -> MetricsConnection {
        if let data = defaults.data(forKey: AppGroupConfig.DefaultsKey.connection),
           let connection = try? JSONDecoder().decode(Self.self, from: data) {
            return connection
        }
        // Preserve credentials and goals from versions that only supported RevenueCat.
        return MetricsConnection(
            provider: .revenueCat,
            resourceID: defaults.string(forKey: AppGroupConfig.DefaultsKey.projectID) ?? ""
        )
    }

    func save(to defaults: UserDefaults = AppGroupConfig.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: AppGroupConfig.DefaultsKey.connection)
        defaults.removeObject(forKey: AppGroupConfig.DefaultsKey.projectID)
    }

    static func clear(from defaults: UserDefaults = AppGroupConfig.defaults) {
        defaults.removeObject(forKey: AppGroupConfig.DefaultsKey.connection)
        defaults.removeObject(forKey: AppGroupConfig.DefaultsKey.projectID)
    }
}
