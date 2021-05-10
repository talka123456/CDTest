//
//  InternalMenuViewController.swift
//  Moments
//
//  Created by Jake Lin on 17/10/20.
//

import UIKit
import RxDataSources
import SnapKit

final class InternalMenuViewController: BaseViewController {
    private var viewModel: InternalMenuViewModelType!

    private lazy var tableView: UITableView = configure(UITableView(frame: CGRect.zero, style: .grouped)) {
        $0.rowHeight = UITableView.automaticDimension
        $0.estimatedRowHeight = 44

        $0.register(InternalMenuDescriptionCell.self, forCellReuseIdentifier: InternalMenuItemType.description.rawValue)
        $0.register(InternalMenuActionTriggerCell.self, forCellReuseIdentifier: InternalMenuItemType.actionTrigger.rawValue)
        $0.register(InternalMenuFeatureToggleCell.self, forCellReuseIdentifier: InternalMenuItemType.featureToggle.rawValue)
    }

    init(router: AppRouting = AppRouter.shared) {
        super.init()

        // Remember to weak self to avoid retain cycle
        viewModel = InternalMenuViewModel(router: router, routingSourceProvider: { [weak self] in
            return self
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupConstraints()

        DispatchQueue.main.async {
            // Walkaround for a warning
            // https://github.com/RxSwiftCommunity/RxDataSources/issues/331
            self.setupBindings()
        }
    }
}

private extension InternalMenuViewController {
    func setupUI() {
        title = viewModel.title
        view.addSubview(tableView)
    }

    func setupConstraints() {
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func setupBindings() {
        let dismissBarButtonItem: UIBarButtonItem = UIBarButtonItem(systemItem: .done)
        dismissBarButtonItem.rx.tap.subscribe(onNext: { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }).disposed(by: disposeBag)
        navigationItem.rightBarButtonItem = dismissBarButtonItem

        let dataSource = RxTableViewSectionedReloadDataSource<InternalMenuSection>(
            configureCell: { _, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: item.type.rawValue, for: indexPath)
                if let cell = cell as? InternalMenuCellType {
                    cell.update(with: item)
                }
                return cell
            }, titleForHeaderInSection: { dataSource, section in
                return dataSource.sectionModels[section].title
            }, titleForFooterInSection: { dataSource, section in
                return dataSource.sectionModels[section].footer
            })

        viewModel.sections
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        tableView.rx
            .itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            })
            .disposed(by: disposeBag)

        tableView.rx
            .modelSelected(InternalMenuItemViewModel.self)
            .subscribe(onNext: { item in
                item.select()
            })
            .disposed(by: disposeBag)
    }
}
