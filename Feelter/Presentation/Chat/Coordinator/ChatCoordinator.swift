//
//  ChatCoordinator.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import UIKit

/// Chat 화면 전환 Coordinator
///
/// 채팅 관련 화면 전환을 담당합니다:
/// - PDF 뷰어 표시
/// - 이미지 뷰어 표시 (추후 확장)
/// - 채팅방 상세 정보 표시 (추후 확장)
@MainActor
final class ChatCoordinator: Coordinator {

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    /// 채팅방 정보 (현재 활성화된 채팅방)
    private weak var chatRoomViewController: ChatRoomViewController?

    // MARK: - Initialization

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    /// ChatRoomViewController와 연결된 Coordinator 생성
    ///
    /// - Parameters:
    ///   - navigationController: 네비게이션 컨트롤러
    ///   - chatRoomViewController: 연결할 ChatRoomViewController
    init(
        navigationController: UINavigationController,
        chatRoomViewController: ChatRoomViewController
    ) {
        self.navigationController = navigationController
        self.chatRoomViewController = chatRoomViewController
    }

    // MARK: - Coordinator

    func start() {
        // ChatCoordinator는 독립적으로 시작되지 않고
        // ChatRoomViewController에서 필요 시 호출됨
    }

    // MARK: - Navigation Methods

    /// PDF 뷰어 표시 (Data 기반)
    ///
    /// - Parameters:
    ///   - data: PDF 파일 데이터
    ///   - fileName: 파일명
    func showPDFViewer(data: Data, fileName: String) {
        let pdfVC = PDFViewerViewController(data: data, fileName: fileName)
        let navController = UINavigationController(rootViewController: pdfVC)
        navController.modalPresentationStyle = .fullScreen

        navigationController.present(navController, animated: true)
    }

    /// PDF 뷰어 표시 (URL 기반 - 서버에서 다운로드)
    ///
    /// - Parameters:
    ///   - fileURL: 파일 경로 (서버 상대 경로)
    ///   - fileName: 파일명
    func showPDFViewer(fileURL: String, fileName: String) {
        // 서버 base URL + file path로 전체 URL 생성
        let fullURLString = "\(Config.baseURL)/v1\(fileURL)"

        guard let url = URL(string: fullURLString) else {
            showErrorAlert(message: "유효하지 않은 파일 URL입니다.")
            return
        }

        let pdfVC = PDFViewerViewController(url: url, fileName: fileName)
        let navController = UINavigationController(rootViewController: pdfVC)
        navController.modalPresentationStyle = .fullScreen

        navigationController.present(navController, animated: true)
    }

    /// PDF 뷰어 표시 (ChatFileAttachment 기반)
    ///
    /// - Parameter file: 파일 첨부 정보
    func showPDFViewer(file: ChatFileAttachment) {
        showPDFViewer(fileURL: file.fileURL, fileName: file.fileName)
    }

    /// 이미지 뷰어 표시 (갤러리 형태)
    ///
    /// - Parameters:
    ///   - images: 이미지 소스 배열
    ///   - selectedIndex: 선택된 이미지 인덱스
    func showImageViewer(images: [ChatImageSource], selectedIndex: Int = 0) {

        let imageViewerVC = ImageViewerViewController(images: images, initialIndex: selectedIndex)
        imageViewerVC.modalPresentationStyle = .fullScreen
        imageViewerVC.modalTransitionStyle = .crossDissolve

        navigationController.present(imageViewerVC, animated: true) {
        }
    }

    /// 파일 뷰어 표시 (파일 타입에 따라 분기)
    ///
    /// - Parameter file: 파일 첨부 정보
    func showFileViewer(file: ChatFileAttachment) {
        let ext = (file.fileName as NSString).pathExtension.lowercased()

        if ext == "pdf" {
            // PDF는 전용 뷰어로 표시
            showPDFViewer(file: file)
        } else {
            // 다른 파일 형식은 Quick Look 사용 (기존 방식)
            chatRoomViewController?.openFileWithQuickLook(file: file)
        }
    }

    // MARK: - Helper Methods

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        navigationController.present(alert, animated: true)
    }
}
