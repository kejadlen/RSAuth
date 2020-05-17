//
//  Keychain.swift
//  RSAuth WatchKit Extension
//
//  Created by Alpha on 5/16/20.
//  Copyright © 2020 Arbitrary Definitions. All rights reserved.
//

import Foundation
import Security

class Keychain {

    struct Error: Swift.Error {}

    var serial: Data? {
        get { try? read(service: "serial") }
        set {
            guard let newValue = newValue else {
                _ = try? delete(service: "serial")
                return
            }

            if serial == nil {
                try? create(data: newValue, for: "serial")
            } else {
                try? update(data: newValue, for: "serial")
            }
        }
    }

    var seed: Data? {
        get { try? read(service: "seed") }
        set {
            guard let newValue = newValue else {
                _ = try? delete(service: "seed")
                return
            }

            if seed == nil {
                try? create(data: newValue, for: "seed")
            } else {
                try? update(data: newValue, for: "seed")
            }
        }
    }

    private func create(data: Data, for service: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecValueData: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw Error()
        }
    }

    private func read(service: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnAttributes: true,
            kSecReturnData: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { throw Error() }

        guard
            let existingItem = item as? [String : Any],
            let data = existingItem[kSecValueData as String] as? Data
        else {
            throw Error()
        }

        return data
    }

    private func update(data: Data, for service: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status != errSecItemNotFound else { throw Error() }
        guard status == errSecSuccess else { throw Error() }
    }

    private func delete(service: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Error() }
    }
}
