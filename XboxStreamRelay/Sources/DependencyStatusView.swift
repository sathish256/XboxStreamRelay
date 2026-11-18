//
//  DependencyStatusView.swift
//  XboxStreamRelay
//

import SwiftUI

struct DependencyStatusView: View {
    let status: DependencyStatus
    let mode: RelayMode
    @State private var copied = false
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Homebrew Dependencies")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
                
                DependencyRow(
                    name: "mediamtx",
                    path: status.mediamtxPath,
                    required: true
                )
                DependencyRow(
                    name: "ffmpeg",
                    path: status.ffmpegPath,
                    required: mode == .directYouTube
                )
                DependencyRow(
                    name: "dnsmasq",
                    path: status.dnsmasqPath,
                    required: false
                )
                
                if !status.hasMediamtx || (mode == .directYouTube && !status.hasFfmpeg) {
                    Divider()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "terminal")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(DependencyChecker.homebrewInstallCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(DependencyChecker.homebrewInstallCommand, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .help("Copy install command")
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(6)
                }
            }
        }
    }
}

struct DependencyRow: View {
    let name: String
    let path: String?
    let required: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: path != nil ? "checkmark.circle.fill" : (required ? "xmark.circle.fill" : "minus.circle"))
                .foregroundColor(path != nil ? .green : (required ? .red : .secondary))
                .font(.caption)
            
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(required ? .semibold : .regular)
            
            Spacer()
            
            if let p = path {
                Text(p)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(required ? "not found" : "optional")
                    .font(.caption2)
                    .foregroundColor(required ? .red : .secondary)
            }
        }
    }
}

