//
//  ReachabilityManager.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/2/16.
//  Copyright © 2016 RadioAristocrats. All rights reserved.
//

import Foundation
import ReachabilitySwift

class ReachabilityManager: NSObject {
    
    private var internetReachability: Reachability?
    private var previousNetworkStatus: Reachability.NetworkStatus
    
    var onReachabilityStatusChange:((prevStatus: Reachability.NetworkStatus, currStatus: Reachability.NetworkStatus) -> Void)? {
        didSet {
            if let internetReachability = internetReachability {
                reactToReachability(internetReachability)
            }
        }
    }
    
    class var sharedManager: ReachabilityManager {
        struct Static {
            static let instance: ReachabilityManager = ReachabilityManager()
        }
        return Static.instance
    }
    
    override init() {
        do {
            internetReachability = try Reachability.reachabilityForInternetConnection()
        } catch _ {
            print("*** Failed to init Reachability.")
        }
        
        do {
            if let internetReachability = internetReachability {
                try internetReachability.startNotifier()
            }
        } catch _ {
            print("*** Failed to start Reachability notifier.")
        }
        
        if let internetReachability = internetReachability {
            previousNetworkStatus = internetReachability.currentReachabilityStatus
        } else {
            previousNetworkStatus = .ReachableViaWiFi // Default
        }
        
        super.init() // super.init() must be called AFTER you initialize all your instance variables
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reachabilityChanged:", name:ReachabilityChangedNotification, object: nil)
    }
    
    func isInternetConnectionAvailable() -> Bool {
        if let internetReachability = internetReachability {
            let networkStatus = internetReachability.currentReachabilityStatus
            if (networkStatus == .NotReachable) { return false } else { return true }
        } else {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func reactToReachability(reachability: Reachability) -> Void {
        let networkStatus = reachability.currentReachabilityStatus
        if let closure = onReachabilityStatusChange {
            closure(prevStatus: previousNetworkStatus, currStatus: networkStatus)
        }
        previousNetworkStatus = networkStatus
    }
    
    func reachabilityChanged(notification: NSNotification) {
        if let reachability = notification.object as? Reachability {
            reactToReachability(reachability)
        } else {
            print("*** Type casting error.")
        }
    }
}
