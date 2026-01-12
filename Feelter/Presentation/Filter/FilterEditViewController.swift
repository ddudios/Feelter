//
//  FilterEditViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/12/26.
//

import UIKit

final class FilterEditViewController: BaseViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCustomTabBarHidden(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setCustomTabBarHidden(false)
    }

    override func configureView() {
        super.configureView()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage.Icon.save,
            style: .plain,
            target: self,
            action: #selector(saveButtonTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .Feelter.gray75
    }

    @objc private func cancelButtonTapped() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func saveButtonTapped() { }

    private func setCustomTabBarHidden(_ hidden: Bool) {
        (tabBarController as? CustomTabBarController)?.setCustomTabBarHidden(hidden, animated: false)
    }
}
