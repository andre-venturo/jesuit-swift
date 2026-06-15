//
//  TokenKeychainActorExtenstion.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Foundation

extension TokenKeychainActor {
    func setString(_ string: String, forKey key: String) throws {
        let data = string.data(using: .utf8)!

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: service
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            // update
            let updateStatus = SecItemUpdate(query as CFDictionary,
                                             attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpected(updateStatus)
            }

        } else if status == errSecItemNotFound {
            // insert
            var addQuery = query
            attributes.forEach { addQuery[$0.key] = $0.value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpected(addStatus)
            }

        } else {
            throw KeychainError.unexpected(status)
        }
    }

    func getString(forKey key: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unexpected(status)
        }

        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func removeString(forKey key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpected(status)
        }
    }
}
