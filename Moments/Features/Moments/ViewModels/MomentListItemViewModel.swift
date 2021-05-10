//
//  MomentListItemViewModel.swift
//  Moments
//
//  Created by Jake Lin on 29/10/20.
//

import Foundation
import RxSwift

struct MomentListItemViewModel: ListItemViewModel {
    let userAvatarURL: URL?
    let userName: String
    let title: String?
    let photoURL: URL? // This version only supports one image
    let postDateDescription: String?
    let isLiked: Bool
    let likes: [URL]

    private let momentID: String
    private let momentsRepo: MomentsRepoType
    private let trackingRepo: TrackingRepoType

    init(moment: MomentsDetails.Moment, momentsRepo: MomentsRepoType = MomentsRepo.shared, trackingRepo: TrackingRepoType = TrackingRepo.shared, now: Date = Date(), relativeDateTimeFormatter: RelativeDateTimeFormatterType = RelativeDateTimeFormatter()) {
        momentID = moment.id
        self.momentsRepo = momentsRepo
        self.trackingRepo = trackingRepo
        userAvatarURL = URL(string: moment.userDetails.avatar)
        userName = moment.userDetails.name
        title = moment.title
        isLiked = moment.isLiked ?? false
        likes = moment.likes?.compactMap { URL(string: $0.avatar) } ?? []

        if let firstPhoto = moment.photos.first {
            photoURL = URL(string: firstPhoto)
        } else {
            photoURL = nil
        }

        var formatter = relativeDateTimeFormatter
        formatter.unitsStyle = .full
        if let timeInterval = TimeInterval(moment.createdDate) {
            let createdDate = Date(timeIntervalSince1970: timeInterval)
            postDateDescription = formatter.localizedString(for: createdDate, relativeTo: now)
        } else {
            postDateDescription = nil
        }
    }

    func like(from userID: String) -> Observable<Void> {
        trackingRepo.trackAction(LikeActionTrackingEvent(momentID: momentID, userID: userID))
        return momentsRepo.updateLike(isLiked: true, momentID: momentID, fromUserID: userID)
    }

    func unlike(from userID: String) -> Observable<Void> {
        trackingRepo.trackAction(UnlikeActionTrackingEvent(momentID: momentID, userID: userID))
        return momentsRepo.updateLike(isLiked: false, momentID: momentID, fromUserID: userID)
    }
}
