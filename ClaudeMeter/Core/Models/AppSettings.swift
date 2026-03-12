//
//  AppSettings.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation
import SwiftUI

// MARK: - Display Mode
enum DisplayMode: String, Codable, CaseIterable {
    case iconOnly = "Icon Only"
    case compact = "Compact"
    case detailed = "Detailed"
}

// MARK: - Color Scheme
enum AppColorScheme: String, Codable, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Card Type
enum CardType: String, Codable, CaseIterable, Identifiable {
    case fiveHour = "five_hour"
    case sevenDay = "seven_day"
    case opus = "opus"
    case sonnet = "sonnet"
    case extraUsage = "extra_usage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveHour: return "5-Hour Limit"
        case .sevenDay: return "7-Day Limit"
        case .opus: return "Opus Limit"
        case .sonnet: return "Sonnet Only"
        case .extraUsage: return "Extra Usage"
        }
    }

    var icon: String {
        switch self {
        case .fiveHour: return "clock"
        case .sevenDay: return "calendar"
        case .opus: return "sparkles"
        case .sonnet: return "music.note"
        case .extraUsage: return "creditcard"
        }
    }

    static let defaultOrder: [CardType] = [.fiveHour, .sevenDay, .opus, .sonnet, .extraUsage]
}

// MARK: - App Settings
struct AppSettings: Codable, Equatable {
    // Display
    var displayMode: DisplayMode = .compact
    var colorScheme: AppColorScheme = .auto
    var showInDock: Bool = false
    var showOpusLimit: Bool = true
    var cardOrder: [CardType] = CardType.defaultOrder

    // Polling
    var refreshInterval: Int = Constants.Settings.defaultRefreshInterval

    // Startup
    var launchAtLogin: Bool = false

    // Notifications
    var notifyAt: [Int] = Constants.Settings.defaultNotifyThresholds
    var notificationsEnabled: Bool = true

    // Web API Fallback (claude.ai session credentials)
    var webSessionKey: String = ""
    var webOrganizationId: String = ""

    // Computed property for backward compatibility
    var notifyAt90: Bool {
        get { notifyAt.contains(90) }
        set {
            if newValue && !notifyAt.contains(90) {
                notifyAt.append(90)
                notifyAt.sort()
            } else if !newValue {
                notifyAt.removeAll { $0 == 90 }
            }
        }
    }

    // Check if notification should be sent for a threshold
    func shouldNotify(at threshold: Int) -> Bool {
        return notificationsEnabled && notifyAt.contains(threshold)
    }

    // Get all enabled thresholds sorted
    var sortedThresholds: [Int] {
        return notifyAt.sorted()
    }
}

// MARK: - Settings Keys
extension AppSettings {
    static let userDefaultsKey = Constants.Settings.userDefaultsKey

    // Validation bounds
    private static let minRefreshInterval = Constants.Settings.minRefreshInterval
    private static let maxRefreshInterval = Constants.Settings.maxRefreshInterval

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              var settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        // Validate loaded settings
        settings.validate()
        return settings
    }

    func save() {
        var validatedSettings = self
        validatedSettings.validate()
        if let data = try? JSONEncoder().encode(validatedSettings) {
            UserDefaults.standard.set(data, forKey: AppSettings.userDefaultsKey)
        }
    }

    /// Validate and fix any out-of-bounds values
    mutating func validate() {
        // Validate refresh interval bounds
        refreshInterval = max(Self.minRefreshInterval, min(refreshInterval, Self.maxRefreshInterval))

        // Validate notification thresholds (must be between 0 and 100)
        notifyAt = notifyAt.filter { $0 > 0 && $0 <= 100 }.sorted()

        // Ensure at least default thresholds if empty
        if notifyAt.isEmpty {
            notifyAt = Constants.Settings.defaultNotifyThresholds
        }

        // Ensure card order contains all card types
        let allCards = Set(CardType.allCases)
        let currentCards = Set(cardOrder)
        if currentCards != allCards {
            // Add missing cards at the end
            let missing = CardType.defaultOrder.filter { !currentCards.contains($0) }
            // Remove duplicates/invalid
            cardOrder = cardOrder.filter { allCards.contains($0) }
            cardOrder.append(contentsOf: missing)
        }
    }
}
