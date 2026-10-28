//
//  SettingsView.swift
//  7Zip Preferences & Settings Screen
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var cacheClearedMessage: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                // General Settings
                Section(header: Text("General").foregroundColor(AppTheme.textSecondary)) {
                    Picker(NSLocalizedString("language", comment: ""), selection: $settings.language) {
                        Text(NSLocalizedString("lang_auto", comment: "")).tag("auto")
                        Text(NSLocalizedString("lang_en", comment: "")).tag("en")
                        Text(NSLocalizedString("lang_ru", comment: "")).tag("ru")
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    Picker(NSLocalizedString("overwrite_policy", comment: ""), selection: $settings.defaultOverwritePolicy) {
                        Text(NSLocalizedString("overwrite_ask", comment: "")).tag(0)
                        Text(NSLocalizedString("overwrite_replace", comment: "")).tag(1)
                        Text(NSLocalizedString("overwrite_skip", comment: "")).tag(2)
                        Text(NSLocalizedString("overwrite_rename", comment: "")).tag(3)
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    Picker(NSLocalizedString("default_preset", comment: ""), selection: $settings.defaultPresetName) {
                        Text("Fast").tag("Fast")
                        Text("Normal").tag("Normal")
                        Text("Maximum").tag("Maximum")
                        Text("Maximum + Encrypted").tag("MaxEncrypted")
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }
                .listRowBackground(AppTheme.cardBackground)

                // Memory & Storage
                Section(header: Text("Memory & Storage").foregroundColor(AppTheme.textSecondary)) {
                    HStack {
                        Text("Available Memory Budget")
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text(MemoryBudget.formattedAvailable())
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Toggle(NSLocalizedString("auto_clean_temp", comment: ""), isOn: $settings.autoCleanTemp)
                        .tint(AppTheme.accent)

                    Button(action: clearCache) {
                        HStack {
                            Text(cacheClearedMessage ? "Temporary files cleared!" : NSLocalizedString("clear_cache_now", comment: ""))
                                .foregroundColor(cacheClearedMessage ? AppTheme.success : AppTheme.accent)
                            Spacer()
                            Image(systemName: "trash")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                // Interface & Haptics
                Section(header: Text("Interface").foregroundColor(AppTheme.textSecondary)) {
                    Toggle(NSLocalizedString("show_hidden_files", comment: ""), isOn: $settings.showHiddenFiles)
                        .tint(AppTheme.accent)

                    Toggle(NSLocalizedString("size_display_format", comment: "") + " (\(settings.sizeBinaryMode ? "1024" : "1000"))", isOn: $settings.sizeBinaryMode)
                        .tint(AppTheme.accent)

                    Toggle(NSLocalizedString("haptic_feedback", comment: ""), isOn: $settings.enableHaptics)
                        .tint(AppTheme.accent)
                }
                .listRowBackground(AppTheme.cardBackground)

                // Developer Options
                Section(header: Text("Developer Options").foregroundColor(AppTheme.textSecondary)) {
                    Toggle(NSLocalizedString("dev_mode", comment: ""), isOn: $settings.developerMode)
                        .tint(AppTheme.accent)

                    if settings.developerMode {
                        Text(NSLocalizedString("dev_mode_desc", comment: ""))
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                // Tools Shortcuts
                Section(header: Text(NSLocalizedString("tab_tools", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    NavigationLink(destination: BenchmarkView()) {
                        Label(NSLocalizedString("benchmark_title", comment: ""), systemImage: "speedometer")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    NavigationLink(destination: HashCalculatorView()) {
                        Label(NSLocalizedString("hash_calc_title", comment: ""), systemImage: "number.square.fill")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                // About
                Section {
                    NavigationLink(destination: AboutView()) {
                        Label(NSLocalizedString("about_title", comment: ""), systemImage: "info.circle")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .listRowBackground(AppTheme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(NSLocalizedString("settings_title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }

    private func clearCache() {
        settings.clearTempCache()
        AppTheme.triggerHaptic(type: .success)
        cacheClearedMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            cacheClearedMessage = false
        }
    }
}
