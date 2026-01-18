//
//  NetworkMonitor.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation
import Network
import Combine

/// 네트워크 연결 상태를 모니터링하는 싱글톤 클래스
///
/// 역할:
/// 1. NWPathMonitor를 사용하여 실시간 네트워크 상태 감지
/// 2. 네트워크 재연결 시 이벤트 발행
/// 3. Combine Publisher를 통해 네트워크 상태 변경 알림
///
final class NetworkMonitor {

    // MARK: - Singleton
    static let shared = NetworkMonitor()

    // MARK: - Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.feelter.networkmonitor")

    /// 현재 네트워크 연결 상태
    @Published private(set) var isConnected: Bool = false

    /// 네트워크 재연결 이벤트 (끊김 -> 연결됨)
    private let networkReconnectedSubject = PassthroughSubject<Void, Never>()
    var networkReconnected: AnyPublisher<Void, Never> {
        return networkReconnectedSubject.eraseToAnyPublisher()
    }

    /// 이전 연결 상태 (재연결 감지용)
    private var previousConnectionStatus: Bool = false

    // MARK: - Initialization
    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// 네트워크 모니터링 시작
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let currentStatus = path.status == .satisfied

            DispatchQueue.main.async {
                self.isConnected = currentStatus

                // 재연결 감지: 이전에 끊겼다가 (false) 지금 연결됨 (true)
                if !self.previousConnectionStatus && currentStatus {
                    self.networkReconnectedSubject.send()
                }

                self.previousConnectionStatus = currentStatus
            }
        }

        monitor.start(queue: queue)
    }

    /// 네트워크 모니터링 중지
    func stopMonitoring() {
        monitor.cancel()
    }
}
