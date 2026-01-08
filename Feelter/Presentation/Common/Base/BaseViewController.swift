//
//  BaseVViewController.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

class BaseViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureHierarchy()
        configureLayout()
        configureView()
    }
    
    func configureHierarchy() { }
    func configureLayout() { }
    func configureView() {
        view.backgroundColor = .Feelter.gray100
        setNavigationBackbutton()
        setNavigationTitleStyle()
        hideKeyboardWhenTappedAround()
    }
    
    private func setNavigationBackbutton() {
        guard let backImage = UIImage.Icon.chevron else { return }
        navigationController?.navigationBar.backIndicatorImage = backImage
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backImage
        navigationController?.navigationBar.tintColor = .Feelter.gray75
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
    
    private func setNavigationTitleStyle() {
        navigationController?.navigationBar.titleTextAttributes = [
            .font: TextStyle.Mulgyeol.body1,
            .foregroundColor: UIColor.Feelter.gray60 ?? .systemGray
        ]
    }
    
    private func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

