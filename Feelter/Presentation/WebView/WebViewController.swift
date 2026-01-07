//
//  WebViewController.swift
//  Feelter
//
//  Created by Suji Jang on 1/7/26.
//

import UIKit
import WebKit
import SnapKit

final class WebViewController: BaseViewController {

    private let urlString: String
    private var webView: WKWebView!
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Initializer
    init(urlString: String) {
        self.urlString = urlString
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .WebView.black
        view.tintColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        setupWebView()  // super 전에 webView 생성
        super.viewDidLoad()
        configureNavigation()
        loadWebPage()
    }

    func configureNavigation() {
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .Feelter.gray15
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
    }

    override func configureHierarchy() {
        super.configureHierarchy()
        view.addSubview(webView)
        view.addSubview(activityIndicator)
    }

    override func configureLayout() {
        super.configureLayout()

        webView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    // MARK: - Private Methods
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // JavaScript 메시지 핸들러 등록
        contentController.add(self, name: "click_attendance_button")
        contentController.add(self, name: "complete_attendance")

        configuration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.backgroundColor = .Feelter.gray100
    }

    private func loadWebPage() {
        guard let url = URL(string: urlString) else {
            showAlert(message: "잘못된 URL입니다")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(Config.apiKey, forHTTPHeaderField: "SeSACKey")

        activityIndicator.startAnimating()
        webView.load(request)
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showAlert(message: "페이지 로딩에 실패했습니다")
    }
}

// MARK: - WKScriptMessageHandler
extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "click_attendance_button":
            handleAttendanceButtonClick()

        case "complete_attendance":
            handleAttendanceComplete(message: message)

        default:
            break
        }
    }

    private func handleAttendanceButtonClick() {
        guard let accessToken = KeychainManager.shared.read(account: "accessToken") else {
            showAlert(message: "로그인이 필요합니다")
            return
        }

        let script = "requestAttendance('\(accessToken)')"
        webView.evaluateJavaScript(script)
    }

    private func handleAttendanceComplete(message: WKScriptMessage) {
        var attendanceCount = "?"

        if let body = message.body as? [String: Any],
           let count = body["count"] as? Int {
            attendanceCount = "\(count)"
        } else if let count = message.body as? Int {
            attendanceCount = "\(count)"
        }

        showAlert(message: "출석이 완료되었습니다! (총 \(attendanceCount)회)")
    }
}
