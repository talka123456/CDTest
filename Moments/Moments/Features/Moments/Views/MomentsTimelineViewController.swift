//
//  MomentsTimelineViewController.swift
//  Moments
//
//  Created by Jake Lin on 28/10/20.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import DesignKit

final class MomentsTimelineViewController: BaseTableViewController {
    override init() {
        super.init()
        viewModel = MomentsTimelineViewModel(userID: UserDataStore.current.userID)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.trackScreenviews()
    }

    override var tableViewCellsToRegister: [String : UITableViewCell.Type] {
        return [
            UserProfileListItemViewModel.reuseIdentifier: BaseTableViewCell<UserProfileListItemView>.self,
            MomentListItemViewModel.reuseIdentifier: BaseTableViewCell<MomentListItemView>.self
        ]
    }
}
