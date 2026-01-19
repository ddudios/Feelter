//
//  JoinViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/19/26.
//

import UIKit
import SnapKit
import Combine

final class JoinViewController: BaseViewController {

    // MARK: - Properties
    weak var coordinator: AuthCoordinator?
    private let authRepository: AuthRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    private var isEmailValidated = false
    private var isPasswordValid = false
    private var isPasswordMatching = false
    private var isNicknameValid = false

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "회원가입"
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .Feelter.gray0
        return label
    }()

    private let emailTextField = FeelterTextField(
        placeholder: "이메일",
        textContentType: .emailAddress,
        keyboardType: .emailAddress
    )

    private let emailCheckButton: UIButton = {
        let button = UIButton()
        button.setTitle("중복확인", for: .normal)
        button.setTitleColor(.Feelter.gray100, for: .normal)
        button.setTitleColor(.Feelter.gray75, for: .disabled)
        button.titleLabel?.font = TextStyle.Pretendard.caption1
        button.backgroundColor = .Feelter.deepTurquoise
        button.layer.cornerRadius = 8
        button.isEnabled = false
        return button
    }()

    private let emailValidationLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray75
        label.isHidden = true
        return label
    }()

    private let passwordTextField = FeelterTextField(
        placeholder: "비밀번호 (8자 이상, 영문/숫자/특수문자 포함)",
        isSecure: true,
        textContentType: .newPassword
    )

    private let passwordValidationLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray75
        label.isHidden = true
        return label
    }()

    private let passwordConfirmTextField = FeelterTextField(
        placeholder: "비밀번호 확인",
        isSecure: true,
        textContentType: .newPassword
    )

    private let passwordMatchLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray75
        label.isHidden = true
        return label
    }()

    private let nicknameTextField = FeelterTextField(
        placeholder: "닉네임 (필수)",
        textContentType: .nickname,
        keyboardType: .default
    )

    private let nicknameValidationLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .Feelter.gray75
        label.isHidden = true
        return label
    }()

    private let nameTextField = FeelterTextField(
        placeholder: "이름 (필수)",
        textContentType: .name,
        keyboardType: .default
    )

    private let introductionTextField = FeelterTextField(
        placeholder: "소개 (선택)",
        keyboardType: .default
    )

    private let phoneTextField = FeelterTextField(
        placeholder: "전화번호 (선택, 예: 010-1234-5678)",
        textContentType: .telephoneNumber,
        keyboardType: .phonePad
    )

    private let hashTagsTextField = FeelterTextField(
        placeholder: "해시태그 (선택, 쉼표로 구분)",
        keyboardType: .default
    )

    private let joinButton = FeelterButton(title: "회원가입")

    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        return stackView
    }()

    // MARK: - Initialization
    init(
        authRepository: AuthRepositoryProtocol = DIContainer.shared.resolve(AuthRepositoryProtocol.self)
    ) {
        self.authRepository = authRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "회원가입"
        setupBindings()
    }

    override func configureHierarchy() {
        super.configureHierarchy()

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStackView)

        contentStackView.addArrangedSubview(titleLabel)

        // 이메일 섹션
        let emailContainer = createEmailContainer()
        contentStackView.addArrangedSubview(emailContainer)
        contentStackView.addArrangedSubview(emailValidationLabel)

        // 비밀번호 섹션
        contentStackView.addArrangedSubview(passwordTextField)
        contentStackView.addArrangedSubview(passwordValidationLabel)
        contentStackView.addArrangedSubview(passwordConfirmTextField)
        contentStackView.addArrangedSubview(passwordMatchLabel)

        // 닉네임 섹션
        contentStackView.addArrangedSubview(nicknameTextField)
        contentStackView.addArrangedSubview(nicknameValidationLabel)

        // 나머지 필드
        contentStackView.addArrangedSubview(nameTextField)
        contentStackView.addArrangedSubview(introductionTextField)
        contentStackView.addArrangedSubview(phoneTextField)
        contentStackView.addArrangedSubview(hashTagsTextField)

        contentStackView.addArrangedSubview(joinButton)

        // 커스텀 간격
        contentStackView.setCustomSpacing(24, after: titleLabel)
        contentStackView.setCustomSpacing(4, after: emailContainer)
        contentStackView.setCustomSpacing(4, after: passwordTextField)
        contentStackView.setCustomSpacing(4, after: passwordConfirmTextField)
        contentStackView.setCustomSpacing(4, after: nicknameTextField)
        contentStackView.setCustomSpacing(24, after: hashTagsTextField)
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

        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(40)
        }

        [emailTextField, passwordTextField, passwordConfirmTextField,
         nicknameTextField, nameTextField, introductionTextField,
         phoneTextField, hashTagsTextField].forEach { textField in
            textField.snp.makeConstraints { make in
                make.height.equalTo(44)
            }
        }

        emailCheckButton.snp.makeConstraints { make in
            make.width.equalTo(70)
        }

        joinButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
    }

    override func configureView() {
        super.configureView()

        emailCheckButton.addTarget(self, action: #selector(emailCheckButtonTapped), for: .touchUpInside)
        joinButton.addTarget(self, action: #selector(joinButtonTapped), for: .touchUpInside)
    }

    // MARK: - Setup
    private func createEmailContainer() -> UIView {
        let container = UIView()
        container.addSubview(emailTextField)
        container.addSubview(emailCheckButton)

        emailTextField.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(emailCheckButton.snp.leading).offset(-8)
        }

        emailCheckButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(44)
        }

        return container
    }

    // MARK: - Bindings
    private func setupBindings() {
        // 이메일 필드 변경 감지
        emailTextField.textPublisher
            .sink { [weak self] text in
                self?.isEmailValidated = false
                self?.emailValidationLabel.isHidden = true
                self?.emailCheckButton.isEnabled = self?.isValidEmailFormat(text ?? "") ?? false
                self?.updateJoinButtonState()
            }
            .store(in: &cancellables)

        // 비밀번호 필드 변경 감지
        passwordTextField.textPublisher
            .sink { [weak self] text in
                self?.validatePassword(text ?? "")
                self?.checkPasswordMatch()
                self?.updateJoinButtonState()
            }
            .store(in: &cancellables)

        // 비밀번호 확인 필드 변경 감지
        passwordConfirmTextField.textPublisher
            .sink { [weak self] _ in
                self?.checkPasswordMatch()
                self?.updateJoinButtonState()
            }
            .store(in: &cancellables)

        // 닉네임 필드 변경 감지
        nicknameTextField.textPublisher
            .sink { [weak self] text in
                self?.validateNickname(text ?? "")
                self?.updateJoinButtonState()
            }
            .store(in: &cancellables)

        // 이름 필드 변경 감지
        nameTextField.textPublisher
            .sink { [weak self] _ in
                self?.updateJoinButtonState()
            }
            .store(in: &cancellables)
    }

    // MARK: - Validation
    private func isValidEmailFormat(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func validatePassword(_ password: String) {
        // 8자 이상, 영문/숫자/특수문자 포함
        let minLength = password.count >= 8
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil

        isPasswordValid = minLength && hasLetter && hasNumber && hasSpecial

        if password.isEmpty {
            passwordValidationLabel.isHidden = true
        } else {
            passwordValidationLabel.isHidden = false
            if isPasswordValid {
                passwordValidationLabel.text = "✓ 사용 가능한 비밀번호입니다"
                passwordValidationLabel.textColor = .Feelter.deepTurquoise
            } else {
                passwordValidationLabel.text = "✗ 8자 이상, 영문/숫자/특수문자를 포함해야 합니다"
                passwordValidationLabel.textColor = .systemRed
            }
        }
    }

    private func checkPasswordMatch() {
        let password = passwordTextField.text ?? ""
        let confirmPassword = passwordConfirmTextField.text ?? ""

        if confirmPassword.isEmpty {
            passwordMatchLabel.isHidden = true
            isPasswordMatching = false
        } else {
            passwordMatchLabel.isHidden = false
            isPasswordMatching = password == confirmPassword

            if isPasswordMatching {
                passwordMatchLabel.text = "✓ 비밀번호가 일치합니다"
                passwordMatchLabel.textColor = .Feelter.deepTurquoise
            } else {
                passwordMatchLabel.text = "✗ 비밀번호가 일치하지 않습니다"
                passwordMatchLabel.textColor = .systemRed
            }
        }
    }

    private func validateNickname(_ nickname: String) {
        // 특수문자 제한: - . , ? * - @ + ^ $ { } ( ) | [ ] \
        let invalidCharacters = CharacterSet(charactersIn: "-.?*@+^${}()|[]\\")
        let hasInvalidCharacters = nickname.rangeOfCharacter(from: invalidCharacters) != nil

        isNicknameValid = !nickname.isEmpty && !hasInvalidCharacters

        if nickname.isEmpty {
            nicknameValidationLabel.isHidden = true
        } else {
            nicknameValidationLabel.isHidden = false
            if isNicknameValid {
                nicknameValidationLabel.text = "✓ 사용 가능한 닉네임입니다"
                nicknameValidationLabel.textColor = .Feelter.deepTurquoise
            } else {
                nicknameValidationLabel.text = "✗ 특수문자는 사용할 수 없습니다"
                nicknameValidationLabel.textColor = .systemRed
            }
        }
    }

    private func updateJoinButtonState() {
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        let nickname = nicknameTextField.text ?? ""
        let name = nameTextField.text ?? ""

        let allRequiredFieldsFilled = !email.isEmpty && !password.isEmpty && !nickname.isEmpty && !name.isEmpty
        let allValidationsPassed = isEmailValidated && isPasswordValid && isPasswordMatching && isNicknameValid

        joinButton.isEnabled = allRequiredFieldsFilled && allValidationsPassed
    }

    // MARK: - Actions
    @objc private func emailCheckButtonTapped() {
        guard let email = emailTextField.text, !email.isEmpty else { return }

        Task {
            do {
                let message = try await authRepository.validateEmail(email: email)

                await MainActor.run {
                    isEmailValidated = true
                    emailValidationLabel.isHidden = false
                    emailValidationLabel.text = "✓ \(message)"
                    emailValidationLabel.textColor = .Feelter.deepTurquoise
                    emailCheckButton.isEnabled = false
                    updateJoinButtonState()
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    isEmailValidated = false
                    emailValidationLabel.isHidden = false
                    emailValidationLabel.text = "✗ \(error.errorDescription ?? "이메일 중복 확인에 실패했습니다")"
                    emailValidationLabel.textColor = .systemRed
                    updateJoinButtonState()
                }
            } catch {
                await MainActor.run {
                    isEmailValidated = false
                    emailValidationLabel.isHidden = false
                    emailValidationLabel.text = "✗ 이메일 중복 확인에 실패했습니다"
                    emailValidationLabel.textColor = .systemRed
                    updateJoinButtonState()
                }
            }
        }
    }

    @objc private func joinButtonTapped() {
        guard let email = emailTextField.text,
              let password = passwordTextField.text,
              let nickname = nicknameTextField.text,
              let name = nameTextField.text else {
            return
        }

        let introduction = introductionTextField.text?.isEmpty == false ? introductionTextField.text : nil
        let phoneNum = phoneTextField.text?.isEmpty == false ? phoneTextField.text : nil
        let hashTagsText = hashTagsTextField.text ?? ""
        let hashTags = parseHashTags(from: hashTagsText)

        Task {
            do {
                joinButton.isEnabled = false

                let result = try await authRepository.join(
                    email: email,
                    password: password,
                    nick: nickname,
                    name: name,
                    introduction: introduction,
                    phoneNum: phoneNum,
                    hashTags: hashTags.isEmpty ? nil : hashTags
                )

                // 토큰 저장
                KeychainManager.shared.save(token: result.1.accessToken, account: "accessToken")
                KeychainManager.shared.save(token: result.1.refreshToken, account: "refreshToken")
                KeychainManager.shared.save(token: result.0.id, account: "userId")

                await MainActor.run {
                    showAlert(message: "회원가입이 완료되었습니다!") { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    joinButton.isEnabled = true
                    showAlert(message: error.errorDescription ?? "회원가입에 실패했습니다")
                }
            } catch {
                await MainActor.run {
                    joinButton.isEnabled = true
                    showAlert(message: "회원가입에 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers
    private func parseHashTags(from text: String) -> [String] {
        let tags = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return tags.filter { !$0.isEmpty }
    }

    private func showAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}
