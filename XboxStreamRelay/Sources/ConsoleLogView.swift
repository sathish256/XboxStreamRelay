//
//  ConsoleLogView.swift
//  XboxStreamRelay
//

import SwiftUI

struct ConsoleLogView: View {
    let logs: [LogEntry]
    let onClear: () -> Void
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                // Header bar
                HStack {
                    Label("Console", systemImage: "terminal.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(logs.count) lines")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .help("Clear logs")
                }
                .padding(.bottom, 6)
                
                Divider()
                
                // Auto-scrolling log area
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(logs) { entry in
                                LogLineView(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(6)
                    }
                    .frame(minHeight: 160, maxHeight: 220)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(6)
                    .onChange(of: logs.count) { _ in
                        if let last = logs.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct LogLineView: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.formattedTimestamp)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(entry.message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(entry.isError ? .red.opacity(0.9) : .green.opacity(0.9))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

