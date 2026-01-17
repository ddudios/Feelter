//
//  VideoViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import UIKit

final class VideoViewController: BaseViewController {

    weak var coordinator: FeedCoordinator?

    private let viewModel: VideoViewModel

    init(viewModel: VideoViewModel = DIContainer.shared.resolve(VideoViewModel.self)) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
