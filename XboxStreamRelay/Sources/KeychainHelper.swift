//
//  KeychainHelper.swift
//  XboxStreamRelay
//

import Foundation
import Security

/// Thread-safe helper for securely storing, retrieving, and deleting secrets
/// in the macOS Keychain using the Security framework.
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let serviceName = "com.xboxstreamrelay.app"
    private let youtubeStreamKeyAccount = "youtube_stream_key"
    
    private init() {}
    
    // MARK: - YouTube Stream Key API
    
    /// Saves or updates the YouTube Stream Key in the Keychain.
    @discardableResult
    public func saveYouTubeStreamKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        return save(account: youtubeStreamKeyAccount, data: data)
    }
    
    /// Retrieves the YouTube Stream Key from the Keychain.
    public func getYouTubeStreamKey() -> String? {
        guard let data = read(account: youtubeStreamKeyAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Deletes the YouTube Stream Key from the Keychain.
    @discardableResult
    public func deleteYouTubeStreamKey() -> Bool {
        return delete(account: youtubeStreamKeyAccount)
    }
    
    // MARK: - Generic Keychain Primitives
    
    private func save(account: String, data: Data) -> Bool {
        // Build query to find existing entry
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account
        ]
        
        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else if status == errSecItemNotFound {
            // Item does not exist; add new item
            var newItem = query
            newItem[kSecValueData] = data
            newItem[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            return addStatus == errSecSuccess
        } else {
            return false
        }
    }
    
    private func read(account: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    private func delete(account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

