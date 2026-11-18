//
//  ContentView.swift
//  XboxStreamRelay
//

import SwiftUI

struct ContentView: View {
    @StateObject private var manager = StreamManager.shared
    
    // Stream key — only held in @State while the SecureField is open for editing.
    // On save it goes straight to Keychain and this is cleared.
    @State private var streamKeyInput: String = ""
    @State private var savedKeyCharCount: Int = 0   // display hint only — not the key itself
    @State private var showDNSGuide = false
    @State private var showStreamKeyField = false
    @State private var keySaved = false
    @State private var localRTMPCopied = false
    
    private var localRTMPAddress: String {
        "rtmp://localhost:1935/live"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("XboxStreamRelay")
                        .font(.headline)
                    Text("RTMP Relay for Xbox One / Series X|S")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showDNSGuide.toggle()
                } label: {
                    Label("Xbox DNS Guide", systemImage: "questionmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // ── Scrollable Body ───────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // Status Header
                    StatusHeaderView(
                        state: manager.state,
                        isPreventingSleep: manager.isPreventingSleep,
                        detectedIP: manager.detectedIP
                    )
                    
                    // Mode Selector
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Relay Mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Mode", selection: $manager.selectedMode) {
                                ForEach(RelayMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(manager.state.isRunning)
                            
                            Group {
                                switch manager.selectedMode {
                                case .directYouTube:
                                    Label("Xbox stream → This Mac → YouTube Live (via ffmpeg)", systemImage: "arrow.right.circle")
                                case .localOBS:
                                    Label("Xbox stream → This Mac → OBS Studio (manual forward)", systemImage: "record.circle")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // Stream Key (Direct YouTube mode only)
                    if manager.selectedMode == .directYouTube {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("YouTube Stream Key", systemImage: "key.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("Stored in Keychain")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                
                                HStack {
                                    if showStreamKeyField {
                                        SecureField("xxxx-xxxx-xxxx-xxxx-xxxx", text: $streamKeyInput)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.caption, design: .monospaced))
                                    } else {
                                        Text(savedKeyCharCount == 0 ? "No key saved — click Edit to enter" : "Key saved (\(savedKeyCharCount) chars)")
                                            .font(.caption)
                                            .foregroundColor(savedKeyCharCount == 0 ? .secondary : .primary)
                                        Spacer()
                                    }
                                    
                                    Button(showStreamKeyField ? "Save" : "Edit") {
                                        if showStreamKeyField {
                                            let trimmed = streamKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !trimmed.isEmpty {
                                                KeychainHelper.shared.saveYouTubeStreamKey(trimmed)
                                                savedKeyCharCount = trimmed.count
                                                keySaved = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                    keySaved = false
                                                }
                                            }
                                            // Clear the in-memory key — Keychain is the only store
                                            streamKeyInput = ""
                                            showStreamKeyField = false
                                        } else {
                                            showStreamKeyField = true
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(manager.state.isRunning)
                                    
                                    if savedKeyCharCount > 0 && !showStreamKeyField {
                                        Button {
                                            streamKeyInput = ""
                                            savedKeyCharCount = 0
                                            KeychainHelper.shared.deleteYouTubeStreamKey()
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                        .controlSize(.small)
                                        .foregroundColor(.red)
                                        .disabled(manager.state.isRunning)
                                        .help("Delete saved stream key")
                                    }
                                }
                                
                                if keySaved {
                                    Label("Stream key saved to Keychain", systemImage: "checkmark.shield")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    
                    // OBS RTMP address (Local OBS mode)
                    if manager.selectedMode == .localOBS {
                        GroupBox {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("OBS Media Source URL")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(localRTMPAddress)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                
                                Spacer()
                                
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(localRTMPAddress, forType: .string)
                                    localRTMPCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        localRTMPCopied = false
                                    }
                                } label: {
                                    Label(localRTMPCopied ? "Copied!" : "Copy", systemImage: localRTMPCopied ? "checkmark" : "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    // Dependency Status
                    DependencyStatusView(status: manager.dependencyStatus, mode: manager.selectedMode)
                    
                    // Start / Stop button
                    startStopButton
                    
                    // Console Log
                    ConsoleLogView(logs: manager.logs) {
                        manager.clearLogs()
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500)
        .frame(minHeight: 580, maxHeight: 700)
        .onAppear {
            // Only load character count — never the actual key into plain @State
            if let key = KeychainHelper.shared.getYouTubeStreamKey(), !key.isEmpty {
                savedKeyCharCount = key.count
            }
        }
        .sheet(isPresented: $showDNSGuide) {
            DNSGuideSheet(detectedIP: manager.detectedIP)
        }
    }
    
    // MARK: - Start / Stop Button
    
    @ViewBuilder
    private var startStopButton: some View {
        let canStart: Bool = {
            switch manager.selectedMode {
            case .directYouTube:
                // Key must be saved in Keychain (savedKeyCharCount > 0) + binaries present
                return manager.dependencyStatus.isReadyForDirectMode && savedKeyCharCount > 0
            case .localOBS:
                return manager.dependencyStatus.isReadyForLocalMode
            }
        }()
        
        Button {
            if manager.state.isRunning {
                manager.stopRelay()
            } else {
                let key = KeychainHelper.shared.getYouTubeStreamKey()
                manager.startRelay(streamKey: key)
            }
        } label: {
            HStack {
                Image(systemName: manager.state.isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title3)
                Text(manager.state.isRunning ? "Stop Relay" : "Start Relay")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(manager.state.isRunning ? .red : .accentColor)
        .disabled(manager.state == .starting || (!manager.state.isRunning && !canStart))
        .help(canStart ? "" : "Install missing dependencies and add a stream key first")
    }
}

