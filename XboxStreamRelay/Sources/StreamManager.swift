//
//  StreamManager.swift
//  XboxStreamRelay
//

import Foundation
import AppKit
import IOKit.pwr_mgt
import Combine

public enum RelayMode: String, CaseIterable, Identifiable {
    case directYouTube = "Direct to YouTube"
    case localOBS = "OBS Studio Local"
    
    public var id: String { rawValue }
}

public enum StreamState: Equatable {
    case stopped
    case starting
    case listening(port: Int)
    case streaming(destination: String)
    case error(String)
    
    public var isRunning: Bool {
        switch self {
        case .starting, .listening, .streaming:
            return true
        case .stopped, .error:
            return false
        }
    }
}

public struct LogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let message: String
    public let isError: Bool
    
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

@MainActor
public final class StreamManager: ObservableObject {
    public static let shared = StreamManager()
    
    @Published public var state: StreamState = .stopped
    @Published public var logs: [LogEntry] = []
    @Published public var isPreventingSleep: Bool = false
    @Published public var selectedMode: RelayMode = .directYouTube
    @Published public var dependencyStatus: DependencyStatus
    @Published public var detectedIP: String?
    
    // Process management
    private var process: Process?
    private var tempConfigFileURL: URL?
    private var sleepAssertionID: IOPMAssertionID = 0
    private var activeStreamKey: String?
    
    // Logging queue
    private let logQueue = DispatchQueue(label: "com.xboxstreamrelay.logqueue")
    
    private init() {
        self.dependencyStatus = DependencyChecker.shared.checkDependencies()
        self.detectedIP = NetworkHelper.getLocalIPv4Address()
        
        // Listen to system termination notification
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.cleanupOnExit()
            }
        }
    }
    
    public func refreshEnvironment() {
        self.dependencyStatus = DependencyChecker.shared.checkDependencies()
        self.detectedIP = NetworkHelper.getLocalIPv4Address()
    }
    
    // MARK: - Relay Lifecycle
    
    public func startRelay(streamKey: String? = nil) {
        guard !state.isRunning else { return }
        
        refreshEnvironment()
        
        guard let mediamtxPath = dependencyStatus.mediamtxPath else {
            appendLog("Error: mediamtx binary not found. Please install via Homebrew.", isError: true)
            state = .error("mediamtx not found")
            return
        }
        
        if selectedMode == .directYouTube {
            guard let _ = dependencyStatus.ffmpegPath else {
                appendLog("Error: ffmpeg binary not found. Required for Direct to YouTube mode.", isError: true)
                state = .error("ffmpeg not found")
                return
            }
            guard let key = streamKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                appendLog("Error: YouTube Stream Key is missing. Please provide it in settings.", isError: true)
                state = .error("Missing Stream Key")
                return
            }
            self.activeStreamKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.activeStreamKey = nil
        }
        
        state = .starting
        appendLog("Preparing configuration for \(selectedMode.rawValue) mode...")
        
        // 1. Generate temp mediamtx config file
        do {
            let configURL = try createTempConfigFile()
            self.tempConfigFileURL = configURL
            appendLog("Generated secure configuration in temporary directory.")
        } catch {
            appendLog("Failed to create temporary configuration: \(error.localizedDescription)", isError: true)
            state = .error("Configuration creation failed")
            return
        }
        
        guard let configPath = tempConfigFileURL?.path else { return }
        
        // 2. Prevent sleep assertion
        preventSleep()
        
        // 3. Launch Process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: mediamtxPath)
        proc.arguments = [configPath]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        proc.standardOutput = outputPipe
        proc.standardError = errorPipe
        
        proc.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.appendLog("mediamtx process terminated with code \(p.terminationStatus).")
                self.stopRelay()
            }
        }
        
        self.process = proc
        
        // Read pipes asynchronously
        readPipe(outputPipe, isError: false)
        readPipe(errorPipe, isError: true)
        
        do {
            try proc.run()
            state = .listening(port: 1935)
            appendLog("mediamtx listening on RTMP port 1935 (PID: \(proc.processIdentifier)).")
            if selectedMode == .directYouTube {
                appendLog("Relay armed: stream will automatically forward to YouTube when Xbox begins broadcasting.")
            } else {
                appendLog("Relay armed: OBS can connect to rtmp://localhost:1935/live once streaming.")
            }
        } catch {
            appendLog("Failed to start mediamtx process: \(error.localizedDescription)", isError: true)
            state = .error("Process execution failed")
            stopRelay()
        }
    }
    
    public func stopRelay() {
        // Terminate process off main thread to avoid blocking UI
        if let proc = process, proc.isRunning {
            proc.terminationHandler = nil
            proc.terminate()
            DispatchQueue.global(qos: .utility).async {
                proc.waitUntilExit()
            }
            appendLog("mediamtx process stopped.")
        }
        process = nil
        
        // Clean up temporary config file
        cleanupTempFile()
        
        // Release sleep assertion
        releaseSleep()
        
        activeStreamKey = nil
        state = .stopped
    }
    
    public func cleanupOnExit() {
        if let proc = process, proc.isRunning {
            proc.terminationHandler = nil
            proc.terminate()
        }
        process = nil
        cleanupTempFile()
        releaseSleep()
    }
    
    // MARK: - Config File Generation
    
    private func createTempConfigFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "mediamtx_\(UUID().uuidString).yml"
        let fileURL = tempDir.appendingPathComponent(uniqueName)
        
        // Build a clean, correctly-indented mediamtx YAML config.
        // runOnReady is placed inside the path block, not at root level.
        var yaml: String
        
        if selectedMode == .directYouTube,
           let streamKey = activeStreamKey,
           let ffmpeg = dependencyStatus.ffmpegPath {
            // ffmpeg re-streams to YouTube when Xbox starts publishing
            let ffmpegCommand = "\(ffmpeg) -i rtmp://localhost:1935/$MTX_PATH -c copy -f flv rtmp://a.rtmp.youtube.com/live2/\(streamKey)"
            yaml = """
            # XboxStreamRelay dynamic temporary configuration — Direct to YouTube
            # Auto-generated at runtime — deleted on stop
            api: no
            metrics: no
            rtsp: no
            hls: no
            webrtc: no
            srt: no
            rtmp: yes
            rtmpAddress: :1935
            paths:
              all:
                runOnAvailable: \(ffmpegCommand)
                runOnAvailableRestart: yes
            """
        } else {
            yaml = """
            # XboxStreamRelay dynamic temporary configuration — OBS Local Relay
            # Auto-generated at runtime — deleted on stop
            api: no
            metrics: no
            rtsp: no
            hls: no
            webrtc: no
            srt: no
            rtmp: yes
            rtmpAddress: :1935
            paths:
              all:
            """
        }
        
        try yaml.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func cleanupTempFile() {
        if let url = tempConfigFileURL {
            try? FileManager.default.removeItem(at: url)
            tempConfigFileURL = nil
        }
    }
    
    // MARK: - Sleep Assertion (IOKit)
    
    private func preventSleep() {
        guard !isPreventingSleep else { return }
        
        let reason = "XboxStreamRelay is actively streaming game capture" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &sleepAssertionID
        )
        
        if success == kIOReturnSuccess {
            isPreventingSleep = true
            appendLog("Sleep prevention assertion active (Mac idle sleep disabled).")
        } else {
            appendLog("Warning: Could not enable sleep prevention assertion.", isError: true)
        }
    }
    
    private func releaseSleep() {
        if isPreventingSleep {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
            isPreventingSleep = false
            appendLog("Sleep prevention assertion released.")
        }
    }
    
    // MARK: - Output & Logging (With Stream Key Redaction)
    
    private func readPipe(_ pipe: Pipe, isError: Bool) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let rawString = String(data: data, encoding: .utf8) else { return }
            
            let lines = rawString.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // State detection based on mediamtx log output
                    // "is publishing to path" triggers when Xbox starts streaming
                    if trimmed.contains("is publishing to path") || trimmed.contains("started publishing to path") {
                        if self.selectedMode == .directYouTube {
                            self.state = .streaming(destination: "YouTube Live")
                        } else {
                            self.state = .streaming(destination: "Local OBS Relay")
                        }
                    } else if (trimmed.contains("stopped publishing") || trimmed.contains("closed")) && self.state.isRunning {
                        self.state = .listening(port: 1935)
                    }
                    
                    self.appendLog(trimmed, isError: isError)
                }
            }
        }
    }
    
    public func appendLog(_ rawMessage: String, isError: Bool = false) {
        var sanitized = rawMessage
        
        // Strictly redact active stream key if present
        if let key = activeStreamKey, !key.isEmpty {
            sanitized = sanitized.replacingOccurrences(of: key, with: "••••••••••••")
        }
        
        // Also redact any potential stream keys saved in Keychain if accessible
        if let savedKey = KeychainHelper.shared.getYouTubeStreamKey(), !savedKey.isEmpty {
            sanitized = sanitized.replacingOccurrences(of: savedKey, with: "••••••••••••")
        }
        
        let entry = LogEntry(timestamp: Date(), message: sanitized, isError: isError)
        logs.append(entry)
        
        // Cap logs at 500 lines to preserve memory
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }
    
    public func clearLogs() {
        logs.removeAll()
    }
}

