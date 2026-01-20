//
//  UIImageView+Extension.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import UIKit
import Kingfisher

extension UIImageView {
    
    // 원본
    func setFeelterImage(with path: String?, completion: ((Bool) -> Void)? = nil) {
        guard let path = path, !path.isEmpty else {
            // path가 없으면 이미지 초기화 or 기본 이미지
            self.image = nil
            completion?(false)
            return
        }

        // 1. URL 조립 (Config.baseURL + /v1 + path)
        // (슬래시 처리가 애매하면 여기서 확실하게 처리해도 됨)
        let fullPath = "\(Config.baseURL)/v1\(path)"

        guard let url = URL(string: fullPath) else {
            completion?(false)
            return
        }

        // 2. Kingfisher 호출
        // 전역 헤더 설정은 자동으로 적용됨
        self.kf.indicatorType = .none  // 인디케이터 제거
        self.kf.setImage(
            with: url,
            placeholder: nil,  // placeholder 제거
            options: [
                .transition(.fade(0.2)), // 부드럽게 뜨는 효과
                .cacheOriginalImage      // 원본 캐싱
            ]
        ) { result in
            switch result {
            case .success:
                completion?(true)
            case .failure:
                // 이미지 로드 실패 시 에러 로그만 남기고 아이콘 표시 안 함
                completion?(false)
            }
        }
    }

    // Resizing + 레티나 배율
    func setFeelterImage(with path: String?, targetSize: CGSize) {
        guard let path = path, !path.isEmpty else {
            image = nil
            return
        }

        let fullPath = "\(Config.baseURL)/v1\(path)"
        guard let url = URL(string: fullPath) else { return }

        let processor = ResizingImageProcessor(referenceSize: targetSize, mode: .aspectFill)

        kf.indicatorType = .none  // 인디케이터 제거
        kf.setImage(
            with: url,
            placeholder: nil,  // placeholder 제거
            options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        ) { result in
            switch result {
            case .success:
                break
            case .failure:
                // 이미지 로드 실패 시 에러 로그만 남기고 아이콘 표시 안 함
                break
            }
        }
    }
}

// MARK: - UIButton Extension
extension UIButton {
    func setFeelterImage(with path: String?, targetSize: CGSize, defaultImage: UIImage? = nil) {
        guard let path = path, !path.isEmpty else {
            setImage(defaultImage, for: .normal)
            tintColor = .Feelter.gray75
            imageView?.contentMode = .scaleAspectFit
            return
        }

        let fullPath = "\(Config.baseURL)/v1\(path)"
        guard let url = URL(string: fullPath) else {
            setImage(defaultImage, for: .normal)
            tintColor = .Feelter.gray75
            imageView?.contentMode = .scaleAspectFit
            return
        }

        let processor = ResizingImageProcessor(referenceSize: targetSize, mode: .aspectFill)

        kf.setImage(
            with: url,
            for: .normal,
            placeholder: defaultImage,
            options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        ) { [weak self] result in
            switch result {
            case .success:
                self?.tintColor = .clear
                self?.imageView?.contentMode = .scaleAspectFill
            case .failure:
                self?.setImage(defaultImage, for: .normal)
                self?.tintColor = .Feelter.gray75
                self?.imageView?.contentMode = .scaleAspectFit
            }
        }
    }
}
