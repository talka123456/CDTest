//
//  UnlikeActionTrackingEvent.swift
//  Moments
//
//  Created by Jake Lin on 5/11/20.
//

import Foundation
import FirebaseAnalytics

struct UnlikeActionTrackingEvent: ActionTrackingEventType {
    let momentID: String
    let userID: String
}

extension UnlikeActionTrackingEvent: FirebaseActionTrackingEvent {
    var parameters: [String : Any] {
        // swiftlint:disable no_hardcoded_strings
        return [
            AnalyticsParameterItemID: "moment-id-\(momentID)-user-id-\(userID)",
            AnalyticsParameterItemName: "moment-unlike"
        ]
        // swiftlint:enable no_hardcoded_strings
    }
}
