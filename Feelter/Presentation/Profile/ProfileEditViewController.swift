//
//  ProfileEditViewController.swift
//  Feelter
//
//  Created by Suji Jang on 2/1/26.
//

import UIKit
import SnapKit
import Kingfisher
import PhotosUI

final class ProfileEditViewController: BaseViewController {

    // MARK: - Properties
    private let userRepository: UserRepositoryProtocol
    private var currentUser: User?
    private var selectedImage: UIImage?
    private var uploadedImagePath: String?
    private var isImageRemoved: Bool = false

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let profileImageButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .Feelter.gray90
        button.layer.cornerRadius = 60
        button.clipsToBounds = true
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.Feelter.gray75?.cgColor
        return button
    }()

    private let cameraIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "camera.fill")
        imageView.tintColor = .Feelter.gray60
        imageView.backgroundColor = .Feelter.gray75
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true
        imageView.contentMode = .center
        return imageView
    }()

    private lazy var nicknameTextField = createTextField(placeholder: "닉네임")
    private lazy var nameTextField = createTextField(placeholder: "이름")
    private lazy var introductionTextField = createTextField(placeholder: "소개")
    private lazy var phoneTextField = createTextField(placeholder: "전화번호 (010-1234-5678)")
    private lazy var hashTagsTextField = createTextField(placeholder: "해시태그 (#태그1, #태그2)")

    // MARK: - Initialization
    init(userRepository: UserRepositoryProtocol = UserRepository(networkManager: NetworkManager())) {
        self.userRepository = userRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프로필 수정"
        setupNavigationBar()
        loadProfile()
    }

    override func configureHierarchy() {
        super.configureHierarchy()

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        [profileImageButton, cameraIconView, nicknameTextField, nameTextField,
         introductionTextField, phoneTextField, hashTagsTextField].forEach {
            contentView.addSubview($0)
        }
    }

    override func configureLayout() {
        super.configureLayout()

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        profileImageButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.centerX.equalToSuperview()
            make.size.equalTo(120)
        }

        cameraIconView.snp.makeConstraints { make in
            make.trailing.bottom.equalTo(profileImageButton)
            make.size.equalTo(32)
        }

        nicknameTextField.snp.makeConstraints { make in
            make.top.equalTo(profileImageButton.snp.bottom).offset(32)
            make.horizontalEdges.equalToSuperview().inset(20)
            make.height.equalTo(48)
        }

        nameTextField.snp.makeConstraints { make in
            make.top.equalTo(nicknameTextField.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(20)
            make.height.equalTo(48)
        }

        introductionTextField.snp.makeConstraints { make in
            make.top.equalTo(nameTextField.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(20)
            make.height.equalTo(48)
        }

        phoneTextField.snp.makeConstraints { make in
            make.top.equalTo(introductionTextField.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(20)
            make.height.equalTo(48)
        }

        hashTagsTextField.snp.makeConstraints { make in
            make.top.equalTo(phoneTextField.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(20)
            make.height.equalTo(48)
            make.bottom.equalToSuperview().offset(-32)
        }
    }

    override func configureView() {
        super.configureView()

        profileImageButton.addTarget(self, action: #selector(profileImageButtonTapped), for: .touchUpInside)
    }

    // MARK: - Setup
    private func setupNavigationBar() {
        let saveButton = UIBarButtonItem(
            image: UIImage.Icon.save,
            style: .plain,
            target: self,
            action: #selector(saveButtonTapped)
        )
        saveButton.tintColor = .Feelter.blackTurquoise
        navigationItem.rightBarButtonItem = saveButton
    }

    private func createTextField(placeholder: String) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = TextStyle.Pretendard.body1
        textField.textColor = .Feelter.gray60
        textField.backgroundColor = .Feelter.gray90
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.Feelter.gray75?.cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        textField.rightViewMode = .always
        return textField
    }

    // MARK: - Actions
    @objc private func profileImageButtonTapped() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let selectPhotoAction = UIAlertAction(title: "사진 선택", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        }

        let removePhotoAction = UIAlertAction(title: "사진 제거", style: .destructive) { [weak self] _ in
            self?.removeProfileImage()
        }

        let cancelAction = UIAlertAction(title: "취소", style: .cancel)

        actionSheet.addAction(selectPhotoAction)

        // 현재 프로필 이미지가 있을 때만 "사진 제거" 옵션 표시
        if currentUser?.hasProfileImage == true || selectedImage != nil {
            actionSheet.addAction(removePhotoAction)
        }

        actionSheet.addAction(cancelAction)

        present(actionSheet, animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func removeProfileImage() {
        isImageRemoved = true
        selectedImage = nil
        uploadedImagePath = nil

        // 기본 아이콘으로 변경
        profileImageButton.setImage(UIImage(named: "appIcon"), for: .normal)
        profileImageButton.tintColor = .clear
        profileImageButton.imageView?.contentMode = .scaleAspectFill
    }

    @objc private func saveButtonTapped() {
        Task {
            await saveProfile()
        }
    }

    // MARK: - Data Loading
    private func loadProfile() {
        Task {
            do {
                let user = try await userRepository.fetchMyProfile()
                currentUser = user
                updateUI(with: user)
            } catch {
                showAlert(message: "프로필을 불러올 수 없습니다: \(error.localizedDescription)")
            }
        }
    }

    private func updateUI(with user: User) {
        nicknameTextField.text = user.nickname
        nameTextField.text = user.name
        introductionTextField.text = user.introduction
        phoneTextField.text = user.phoneNumber
        hashTagsTextField.text = user.hashTags.joined(separator: ", ")

        // Load profile image
        profileImageButton.setFeelterImage(
            with: user.profileImageURL,
            targetSize: CGSize(width: 120, height: 120),
            defaultImage: UIImage(named: "appIcon")
        )
    }

    // MARK: - Data Saving
    private func saveProfile() async {
        guard let nickname = nicknameTextField.text, !nickname.isEmpty else {
            showAlert(message: "닉네임을 입력해주세요.")
            return
        }

        do {
            // 1. 이미지가 선택되었으면 먼저 업로드
            var imagePath: String? = uploadedImagePath ?? currentUser?.profileImageURL

            if isImageRemoved {
                // 프로필 사진 제거
                imagePath = ""
            } else if let selectedImage = selectedImage,
                      let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
                showLoading(message: "이미지 업로드 중...")
                imagePath = try await userRepository.uploadProfileImage(imageData)
                hideLoading()
            }

            // 2. 프로필 업데이트
            showLoading(message: "저장 중...")

            let hashTags = parseHashTags(from: hashTagsTextField.text ?? "")

            let updatedUser = try await userRepository.updateProfile(
                nick: nickname,
                name: nameTextField.text,
                introduction: introductionTextField.text,
                phoneNum: phoneTextField.text,
                profileImage: imagePath,
                hashTags: hashTags.isEmpty ? nil : hashTags
            )

            hideLoading()

            currentUser = updatedUser
            uploadedImagePath = nil
            selectedImage = nil
            isImageRemoved = false

            showAlert(message: "프로필이 저장되었습니다.") { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }

        } catch {
            hideLoading()
            showAlert(message: "저장 실패: \(error.localizedDescription)")
        }
    }

    private func parseHashTags(from text: String) -> [String] {
        let tags = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return tags.map { tag in
            tag.hasPrefix("#") ? tag : "#\(tag)"
        }.filter { !$0.isEmpty && $0 != "#" }
    }

    // MARK: - Helpers
    private func showAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }

    private func showLoading(message: String) {
        // TODO: 로딩 인디케이터 구현
        print(message)
    }

    private func hideLoading() {
        // TODO: 로딩 인디케이터 숨기기
        print("Loading hidden")
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ProfileEditViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showAlert(message: "이미지 로드 실패: \(error.localizedDescription)")
                }
                return
            }

            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    self?.selectedImage = image
                    self?.isImageRemoved = false
                    self?.profileImageButton.setImage(image, for: .normal)
                    self?.profileImageButton.tintColor = .clear
                    self?.profileImageButton.imageView?.contentMode = .scaleAspectFill
                }
            }
        }
    }
}
