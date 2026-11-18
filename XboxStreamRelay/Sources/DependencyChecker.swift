//
//  DependencyChecker.swift
//  XboxStreamRelay
//

import Foundation

public struct DependencyStatus: Equatable {
    public let mediamtxPath: String?
    public let ffmpegPath: String?
    public let dnsmasqPath: String?
    
    public var hasMediamtx: Bool { mediamtxPath != nil }
    public var hasFfmpeg: Bool { ffmpegPath != nil }
    public var hasDnsmasq: Bool { dnsmasqPath != nil }
    
    public var isReadyForLocalMode: Bool { hasMediamtx }
    public var isReadyForDirectMode: Bool { hasMediamtx && hasFfmpeg }
}

public final class DependencyChecker {
    public static let shared = DependencyChecker()
    
    // Standard Homebrew binary paths on macOS (Apple Silicon vs Intel)
    // Note: dnsmasq installs to /sbin, not /bin, so both are included
    private let searchPaths = [
        "/opt/homebrew/bin",  // Apple Silicon Homebrew (mediamtx, ffmpeg)
        "/opt/homebrew/sbin", // Apple Silicon Homebrew (dnsmasq)
        "/usr/local/bin",     // Intel Homebrew (mediamtx, ffmpeg)
        "/usr/local/sbin",    // Intel Homebrew (dnsmasq)
        "/usr/bin",
        "/usr/sbin",
        "/bin",
        "/sbin"
    ]
    
    private init() {}
    
    public func checkDependencies() -> DependencyStatus {
        let mediamtx = findBinary(named: "mediamtx")
        let ffmpeg = findBinary(named: "ffmpeg")
        let dnsmasq = findBinary(named: "dnsmasq")
        
        return DependencyStatus(
            mediamtxPath: mediamtx,
            ffmpegPath: ffmpeg,
            dnsmasqPath: dnsmasq
        )
    }
    
    public func findBinary(named name: String) -> String? {
        let fm = FileManager.default
        for directory in searchPaths {
            let fullPath = (directory as NSString).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }
    
    public static let homebrewInstallCommand = "brew install mediamtx ffmpeg dnsmasq"
}

