//
//  MainTabView.swift
//  7Zip Main Tabbed Navigation
//

import SwiftUI
import UIKit

public struct MainTabView: View {
    @State private var selectedTab: Int = 0

    public init() {
        // Enforce pure black tab bar styling
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.shadowColor = UIColor(red: 31/255.0, green: 31/255.0, blue: 31/255.0, alpha: 1.0)

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Archives
            ArchivesHomeView()
                .tabItem {
                    Label(NSLocalizedString("tab_archives", comment: ""), systemImage: "archivebox.fill")
                }
                .tag(0)

            // Tab 2: Tasks Queue
            TasksView()
                .tabItem {
                    Label(NSLocalizedString("tab_tasks", comment: ""), systemImage: "checklist")
                }
                .tag(1)

            // Tab 3: Settings
            SettingsView()
                .tabItem {
                    Label(NSLocalizedString("tab_settings", comment: ""), systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(AppTheme.accent)
        .preferredColorScheme(.dark)
    }
}
