//
//  FilterDetailViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import UIKit
import Combine

final class FilterDetailViewController: BaseViewController {
    private let filterId: String
    private let viewModel: FilterDetailViewModel
    
    private let viewDidLoadSubject = PassthroughSubject<String, Never>()
    private let likeButtonTappedSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var currentIsLiked = false
    private var currentLikeCount: Int?
    var onLikeStateChanged: ((String, Bool, Int) -> Void)?
    
    private lazy var likeBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(
            image: UIImage.Icon.likeEmpty,
            style: .plain,
            target: self,
            action: #selector(likeButtonTapped)
        )
    }()
    
    init(
        filterId: String,
        viewModel: FilterDetailViewModel = FilterDetailViewModel(
            filterUsecase: DIContainer.shared.resolve(FilterUsecaseProtocol.self)
        )
    ) {
        self.filterId = filterId
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
        viewDidLoadSubject.send(filterId)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent, let currentLikeCount {
            onLikeStateChanged?(filterId, currentIsLiked, currentLikeCount)
        }
    }
    
    override func configureView() {
        super.configureView()
        navigationItem.rightBarButtonItem = likeBarButtonItem
    }
    
    private func bind() {
        let input = FilterDetailViewModel.Input(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            likeButtonTapped: likeButtonTappedSubject.eraseToAnyPublisher()
        )
        
        let output = viewModel.transform(input: input)
        
        output.filterDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filter in
                self?.title = filter.title
                self?.currentIsLiked = filter.isLiked
                self?.currentLikeCount = filter.likeCount
            }
            .store(in: &cancellables)
        
        output.isLiked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLiked in
                self?.updateLikeButton(isLiked: isLiked)
                self?.currentIsLiked = isLiked
            }
            .store(in: &cancellables)
        
        output.likeCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] likeCount in
                self?.currentLikeCount = likeCount
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
    
    private func updateLikeButton(isLiked: Bool) {
        let image = isLiked ? UIImage.Icon.likeFill : UIImage.Icon.likeEmpty
        likeBarButtonItem.image = image
    }
    
    @objc private func likeButtonTapped() {
        likeButtonTappedSubject.send(())
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
