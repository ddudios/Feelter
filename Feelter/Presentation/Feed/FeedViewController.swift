//
//  FeedViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit
import SnapKit

final class FeedViewController: BaseViewController {

    weak var coordinator: FeedCoordinator?

    private let placeholderLabel = {
        let label = UILabel()
        label.text = "FEED\n(준비 중)"
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray60
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FEED"
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(placeholderLabel)
    }

    override func configureLayout() {
        super.configureLayout()
        placeholderLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
