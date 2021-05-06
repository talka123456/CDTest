//
//  UserProfileListItemViewModel.swift
//  Moments
//
//  Created by Jake Lin on 26/10/20.
//

import Foundation

struct UserProfileListItemViewModel: ListItemViewModel {
    let name: String
    let avatarURL: URL?
    let backgroundImageURL: URL?

    init(userDetails: MomentsDetails.UserDetails) {
        name = userDetails.name
        avatarURL = URL(string: userDetails.avatar)
        backgroundImageURL = URL(string: userDetails.backgroundImage)
    }
}
