//
//  CustomTabBarController.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit
import SnapKit

protocol CustomTabBarControllerDelegate: AnyObject {
    func customTabBarControllerDidSelectFilter(_ controller: CustomTabBarController)
}

final class CustomTabBarController: UITabBarController {

    // MARK: - Types
    enum TabType: Int, CaseIterable {
        case home = 0
        case feed
        case filter
        case search
        case profile

        var title: String {
            switch self {
            case .home: return "홈"
            case .feed: return "피드"
            case .filter: return "필터"
            case .search: return "검색"
            case .profile: return "프로필"
            }
        }

        var emptyIcon: UIImage? {
            switch self {
            case .home: return UIImage.TabBar.homeEmpty
            case .feed: return UIImage.TabBar.feedEmpty
            case .filter: return UIImage.TabBar.filterEmpty
            case .search: return UIImage.TabBar.searchEmpty
            case .profile: return UIImage.TabBar.profileEmpty
            }
        }

        var fillIcon: UIImage? {
            switch self {
            case .home: return UIImage.TabBar.homeFill
            case .feed: return UIImage.TabBar.feedFill
            case .filter: return UIImage.TabBar.filterFill
            case .search: return UIImage.TabBar.searchFill
            case .profile: return UIImage.TabBar.profileFill
            }
        }
    }

    // MARK: - Properties
    private let customTabBar = UIView()
    private let indicatorView = UIView()
    private var tabButtons: [UIButton] = []
    weak var tabBarActionDelegate: CustomTabBarControllerDelegate?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Feelter.gray100
        setupTabBar()
    }

    // MARK: - Setup
    private func setupTabBar() {
        // 기본 탭바 숨기기
        tabBar.isHidden = true

        // 커스텀 탭바 설정
        view.addSubview(customTabBar)
        customTabBar.layer.cornerRadius = 34
        customTabBar.layer.borderColor = UIColor.Feelter.gray75?.cgColor
        customTabBar.layer.borderWidth = 1
        customTabBar.layer.shadowColor = UIColor.Feelter.shadow?.cgColor
        customTabBar.layer.shadowOpacity = 0.25
        customTabBar.layer.shadowOffset = CGSize(width: 0, height: 6)
        customTabBar.layer.shadowRadius = 6

        // Blur 효과 추가 (더 투명하게)
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.alpha = 0.8  // 투명도 조정
        blurEffectView.layer.cornerRadius = 34
        blurEffectView.clipsToBounds = true
        customTabBar.insertSubview(blurEffectView, at: 0)

        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        customTabBar.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-10)
            make.height.equalTo(72)
        }

        // 선택 인디케이터
        customTabBar.addSubview(indicatorView)
        indicatorView.backgroundColor = UIColor.Feelter.gray0

        // 탭 버튼 생성
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center

        customTabBar.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.verticalEdges.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(20)
        }

        TabType.allCases.forEach { tabType in
            let button = createTabButton(for: tabType)
            stackView.addArrangedSubview(button)
            tabButtons.append(button)
        }

        // 초기 선택 아이콘 설정 (Home)
        if let firstButton = tabButtons.first {
            firstButton.setImage(TabType.home.fillIcon?.resize(to: CGSize(width: 34, height: 34)), for: .normal)
            firstButton.tintColor = .Feelter.gray15
        }
    }

    private func createTabButton(for tabType: TabType) -> UIButton {
        let button = UIButton()
        button.tag = tabType.rawValue
        button.setImage(tabType.emptyIcon?.resize(to: CGSize(width: 34, height: 34)), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.tintColor = .Feelter.gray45
        button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
        return button
    }

    // MARK: - Actions
    @objc private func tabButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        selectedIndex = index
        selectTab(at: index)
        if TabType(rawValue: index) == .filter {
            tabBarActionDelegate?.customTabBarControllerDidSelectFilter(self)
        }
    }

    private func selectTab(at index: Int) {
        // 모든 버튼 초기화
        tabButtons.enumerated().forEach { idx, button in
            let tabType = TabType(rawValue: idx)!
            if idx == index {
                button.setImage(tabType.fillIcon?.resize(to: CGSize(width: 34, height: 34)), for: .normal)
                button.tintColor = .Feelter.gray15
            } else {
                button.setImage(tabType.emptyIcon?.resize(to: CGSize(width: 34, height: 34)), for: .normal)
                button.tintColor = .Feelter.gray45
            }
        }

        // 인디케이터 이동 (inset 고려)
        guard customTabBar.frame.width > 0 else { return }

        let horizontalInset: CGFloat = 20
        let availableWidth = customTabBar.frame.width - (horizontalInset * 2)
        let buttonWidth = availableWidth / CGFloat(tabButtons.count)
        let indicatorWidth: CGFloat = 28
        let indicatorX = horizontalInset + (buttonWidth * CGFloat(index)) + (buttonWidth - indicatorWidth) / 2

        UIView.animate(withDuration: 0.3) {
            self.indicatorView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(1)
                make.leading.equalToSuperview().offset(indicatorX)
                make.width.equalTo(indicatorWidth)
                make.height.equalTo(4)
            }
            self.customTabBar.layoutIfNeeded()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 초기 인디케이터 위치 설정 (애니메이션 없이)
        if indicatorView.constraints.isEmpty {
            let horizontalInset: CGFloat = 20
            let availableWidth = customTabBar.frame.width - (horizontalInset * 2)
            let buttonWidth = availableWidth / CGFloat(tabButtons.count)
            let indicatorWidth: CGFloat = 28
            let indicatorX = horizontalInset + (buttonWidth - indicatorWidth) / 2

            indicatorView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(1)
                make.leading.equalToSuperview().offset(indicatorX)
                make.width.equalTo(indicatorWidth)
                make.height.equalTo(4)
            }
        }
    }

    func setCustomTabBarHidden(_ hidden: Bool, animated: Bool) {
        let updateVisibility = {
            self.customTabBar.alpha = hidden ? 0 : 1
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: updateVisibility) { _ in
                self.customTabBar.isHidden = hidden
            }
        } else {
            customTabBar.isHidden = hidden
            updateVisibility()
        }
    }

    func actionSheetAnchorView() -> UIView {
        return customTabBar
    }

    func actionSheetAnchorRect() -> CGRect {
        return CGRect(x: customTabBar.bounds.midX, y: 0, width: 1, height: 1)
    }
}

// MARK: - UIImage Extension
private extension UIImage {
    func resize(to size: CGSize) -> UIImage {
        let resizedImage = UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        // 원본 renderingMode 유지
        return resizedImage.withRenderingMode(renderingMode)
    }
}
