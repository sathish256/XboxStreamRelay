//
//  StatusHeaderView.swift
//  XboxStreamRelay
//

import SwiftUI

struct StatusHeaderView: View {
    let state: StreamState
    let isPreventingSleep: Bool
    let detectedIP: String?
    @State private var ipCopied = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Main status indicator
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: statusColor.opacity(0.6), radius: statusGlow ? 6 : 0)
                
                Text(statusLabel)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(statusColor)
                
                Spacer()
                
                // Sleep-prevention badge
                if isPreventingSleep {
                    Label("Sleep Blocked", systemImage: "moon.zzz.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }
            }
            
            Divider()
            
            // Detected local IP
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("Local IP:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(detectedIP ?? "Not detected")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(detectedIP != nil ? .primary : .secondary)
                
                Spacer()
                
                if let ip = detectedIP {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(ip, forType: .string)
                        ipCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            ipCopied = false
                        }
                    } label: {
                        Label(ipCopied ? "Copied!" : "Copy", systemImage: ipCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private var statusColor: Color {
        switch state {
        case .stopped:        return .secondary
        case .starting:       return .yellow
        case .listening:      return .blue
        case .streaming:      return .green
        case .error:          return .red
        }
    }
    
    private var statusGlow: Bool {
        switch state {
        case .listening, .streaming: return true
        default: return false
        }
    }
    
    private var statusLabel: String {
        switch state {
        case .stopped:                   return "Offline"
        case .starting:                  return "Starting..."
        case .listening(let port):       return "Listening on :\(port)"
        case .streaming(let dest):       return "Live → \(dest)"
        case .error(let msg):            return "Error: \(msg)"
        }
    }
}

