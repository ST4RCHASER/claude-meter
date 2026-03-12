//
//  GeneralSettingsView.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import SwiftUI
import ServiceManagement

// MARK: - General Settings
struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var launchAtLoginError: String?

    var body: some View {
        SettingsTabContainer {
            Form {
                Section {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { appState.settings.launchAtLogin },
                        set: { newValue in
                            appState.settings.launchAtLogin = newValue
                            toggleLaunchAtLogin(newValue)
                        }
                    ))
                    .help("Automatically start ClaudeMeter when you log in.")
                    .accessibilityLabel("Launch at Login")
                    .accessibilityHint("When enabled, ClaudeMeter will start automatically when you log in")

                    if let error = launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ColorTheme.red)
                            .accessibilityLabel("Error: \(error)")
                    }

                    Toggle("Show in Dock", isOn: Binding(
                        get: { appState.settings.showInDock },
                        set: { newValue in
                            appState.settings.showInDock = newValue
                            updateDockVisibility(newValue)
                        }
                    ))
                    .help("Show ClaudeMeter icon in the Dock.")
                    .accessibilityLabel("Show in Dock")
                    .accessibilityHint("When enabled, ClaudeMeter will appear in the Dock")

                    Picker("Refresh Interval", selection: $appState.settings.refreshInterval) {
                        Text("30 Seconds").tag(30)
                        Text("1 Minute").tag(60)
                        Text("2 Minutes").tag(120)
                        Text("5 Minutes").tag(300)
                    }
                    .accessibilityLabel("Refresh Interval")
                    .accessibilityHint("Choose how often to update usage data")
                }

                Section(header: Text("Display")) {
                    Toggle("Show Opus Limit", isOn: $appState.settings.showOpusLimit)
                        .help("Display Opus model usage limit in the usage view.")
                        .accessibilityLabel("Show Opus Limit")
                        .accessibilityHint("When enabled, shows the Opus model usage limit")
                }

                Section(header: Text("Card Order")) {
                    ForEach(appState.settings.cardOrder) { card in
                        HStack(spacing: 8) {
                            Image(systemName: card.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16)
                            Text(card.displayName)
                                .font(.caption)
                            Spacer()
                            VStack(spacing: 0) {
                                Button {
                                    moveCard(card, direction: .up)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .disabled(appState.settings.cardOrder.first == card)

                                Button {
                                    moveCard(card, direction: .down)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .disabled(appState.settings.cardOrder.last == card)
                            }
                        }
                    }
                }

                Section(header: Text("Web API Fallback")) {
                    TextField("Organization ID", text: $appState.settings.webOrganizationId)
                        .font(.caption)
                        .help("Your Claude organization UUID (from claude.ai URL)")

                    SecureField("Session Key", text: $appState.settings.webSessionKey)
                        .font(.caption)
                        .help("sessionKey cookie from claude.ai browser session")

                    Text("Used as backup when the OAuth API is rate limited.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollIndicators(.hidden)
        }
    }

    private enum MoveDirection { case up, down }

    private func moveCard(_ card: CardType, direction: MoveDirection) {
        guard let index = appState.settings.cardOrder.firstIndex(of: card) else { return }
        let newIndex = direction == .up ? index - 1 : index + 1
        guard newIndex >= 0, newIndex < appState.settings.cardOrder.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.settings.cardOrder.swapAt(index, newIndex)
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = "Failed to update: \(error.localizedDescription)"
            // Revert the setting on failure
            appState.settings.launchAtLogin = !enabled
        }
    }

    private func updateDockVisibility(_ showInDock: Bool) {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
