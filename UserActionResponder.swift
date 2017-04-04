//
//  UserActionResponder.swift
//  PhotoLockBox
//
//  Created by Troy Anderson on 4/3/17.
//  Copyright © 2017 TLA Investments LLC. All rights reserved.
//

import Foundation

//
//  Sample usage:
//
//    let responder = UserActionResponder()     // Keep this handy so you can call other functions
//
//    responder.when(.one(criteria:[.launch(count:5), .activated(count:5)]) { _ in
//      if #available(iOS 10.3, *) {
//          SKStoreReviewController.requestReview()
//      } else {
//          print("Skipping review requesting due to OS version")
//      }
//    })
//
//  Explicit criteria:
//    var criteria:[UserActionResponder.Criterion] = []
//
//    criteria.append(.launch(count:5))
//    criteria.append(.activated(count:5))
//    criteria.append(.daysSinceInstallationOrUpdate(days:7))
//    criteria.append(.significantEvent("Did the thing", count:5)
//
//    responder.when(.all(criteria:criteria) { _ in
//        if #available(iOS 10.3, *) {
//            SKStoreReviewController.requestReview()
//        } else {
//            print("Skipping review requesting due to OS version")
//        }
//    })
//
//
//  Significant events:
//
//    responder.when("Testing", trigger: .any(criteria: [.significantEvent(identifier:"Event 1", count:2)]), repeats: false) { _ in
//        print("Some significant events did occur")
//    }
//
//    UserActionResponder.shared.significantEventDidOccur(identifier: "Event 1")
//




typealias UserActionTrigger = UserActionResponder.Trigger

class UserActionResponder {
    fileprivate struct TriggerInfo {
        let trigger:Trigger
        let block:((AnyHashable) -> Void)
        let repeats:Bool
    }
    
    enum Trigger {
        /// When any criterion is matched, the block will be called
        case any(criteria:[Criterion])
        
        /// When all of the criterion have matched, the block will be called
        case all(criteria:[Criterion])
        
        /// Return true if the action is being performed
        fileprivate func matches(_ info:Info) -> Bool {
            switch self {
            case .any(let criteria):
                return criteria.contains(where: { $0.matches(info) })
                
            case .all(let criteria):
                return criteria.filter({ !$0.matches(info) }).count == 0
            }
        }
    }

    enum Criterion {
        case launch(count:Int)
        case activated(count:Int)
        case daysSinceInstallationOrUpdate(days:Int)
        case significantEvent(identifier:String, count:Int)
        
        fileprivate func matches(_ info:Info) -> Bool {
            switch self {
            case .launch(let count): return info.launchCount >= count
            case .activated(let count): return info.activationCount >= count
            case .significantEvent(let identifier, let count):
                guard let eventCount = info.significantEventCounts[identifier] else { return false }
                return eventCount >= count

            case .daysSinceInstallationOrUpdate(let days):
                let latest:Date
                if let updatedAt = info.lastUpdatedAt {
                    latest = max(updatedAt, info.installedAt)
                } else {
                    latest = info.installedAt
                }
                
                return latest.addingTimeInterval(TimeInterval(days * 24*60*60)) >= Date()
            }
        }
    }
    
    var userDefaultsKey:String
    var resetCountsOnUpdate:Bool
    var queue:DispatchQueue

    fileprivate var info:Info { didSet { info.store() } }
    private var triggers = [AnyHashable:TriggerInfo]()
    
    fileprivate struct Info {
        let userDefaultsKey:String
        
        var launchCount:Int
        var activationCount:Int
        var significantEventCounts:[String:Int]
        
        var installedAt:Date
        var installedVersion:String
        var lastUpdatedAt:Date?
        
        var history:[AnyHashable]
        
        private struct Key {
            static let launchCount = "launhCount"
            static let activationCount = "activationCount"
            static let significantEventCounts = "significantEventCounts"
            static let eventName = "eventName"
            static let eventCount = "eventCount"
            static let installedAt = "installedAt"
            static let installedVersion = "installedVersion"
            static let lastUpdatedAt = "lastUpdatedAt"
            static let history = "history"
        }
        
        static func load(userDefaultsKey:String) -> Info {
            let info:Info
            
            if let dict = UserDefaults.standard.dictionary(forKey: userDefaultsKey),
                let launchCount = dict[Key.launchCount] as? Int,
                let activationCount = dict[Key.activationCount] as? Int,
                let significantEventCounts = dict[Key.significantEventCounts] as? [String:Int],
                let installedAt = dict[Key.installedAt] as? Date,
                let installedVersion = dict[Key.installedVersion] as? String,
                let history = dict[Key.history] as? [AnyHashable]
            {
                let lastUpdatedAt = dict[Key.lastUpdatedAt] as? Date
                info = Info(userDefaultsKey:userDefaultsKey, launchCount: launchCount, activationCount: activationCount, significantEventCounts: significantEventCounts, installedAt: installedAt, installedVersion: installedVersion, lastUpdatedAt: lastUpdatedAt, history:history)
            } else {
                // Build the initial info for an app
                let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                
                info = Info(userDefaultsKey:userDefaultsKey, launchCount: 0, activationCount: 0, significantEventCounts: [:], installedAt: Date(), installedVersion: installedVersion, lastUpdatedAt: nil, history:[])
                info.store()
            }

            return info
        }
        
        func store() {
            var dict:[String:Any] = [Key.launchCount:launchCount,
                                     Key.activationCount:activationCount,
                                     Key.significantEventCounts:significantEventCounts,
                                     Key.installedAt:installedAt,
                                     Key.installedVersion:installedVersion,
                                     Key.history:history]

            if let date = lastUpdatedAt {
                dict[Key.lastUpdatedAt] = date
            }
            
            UserDefaults.standard.set(dict, forKey: userDefaultsKey)
        }
    }
    
    init(resetCountsOnUpdate:Bool = true, userDefaultsKey:String = "com.alliedcode.userActionResponder", queue:DispatchQueue = DispatchQueue.main) {
        self.resetCountsOnUpdate = resetCountsOnUpdate
        self.userDefaultsKey = userDefaultsKey
        self.queue = queue

        info = Info.load(userDefaultsKey:userDefaultsKey)
        
        checkForUpdate()
        
        info.launchCount += 1

        // When we come to the foreground, update the activation count
        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { [weak self] _ in
            self?.info.activationCount += 1
            self?.performTriggersIfNeeded()
        }
    }
    
    func significantEventDidOccur(identifier:String) {
        let count = info.significantEventCounts[identifier] ?? 0
        info.significantEventCounts[identifier] = count + 1
        performTriggersIfNeeded()
    }
    
    func when(_ identifier:AnyHashable, trigger:Trigger, repeats:Bool, block:@escaping ((AnyHashable) -> Void)) {
        triggers[identifier] = TriggerInfo(trigger: trigger, block: block, repeats: repeats)
        
        performTriggersIfNeeded()
    }
    
    func cancel(identifier:AnyHashable) {
        triggers.removeValue(forKey: identifier)
    }
    
    private func checkForUpdate() {
        let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let knownVersion = info.installedVersion
        
        if knownVersion != installedVersion {
            info.installedVersion = installedVersion
            info.lastUpdatedAt = Date()
            
            if resetCountsOnUpdate {
                info.launchCount = 0
                info.activationCount = 0
                info.significantEventCounts = [:]
                info.history = []
            }
        }
    }
    
    private func performTriggersIfNeeded() {
        for (identifier, triggerInfo) in triggers {
            guard triggerInfo.repeats || !info.history.contains(identifier) else { continue }

            if triggerInfo.trigger.matches(info) {
                queue.async { triggerInfo.block(identifier) }
                
                if !info.history.contains(identifier) {
                    info.history.append(identifier)
                }
            }
        }
    }
}
