//
//  WatchConnectionHelper.swift
//  GeometricWeather
//
//  Created by 王大爷 on 2022/5/10.
//

import Foundation
import WatchConnectivity
import GeometricWeatherCore

@MainActor
class WatchConnectionHelper: NSObject,
                             WCSessionDelegate {
    
    // MARK: - singleton.
    
    static let shared = WatchConnectionHelper()
    
    private override init() {
        // do nothing.
    }
    
    // MARK: - properties.
    
    private let session = WCSession.default
    
    private var isHandshaking = false
    private var pendingRunnable = [() -> Void]()
    private var lastWatchSyncSkipLogTime: Date?
    private let watchSyncSkipLogInterval: TimeInterval = 5.0 * 60.0
    
    // MARK: - connectivity.
    
    var isConnecting: Bool {
        return self.session.activationState == .activated
    }
    
    private var canSyncToWatch: Bool {
        return WCSession.isSupported()
        && self.session.activationState == .activated
        && self.session.isPaired
        && self.session.isWatchAppInstalled
    }
    
    func checkToHandshake() {
        if !self.isHandshaking && WCSession.isSupported() && self.session.activationState != .activated {
            self.session.delegate = self
            self.session.activate()
            
            self.isHandshaking = true
        }
    }
    
    private func executeOrPending(_ runnable: @escaping () -> Void) {
        if self.isHandshaking {
            self.pendingRunnable.append(runnable)
            return
        }
        
        runnable()
    }
    
    // MARK: - location.
    
    func shareLocationUpdateResult(locations: [Location]) {
        self.checkToHandshake()
        
        if !self.isHandshaking && !self.canSyncToWatch {
            self.logWatchSyncSkippedIfNeeded()
            return
        }
        
        self.executeOrPending { [self] in
            guard self.canSyncToWatch else {
                self.logWatchSyncSkippedIfNeeded()
                return
            }
            
            let model = SharedLocationUpdateResult(locations: locations)
            
            do {
                let data = try JSONEncoder().encode(model)
                self.session.sendMessageData(data) { data in
                    // do nothing when reply.
                } errorHandler: { [weak self] error in
                    self?.shareLocationUpdateResultOnBackground(data: data)
                }
            } catch {
                printLog(
                    keyword: "watchConnection",
                    content: "Error when sending location update result: \(error)"
                )
            }
        }
    }
    
    private func shareLocationUpdateResultOnBackground(data: Data) {
        guard self.canSyncToWatch else {
            self.logWatchSyncSkippedIfNeeded()
            return
        }
        
        do {
            try self.session.updateApplicationContext(
                try JSONSerialization.jsonObject(
                    with: data,
                    options: .fragmentsAllowed
                ) as! Dictionary<String, Any>
            )
        } catch {
            printLog(
                keyword: "watchConnection",
                content: "Error when background updating location update result: \(error)"
            )
        }
    }
    
    private func logWatchSyncSkippedIfNeeded() {
        #if DEBUG
        let now = Date()
        if let lastWatchSyncSkipLogTime = self.lastWatchSyncSkipLogTime,
           now.timeIntervalSince(lastWatchSyncSkipLogTime) < self.watchSyncSkipLogInterval {
            return
        }
        
        self.lastWatchSyncSkipLogTime = now
        printLog(
            keyword: "watchConnection",
            content: "Skipped Watch sync because Watch app is not installed or session is not activated."
        )
        #endif
    }
    
    // MARK: - watch connectivity session delegate.
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task {
            await MainActor.run {
                self.isHandshaking = false
                
                for runnable in self.pendingRunnable {
                    runnable()
                }
                self.pendingRunnable.removeAll()
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // do nothing.
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // do nothing.
    }
}
