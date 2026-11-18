//
//  NetworkHelper.swift
//  XboxStreamRelay
//

import Foundation
import SystemConfiguration

public struct NetworkHelper {
    
    /// Detects the active local IPv4 address (e.g. en0 for Wi-Fi or en1 for Ethernet)
    /// without accessing or storing MAC addresses.
    public static func getLocalIPv4Address() -> String? {
        var address: String?
        
        // Get list of all network interfaces on the local machine
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer {
            freeifaddrs(ifaddr)
        }
        
        var candidates: [(name: String, ip: String)] = []
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // Check for IPv4 family (AF_INET)
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                let flags = Int32(interface.ifa_flags)
                
                // Interface must be UP, RUNNING, and NOT a loopback interface
                let isUp = (flags & IFF_UP) == IFF_UP
                let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
                let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
                
                if isUp && isRunning && !isLoopback {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    ) == 0 {
                        let ip = String(cString: hostname)
                        // Ignore link-local addresses (169.254.x.x) and empty strings
                        if !ip.starts(with: "169.254.") && !ip.isEmpty {
                            candidates.append((name: name, ip: ip))
                        }
                    }
                }
            }
        }
        
        // Prioritize en0 (standard Wi-Fi on Mac) and en1 (Ethernet / second Wi-Fi)
        if let primary = candidates.first(where: { $0.name == "en0" }) {
            address = primary.ip
        } else if let secondary = candidates.first(where: { $0.name == "en1" }) {
            address = secondary.ip
        } else {
            address = candidates.first?.ip
        }
        
        return address
    }
    
    /// Generates the exact dnsmasq configuration lines for Twitch RTMP ingestion domain redirection
    public static func generateDnsmasqRules(for ipAddress: String) -> String {
        return """
        # XboxStreamRelay Twitch Ingest Redirection
        address=/live.twitch.tv/\(ipAddress)
        address=/ingest.global-contribute.live-video.net/\(ipAddress)
        """
    }
}

