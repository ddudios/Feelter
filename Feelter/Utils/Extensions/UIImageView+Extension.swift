//
//  UIImageView+Extension.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import UIKit
import Kingfisher

extension UIImageView {
    
    // path만 넘기면 알아서 baseURL 붙여서 요청하는 함수
    func setFeelterImage(with path: String?) {
        guard let path = path, !path.isEmpty else {
            // path가 없으면 이미지 초기화 or 기본 이미지
            self.image = nil
            return
        }

        // 1. URL 조립 (Config.baseURL + /v1 + path)
        // (슬래시 처리가 애매하면 여기서 확실하게 처리해도 됨)
        let fullPath = "\(Config.baseURL)/v1\(path)"

        guard let url = URL(string: fullPath) else { return }

        // 2. Kingfisher 호출
        // 전역 헤더 설정은 자동으로 적용됨
        self.kf.indicatorType = .activity
        self.kf.setImage(
            with: url,
            placeholder: UIImage(systemName: "doc.fill"),
            options: [
                .transition(.fade(0.2)), // 부드럽게 뜨는 효과
                .cacheOriginalImage      // 원본 캐싱
            ]
        ) { [weak self] result in
            switch result {
            case .success:
                break
            case .failure(let error):
                // 이미지 로드 실패 시 파일 아이콘 표시 (PDF 등 비이미지 데이터 대응)
                print("⚠️ 이미지 로드 실패: \(error.localizedDescription)")
                self?.image = UIImage(systemName: "doc.fill")
                self?.tintColor = .systemGray
                self?.contentMode = .center
            }
        }
    }

    func setFeelterImage(with path: String?, targetSize: CGSize) {
        guard let path = path, !path.isEmpty else {
            image = nil
            return
        }

        let fullPath = "\(Config.baseURL)/v1\(path)"
        guard let url = URL(string: fullPath) else { return }

        let processor = ResizingImageProcessor(referenceSize: targetSize, mode: .aspectFill)

        kf.indicatorType = .activity
        kf.setImage(
            with: url,
            placeholder: UIImage(systemName: "doc.fill"),
            options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        ) { [weak self] result in
            switch result {
            case .success:
                break
            case .failure(let error):
                // 이미지 로드 실패 시 파일 아이콘 표시 (PDF 등 비이미지 데이터 대응)
                print("⚠️ 이미지 로드 실패: \(error.localizedDescription)")
                self?.image = UIImage(systemName: "doc.fill")
                self?.tintColor = .systemGray
                self?.contentMode = .center
            }
        }
    }
}
