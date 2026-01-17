//
//  BaseVViewController.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit

class BaseViewController: UIViewController {

    // Tap gesture를 저장하여 필요 시 제거 가능
    private var keyboardDismissTapGesture: UITapGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureHierarchy()
        configureLayout()
        configureView()
        setupKeyboardDismissGesture()
    }

    func configureHierarchy() { }
    func configureLayout() { }
    func configureView() {
        view.backgroundColor = .Feelter.gray100
        setNavigationBackbutton()
        setNavigationTitleStyle()
    }

    /// 배경 탭 시 키보드 내리기 제스처 설정
    /// - 서브클래스에서 제거가 필요한 경우 `removeKeyboardDismissGesture()` 호출 가능
    private func setupKeyboardDismissGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        keyboardDismissTapGesture = tapGesture
    }

    /// 키보드 dismiss 제스처 제거 (필요한 경우 서브클래스에서 호출)
    func removeKeyboardDismissGesture() {
        if let gesture = keyboardDismissTapGesture {
            view.removeGestureRecognizer(gesture)
            keyboardDismissTapGesture = nil
        }
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
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension BaseViewController: UIGestureRecognizerDelegate {

    /// 제스처가 터치를 받을지 결정
    /// - 버튼, 텍스트필드 등 인터랙티브 요소는 제외
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // UIControl (버튼, 텍스트필드 등) 하위 뷰는 키보드 dismiss 안 함
        if touch.view is UIControl {
            return false
        }

        // UITextView도 제외 (채팅 입력창 등)
        if touch.view is UITextView {
            return false
        }

        return true
    }
}

