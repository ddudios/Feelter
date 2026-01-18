//
//  ProfileEditViewController.swift
//  Feelter
//
//  Created by Suji Jang on 2/1/26.
//

import UIKit
import SnapKit

final class ProfileEditViewController: BaseViewController {

    private let titleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프로필 수정"
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(titleLabel)
    }

    override func configureLayout() {
        super.configureLayout()
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func configureView() {
        super.configureView()
        titleLabel.font = TextStyle.Pretendard.body1
        titleLabel.textColor = .Feelter.gray60
        titleLabel.text = "프로필 수정 (준비중)"
    }
}
