//
//  GoalStore.swift
//  AppGoals
//
//  Persists the single active goal in the shared App Group container so both
//  the app and the widget can read it.
//

import Foundation

enum GoalStore {
    static func load() -> Goal? {
        guard let data = AppGroupConfig.defaults.data(forKey: AppGroupConfig.DefaultsKey.goal) else {
            return nil
        }
        return try? JSONDecoder().decode(Goal.self, from: data)
    }

    static func save(_ goal: Goal) {
        guard let data = try? JSONEncoder().encode(goal) else { return }
        AppGroupConfig.defaults.set(data, forKey: AppGroupConfig.DefaultsKey.goal)
    }

    static func clear() {
        AppGroupConfig.defaults.removeObject(forKey: AppGroupConfig.DefaultsKey.goal)
    }
}
