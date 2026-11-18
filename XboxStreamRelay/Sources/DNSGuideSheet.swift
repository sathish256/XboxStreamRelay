//
//  DNSGuideSheet.swift
//  XboxStreamRelay
//

import SwiftUI

struct DNSGuideSheet: View {
    let detectedIP: String?
    @Environment(\.dismiss) private var dismiss
    @State private var dnsmasqCopied = false
    @State private var xboxDnsCopied = false
    
    private var localIP: String { detectedIP ?? "192.168.x.x" }
    
    private var dnsmasqRules: String {
        NetworkHelper.generateDnsmasqRules(for: localIP)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Xbox DNS Setup Guide")
                        .font(.headline)
                    Text("Route your Xbox's stream through this Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Step 1 — dnsmasq
                    StepView(number: 1, title: "Configure dnsmasq on This Mac") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add these rules to `/usr/local/etc/dnsmasq.conf` (Intel) or `/opt/homebrew/etc/dnsmasq.conf` (Apple Silicon):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(alignment: .top) {
                                Text(dnsmasqRules)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(Color.black.opacity(0.08))
                                    .cornerRadius(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(dnsmasqRules, forType: .string)
                                    dnsmasqCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        dnsmasqCopied = false
                                    }
                                } label: {
                                    Image(systemName: dnsmasqCopied ? "checkmark" : "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .padding(.top, 8)
                            }
                            
                            Text("Then restart dnsmasq:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("sudo brew services restart dnsmasq")
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color.black.opacity(0.08))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Step 2 — Sharing DNS
                    StepView(number: 2, title: "Enable Internet Sharing DNS on This Mac") {
                        VStack(alignment: .leading, spacing: 6) {
                            BulletItem(text: "Open System Settings → General → Sharing")
                            BulletItem(text: "Enable Internet Sharing from your internet connection to the network where your Xbox is connected")
                            BulletItem(text: "This Mac's IP (\(localIP)) will serve as the DNS resolver for your Xbox")
                        }
                    }
                    
                    // Step 3 — Xbox DNS
                    StepView(number: 3, title: "Set Xbox Custom DNS") {
                        VStack(alignment: .leading, spacing: 6) {
                            BulletItem(text: "On your Xbox: Settings → General → Network Settings → Advanced Settings → DNS Settings → Manual")
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Primary DNS", systemImage: "arrow.right.circle")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text(localIP)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(localIP, forType: .string)
                                    xboxDnsCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        xboxDnsCopied = false
                                    }
                                } label: {
                                    Label(xboxDnsCopied ? "Copied!" : "Copy IP", systemImage: xboxDnsCopied ? "checkmark" : "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    // Step 4 — Start relay
                    StepView(number: 4, title: "Start the Relay, then Broadcast on Xbox") {
                        VStack(alignment: .leading, spacing: 6) {
                            BulletItem(text: "Press Start Relay in this app")
                            BulletItem(text: "On your Xbox, start broadcasting to Twitch — the stream will be intercepted by this Mac via dnsmasq and routed through mediamtx")
                            BulletItem(text: "In Direct to YouTube mode, ffmpeg will re-stream it live to YouTube using your stored stream key")
                            BulletItem(text: "In OBS Local mode, connect OBS Media Source to rtmp://localhost:1935/live for local recording or further processing")
                        }
                    }
                    
                    // Note
                    GroupBox {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Your YouTube Stream Key is stored exclusively in the macOS Keychain and is never written to disk, logged, or transmitted in plain text.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 580)
    }
}

// MARK: - Sub-Components

struct StepView<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 22, height: 22)
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            content
                .padding(.leading, 30)
        }
    }
}

struct BulletItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

