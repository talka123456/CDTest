//
//  UserProfileListItemView.swift
//  Moments
//
//  Created by Jake Lin on 27/10/20.
//

import Foundation
import UIKit
import DesignKit

final class UserProfileListItemView: BaseListItemView {
    private let backgroundImageView: UIImageView = configure(.init()) {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.contentMode = .scaleAspectFill
        $0.accessibilityIgnoresInvertColors = true
    }

    private let avatarImageView: UIImageView = configure(.init()) {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.asAvatar(cornerRadius: 8)
        $0.contentMode = .scaleAspectFill
        $0.accessibilityIgnoresInvertColors = true
    }

    private let nameLabel: UILabel = configure(.init()) {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.font = UIFont.designKit.title3
        $0.textColor = .white
        $0.numberOfLines = 1
    }

    private let remoteTogglesDataStore: TogglesDataStoreType

    convenience override init(frame: CGRect = .zero) {
        self.init(frame: frame, remoteTogglesDataStore: RemoteTogglesDataStore.shared)
    }

    init(frame: CGRect, remoteTogglesDataStore: TogglesDataStoreType) {
        self.remoteTogglesDataStore = remoteTogglesDataStore
        super.init(frame: frame)

        setupUI()
        setupConstraints()
    }

    // swiftlint:disable unavailable_function
    required init?(coder aDecoder: NSCoder) {
        fatalError(L10n.Development.fatalErrorInitCoderNotImplemented)
    }
    // swiftlint:enable unavailable_function

    override func update(with viewModel: ListItemViewModel) {
        guard let viewModel = viewModel as? UserProfileListItemViewModel else {
            return
        }

        backgroundImageView.kf.setImage(with: viewModel.backgroundImageURL)
        avatarImageView.kf.setImage(with: viewModel.avatarURL)
        nameLabel.text = viewModel.name
    }
}

private extension UserProfileListItemView {
    func setupUI() {
        backgroundColor = UIColor.designKit.background

        [backgroundImageView, avatarImageView, nameLabel].forEach {
            addSubview($0)
        }

        // Round the avatar if the remote toggle is on
        if remoteTogglesDataStore.isToggleOn(RemoteToggle.isRoundedAvatar) {
            avatarImageView.asAvatar(cornerRadius: 40)
        }
    }

    func setupConstraints() {
        backgroundImageView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-Spacing.medium)
            $0.height.equalTo(backgroundImageView.snp.width).multipliedBy(0.8).priority(999)
        }

        avatarImageView.snp.makeConstraints {
            $0.right.equalToSuperview().offset(-Spacing.medium)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(80)
            $0.width.equalTo(80)
        }

        nameLabel.snp.makeConstraints {
            $0.right.equalTo(self.avatarImageView.snp.left).offset(-Spacing.medium)
            $0.centerY.equalTo(self.avatarImageView.snp.centerY)
        }
    }
}
