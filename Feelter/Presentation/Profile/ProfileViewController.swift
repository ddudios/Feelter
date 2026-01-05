//
//  ProfileViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import SnapKit
import Combine

final class ProfileViewController: BaseViewController {

    private let logoutButton = {
        let button = FeelterButton(title: "로그아웃")
        button.backgroundColor = .Feelter.deepTurquoise
        return button
    }()
    
    private let viewModel: ProfileViewModel
    private let logoutConfirmSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프로필"
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(logoutButton)
    }

    override func configureLayout() {
        super.configureLayout()
        logoutButton.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(40)
            make.height.equalTo(44)
        }
    }

    override func configureView() {
        super.configureView()

        let input = ProfileViewModel.Input(
            logoutButtonTapped: logoutButton.tapPublisher,
            logoutConfirmed: logoutConfirmSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.showLogoutAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.showLogoutAlert()
            }
            .store(in: &cancellables)

        output.logoutFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.performLogout()
            }
            .store(in: &cancellables)
    }

    private func showLogoutAlert() {
        let alert = UIAlertController(
            title: "로그아웃",
            message: "정말 로그아웃 하시겠습니까?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in
            // ViewModel에게 "확인 버튼 눌렀어" 신호 전달
            self?.logoutConfirmSubject.send(())
        })

        present(alert, animated: true)
    }

    private func performLogout() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate,
              let appCoordinator = sceneDelegate.appCoordinator else { return }
        appCoordinator.logout()
    }
}
