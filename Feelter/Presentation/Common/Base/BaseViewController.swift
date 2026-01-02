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
    }
    
    private func setNavigationBackbutton() {
        let backbutton = UIBarButtonItem(title: "", style: .plain, target: self, action: nil)
        backbutton.tintColor = .Feelter.gray75
        navigationItem.backBarButtonItem = backbutton
    }
    
    private func setNavigationTitleStyle() {
        navigationItem.largeTitleDisplayMode = .never
        
        navigationController?.navigationBar.titleTextAttributes = [
            .font: TextStyle.Mulgyeol.body1,
            .foregroundColor: UIColor.Feelter.gray60 ?? .systemGray
        ]
    }
}

