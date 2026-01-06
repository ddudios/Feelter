//
//  HomeViewController.swift
//  Feelter
//
//  Created by Suji Jang on 12/31/25.
//

import UIKit
import SnapKit
import Combine
import Kingfisher

final class HomeViewController: BaseViewController {

    private let viewModel: HomeViewModel
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Components
    private let backgroundImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let gradientOverlay = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }()

    private let useFilterButton = {
        let button = UIButton()
        button.setTitle("사용해보기", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = TextStyle.Pretendard.body1
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        return button
    }()

    private let introduceLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.caption1
        label.textColor = .white
        return label
    }()

    private let titleLabel = {
        let label = UILabel()
        label.font = TextStyle.Mulgyeol.title1
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    private let descriptionLabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body2
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    private lazy var categoryStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()

    // MARK: - Initializer
    init(viewModel: HomeViewModel = DIContainer.shared.resolve(HomeViewModel.self)) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
        viewDidLoadSubject.send(())
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(backgroundImageView)
        view.addSubview(gradientOverlay)
        view.addSubview(useFilterButton)
        view.addSubview(introduceLabel)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(categoryStackView)

        setupCategoryButtons()
    }

    override func configureLayout() {
        super.configureLayout()

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        gradientOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        useFilterButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalToSuperview().inset(20)
            make.height.equalTo(32)
            make.width.equalTo(100)
        }

        introduceLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(60)
            make.leading.equalToSuperview().offset(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(introduceLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().inset(20)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().inset(20)
        }

        categoryStackView.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(120)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(80)
        }
    }

    // MARK: - Private Methods
    private func setupCategoryButtons() {
        let categories: [(title: String, icon: UIImage?)] = [
            ("푸드", UIImage.Category.food),
            ("인물", UIImage.Category.people),
            ("풍경", UIImage.Category.landscape),
            ("야경", UIImage.Category.night),
            ("별", UIImage.Category.star)
        ]

        categories.forEach { category in
            let button = createCategoryButton(title: category.title, icon: category.icon)
            categoryStackView.addArrangedSubview(button)
        }
    }

    private func createCategoryButton(title: String, icon: UIImage?) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        containerView.layer.cornerRadius = 12

        let iconImageView = UIImageView(image: icon)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = title
        label.font = TextStyle.Pretendard.caption2
        label.textColor = .white
        label.textAlignment = .center

        containerView.addSubview(iconImageView)
        containerView.addSubview(label)

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(32)
        }

        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(4)
        }

        return containerView
    }

    private func bind() {
        let input = HomeViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.todayFilter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filter in
                self?.updateUI(with: filter)
            }
            .store(in: &cancellables)

        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { isLoading in
                // TODO: 로딩 인디케이터 처리
                print("Loading: \(isLoading)")
            }
            .store(in: &cancellables)

        output.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)
    }

    private func updateUI(with filter: Filter) {
        introduceLabel.text = filter.introduction
        titleLabel.text = filter.title
        descriptionLabel.text = filter.description

        if let firstImageURL = filter.files.first, let url = URL(string: firstImageURL) {
            backgroundImageView.kf.setImage(with: url)
        }
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
