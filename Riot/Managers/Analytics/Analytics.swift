// 
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import PostHog
import AnalyticsEvents

/// A class responsible for managing an analytics client
/// and sending events through this client.
@objcMembers class Analytics: NSObject {
    
    // MARK: - Properties
    
    /// The singleton instance to be used within the Riot target.
    static let shared = Analytics()
    
    /// The analytics client to send events with.
    private var client = PostHogAnalyticsClient()
    
    /// Whether or not the object is enabled and sending events to the server.
    var isRunning: Bool { client.isRunning }
    
    /// Whether the user has yet to opt in or out of analytics collection.
    var shouldShowAnalyticsPrompt: Bool {
        // Show an analytics prompt when the user hasn't seen the PostHog prompt before.
        !RiotSettings.shared.hasSeenAnalyticsPrompt
    }
    
    /// Indicates whether the user previously accepted Matomo analytics and should be shown the upgrade prompt.
    var promptShouldDisplayUpgradeMessage: Bool {
        RiotSettings.shared.hasAcceptedMatomoAnalytics
    }
    
    // MARK: - Public
    
    /// Opts in to analytics tracking with the supplied session.
    /// - Parameter session: The session to use to when reading/generating the analytics ID.
    func optIn(with session: MXSession?) {
        guard let session = session else { return }
        RiotSettings.shared.enableAnalytics = true
        
        var settings = AnalyticsSettings(session: session)
        
        if settings.id == nil {
            settings.generateID()
            
            session.setAccountData(settings.dictionary, forType: AnalyticsSettings.eventType) {
                MXLog.debug("[Analytics] Successfully updated analytics settings in account data.")
            } failure: { error in
                MXLog.error("[Analytics] Failed to update analytics settings.")
            }
        }
        
        startIfEnabled()
        
        if !RiotSettings.shared.isIdentifiedForAnalytics {
            identify(with: settings)
        }
    }
    
    /// Opts out of analytics tracking and calls `reset` to clear any IDs and event queues.
    func optOut() {
        RiotSettings.shared.enableAnalytics = false
        reset()
    }
    
    /// Starts the analytics client if the user has opted in, otherwise does nothing.
    func startIfEnabled() {
        guard RiotSettings.shared.enableAnalytics, !isRunning else { return }
        
        client.start()
        
        // Sanity check in case something went wrong.
        guard client.isRunning else { return }
        
        MXLog.debug("[Analytics] Started.")
        
        // Catch and log crashes
        MXLogger.logCrashes(true)
        MXLogger.setBuildVersion(AppDelegate.theDelegate().build)
    }
    
    /// Resets the any IDs and event queues in the analytics client. This method
    /// can be called on sign-out to remember opt-in status, but ensure the next
    /// account used isn't associated with the previous one.
    func reset() {
        guard isRunning else { return }
        
        client.reset()
        MXLog.debug("[Analytics] Stopped and reset.")
        RiotSettings.shared.isIdentifiedForAnalytics = false
        
        // Stop collecting crash logs
        MXLogger.logCrashes(false)
    }
    
    /// Flushes the event queue in the analytics client, uploading all pending events.
    /// Normally events are sent in batches. Call this method when you need an event
    /// to be sent immediately.
    func forceUpload() {
        client.flush()
    }
    
    // MARK: - Private
    
    /// Identify (pseudonymously) any future events with the ID from the analytics account data settings.
    /// - Parameter settings: The settings to use for identification. The ID must be set *before* calling this method.
    private func identify(with settings: AnalyticsSettings) {
        guard let id = settings.id else {
            MXLog.warning("[Analytics] identify(with:) called before an ID has been generated.")
            return
        }
        
        client.identify(id: id)
        MXLog.debug("[Analytics] Identified.")
        RiotSettings.shared.isIdentifiedForAnalytics = true
    }
    
    /// Capture an event in the `client`.
    /// - Parameter event: The event to capture.
    private func capture(event: AnalyticsEventProtocol) {
        client.capture(event)
    }
}

// MARK: - Public tracking methods
// The following methods are exposed for compatibility with Objective-C as
// the `capture` method and the generated events cannot be bridged from Swift.
extension Analytics {
    /// Track the presentation of a screen
    /// - Parameters:
    ///   - screen: The screen that was shown.
    ///   - milliseconds: An optional value representing how long the screen was shown for in milliseconds.
    func trackScreen(_ screen: AnalyticsScreen, duration milliseconds: Int?) {
        let event = AnalyticsEvent.Screen(durationMs: milliseconds, screenName: screen.screenName)
        client.screen(event)
    }
    
    /// Track an E2EE error that occurred
    /// - Parameters:
    ///   - reason: The error that occurred.
    ///   - count: The number of times that error occurred.
    func trackE2EEError(_ reason: DecryptionFailureReason, count: Int) {
        for _ in 0..<count {
            let event = AnalyticsEvent.Error(context: nil, domain: .E2EE, name: reason.errorName)
            capture(event: event)
        }
    }
    
    /// Track whether the user accepted or declined the terms to an identity server.
    /// **Note** This method isn't currently implemented.
    /// - Parameter accepted: Whether the terms were accepted.
    func trackIdentityServerAccepted(_ accepted: Bool) {
        // Do we still want to track this?
    }
    
    /// Track whether the user granted or rejected access to the device contacts.
    /// **Note** This method isn't currently implemented.
    /// - Parameter granted: Whether access was granted.
    func trackContactsAccessGranted(_ granted: Bool) {
        // Do we still want to track this?
    }
}

// MARK: - MXAnalyticsDelegate
extension Analytics: MXAnalyticsDelegate {
    func trackDuration(_ milliseconds: Int, name: MXTaskProfileName, units: UInt) {
        guard let analyticsName = name.analyticsName else {
            MXLog.warning("[Analytics] Attempt to capture unknown profile task: \(name.rawValue)")
            return
        }
        
        let event = AnalyticsEvent.PerformanceTimer(context: nil, itemCount: Int(units), name: analyticsName, timeMs: milliseconds)
        capture(event: event)
    }
    
    func trackCallStarted(withVideo isVideo: Bool, numberOfParticipants: Int, incoming isIncoming: Bool) {
        let event = AnalyticsEvent.CallStarted(isVideo: isVideo, numParticipants: numberOfParticipants, placed: !isIncoming)
        capture(event: event)
    }
    
    func trackCallEnded(withDuration duration: Int, video isVideo: Bool, numberOfParticipants: Int, incoming isIncoming: Bool) {
        let event = AnalyticsEvent.CallEnded(durationMs: duration, isVideo: isVideo, numParticipants: numberOfParticipants, placed: !isIncoming)
        capture(event: event)
    }
    
    func trackCallError(with reason: __MXCallHangupReason, video isVideo: Bool, numberOfParticipants: Int, incoming isIncoming: Bool) {
        let callEvent = AnalyticsEvent.CallError(isVideo: isVideo, numParticipants: numberOfParticipants, placed: !isIncoming)
        let event = AnalyticsEvent.Error(context: nil, domain: .VOIP, name: reason.errorName)
        capture(event: callEvent)
        capture(event: event)
    }
    
    func trackCreatedRoom(asDM isDM: Bool) {
        let event = AnalyticsEvent.CreatedRoom(isDM: isDM)
        capture(event: event)
    }
    
    func trackJoinedRoom(asDM isDM: Bool, memberCount: UInt) {
        guard let roomSize = AnalyticsEvent.JoinedRoom.RoomSize(memberCount: memberCount) else {
            MXLog.warning("[Analytics] Attempt to capture joined room with invalid member count: \(memberCount)")
            return
        }
        
        let event = AnalyticsEvent.JoinedRoom(isDM: isDM, roomSize: roomSize)
        capture(event: event)
    }
}
