//
//  ShushValue.swift
//  Shush
//
//  Created by syan on 18/05/2023.
//  Copyright © 2023 Syan. All rights reserved.
//

import Foundation

// https://betterprogramming.pub/five-property-wrappers-to-de-clutter-your-ios-code-f5ee6fa4e52e
@propertyWrapper
public class ShushValue<T: Codable>: NSObject {
    
    // MARK: Init
    public init(key: String, defaultValue: T, local: UserDefaults = .standard, ubiquitous: NSUbiquitousKeyValueStore? = .default, notification: Notification.Name? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.local = local
        self.ubiquitous = ubiquitous
        self.notification = notification
        
        var initError: Error? = nil
        if let data = local.data(forKey: key) {
            do {
                self.wrappedValue = try JSONDecoder().decode(T.self, from: data)
            }
            catch {
                initError = error
                self.wrappedValue = defaultValue
            }
        }
        else {
            self.wrappedValue = defaultValue
        }
        super.init()
        
        if let initError {
            self.log(.error, "Couldn't decode value: \(initError)")
        }
        
        if let ubiquitous {
            // https://stackoverflow.com/a/13476127/1439489
            ubiquitous.set(Int.random(in: 0..<100), forKey: "random_key_to_start_syncing")
            ubiquitous.synchronize()

            NotificationCenter.default.addObserver(
                self, selector: #selector(self.ubiquitousStoreChanged(notification:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: ubiquitous
            )
        }
    }

    // MARK: Internal
    private let key: String
    private let defaultValue: T
    private let local: UserDefaults
    private let ubiquitous: NSUbiquitousKeyValueStore?
    private let notification: Notification.Name?
    
    // MARK: Properties
    public var wrappedValue: T {
        didSet {
            do {
                let data = try JSONEncoder().encode(wrappedValue)
                local.set(data, forKey: key)
                ubiquitous?.set(data, forKey: key)
                ubiquitous?.synchronize()
            }
            catch {
                log(.error, "Couldn't encode value: \(error)")
            }
            postNotification()
        }
    }
    
    // MARK: Sync
    private func postNotification() {
        guard let notification else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notification, object: nil)
        }
    }

    @objc private func ubiquitousStoreChanged(notification: Notification) {
        guard let ubiquitous else { return }
        guard let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }

        switch reason {
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            log(.warn, "Over quota")
            
        case NSUbiquitousKeyValueStoreAccountChange:
            log(.warn, "Account changed")
            
        case NSUbiquitousKeyValueStoreInitialSyncChange, NSUbiquitousKeyValueStoreServerChange:
            guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
            guard keys.contains(key) else { return }

            let value = ubiquitous.object(forKey: key)
            if let data = value as? Data {
                // added / updated
                local.setValue(data, forKey: key)
                postNotification()
            }
            else if let value {
                // added / updated, but unknown type
                log(.error, "Received new synced value, but it is not a Data type: \(type(of: value))")
            }
            else {
                // deleted
                local.removeObject(forKey: key)
                postNotification()
            }
            
        default:
            log(.error, "Unknown sync reason: \(reason)")
        }
    }
}

extension ShushValue: Loggable {
    var logTag: String {
        return "ShushValue(\(key))"
    }
}
