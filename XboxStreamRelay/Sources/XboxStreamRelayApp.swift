//
//  XboxStreamRelayApp.swift
//  XboxStreamRelay
//

import SwiftUI

@main
struct XboxStreamRelayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}   // Disable New Window menu item
        }
        .defaultSize(width: 500, height: 640)
    }
}

// MARK: - App Delegate for clean process termination

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Ensure mediamtx process, temp file and sleep assertion
        // are all cleaned up before the app exits
        Task { @MainActor in
            StreamManager.shared.cleanupOnExit()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

