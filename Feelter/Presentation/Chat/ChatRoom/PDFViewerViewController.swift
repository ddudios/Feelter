//
//  PDFViewerViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/14/26.
//

import UIKit
import PDFKit
import SnapKit

/// PDF 파일 전용 뷰어
///
/// PDFKit의 PDFView를 사용하여 PDF 파일을 표시합니다.
/// - 원격 URL 또는 로컬 Data를 통해 PDF를 로드할 수 있습니다.
/// - 네비게이션 바에 닫기 버튼과 공유 버튼을 제공합니다.
/// - 핀치 줌, 스크롤 등 기본 PDF 뷰어 기능을 지원합니다.
final class PDFViewerViewController: BaseViewController {

    // MARK: - Properties

    /// PDF 문서 데이터
    private let pdfData: Data?

    /// PDF 원격 URL (다운로드 필요 시)
    private let pdfURL: URL?

    /// 파일명 (네비게이션 타이틀용)
    private let fileName: String

    /// 파일의 로컬 URL (공유 기능용)
    private var localFileURL: URL?

    // MARK: - UI Components

    /// PDFKit의 PDFView
    private let pdfView: PDFView = {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        return view
    }()

    /// 로딩 인디케이터
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.color = .Feelter.brightTurquoise
        return indicator
    }()

    /// 에러 라벨
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = TextStyle.Pretendard.body1
        label.textColor = .Feelter.gray60
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    // MARK: - Initialization

    /// Data로 초기화 (이미 다운로드된 PDF)
    ///
    /// - Parameters:
    ///   - data: PDF 파일 데이터
    ///   - fileName: 표시할 파일명
    init(data: Data, fileName: String) {
        self.pdfData = data
        self.pdfURL = nil
        self.fileName = fileName
        super.init(nibName: nil, bundle: nil)
    }

    /// URL로 초기화 (다운로드가 필요한 원격 PDF)
    ///
    /// - Parameters:
    ///   - url: PDF 파일의 원격 URL
    ///   - fileName: 표시할 파일명
    init(url: URL, fileName: String) {
        self.pdfData = nil
        self.pdfURL = url
        self.fileName = fileName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPDF()
    }

    // MARK: - Configuration

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(pdfView)
        view.addSubview(loadingIndicator)
        view.addSubview(errorLabel)
    }

    override func configureLayout() {
        super.configureLayout()

        pdfView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        errorLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
    }

    override func configureView() {
        super.configureView()
        view.backgroundColor = .systemBackground
        title = fileName
        configureNavigationBar()
    }

    private func configureNavigationBar() {
        // 닫기 버튼 (모달 present 시)
        if navigationController?.viewControllers.first === self {
            let closeButton = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: self,
                action: #selector(closeButtonTapped)
            )
            navigationItem.leftBarButtonItem = closeButton
        }

        // 공유 버튼
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareButtonTapped)
        )
        navigationItem.rightBarButtonItem = shareButton
    }

    // MARK: - PDF Loading

    private func loadPDF() {
        if let data = pdfData {
            // Data로 직접 로드
            displayPDF(from: data)
        } else if let url = pdfURL {
            // URL에서 다운로드 후 로드
            downloadAndDisplayPDF(from: url)
        } else {
            showError("PDF 파일을 불러올 수 없습니다.")
        }
    }

    /// Data로부터 PDF 표시
    private func displayPDF(from data: Data) {
        guard let document = PDFDocument(data: data) else {
            showError("유효하지 않은 PDF 파일입니다.")
            return
        }

        pdfView.document = document

        // 로컬 파일 저장 (공유 기능용)
        saveToTempFile(data: data)
    }

    /// 원격 URL에서 PDF 다운로드 후 표시
    private func downloadAndDisplayPDF(from url: URL) {
        loadingIndicator.startAnimating()
        pdfView.isHidden = true

        // 인증 헤더 추가
        var request = URLRequest(url: url)
        if let accessToken = KeychainManager.shared.read(account: "accessToken") {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        request.setValue(Config.apiKey, forHTTPHeaderField: "SeSACKey")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.pdfView.isHidden = false

                // 에러 처리
                if let error = error {
                    self?.showError("다운로드 실패: \(error.localizedDescription)")
                    return
                }

                // HTTP 응답 체크
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    self?.showError("서버 응답 오류 (코드: \(statusCode))")
                    return
                }

                // 데이터 체크 및 표시
                guard let data = data, !data.isEmpty else {
                    self?.showError("파일 데이터가 비어있습니다.")
                    return
                }

                self?.displayPDF(from: data)
            }
        }

        task.resume()
    }

    /// 임시 파일로 저장 (공유 기능용)
    private func saveToTempFile(data: Data) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try data.write(to: fileURL)
            localFileURL = fileURL
        } catch {
        }
    }

    /// 에러 표시
    private func showError(_ message: String) {
        pdfView.isHidden = true
        errorLabel.text = message
        errorLabel.isHidden = false

        // 공유 버튼 비활성화
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        if let navigationController = navigationController {
            if navigationController.viewControllers.first === self {
                // 모달로 표시된 경우
                dismiss(animated: true)
            } else {
                // 푸시된 경우
                navigationController.popViewController(animated: true)
            }
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func shareButtonTapped() {
        guard let fileURL = localFileURL else {
            let alert = UIAlertController(
                title: "공유 불가",
                message: "파일을 먼저 로드해주세요.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )

        // iPad 대응
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(activityVC, animated: true)
    }
}
